import { test; suite } "mo:test/async";
import Array "mo:core/Array";
import Blob "mo:core/Blob";
import Nat8 "mo:core/Nat8";
import Nat64 "mo:core/Nat64";
import Int "mo:core/Int";
import Principal "mo:core/Principal";
import Runtime "mo:core/Runtime";
import Text "mo:core/Text";
import Time "mo:core/Time";
import ICRC "../canisters/shared/ICRC";
import Core "../canisters/square_core/main";
import CoreTypes "../canisters/square_core/types";
import EscrowTypes "../canisters/square_escrow/types";
import Escrow "../canisters/square_escrow/main";
import TestLedger "../canisters/test_ledger/main";
import Sim "support/sim";

/// Phase 1 integration suite: the full escrow lifecycle against the local
/// dummy ICRC-1/2 ledger, plus auth, reentrancy, compensation, and timeout
/// paths, and square_core reading rep from receipts.
persistent actor {

  let FEE : Nat = 10_000; // dummy ledger flat fee
  let CB : Nat = 1_000_000; // client job bond (escrow constant)
  let AB : Nat = 1_000_000; // agent job bond (escrow constant)
  let G : Nat = 50_000_000; // happy-path gross: 0.5 ICP

  let hash32 : Blob = Blob.fromArray(Array.tabulate<Nat8>(32, func(_) { 7 }));
  let badHash : Blob = Blob.fromArray(Array.tabulate<Nat8>(31, func(_) { 7 }));

  func acct(p : Principal) : ICRC.Account {
    { owner = p; subaccount = null };
  };

  func isOk<T>(r : EscrowTypes.Result<T>) : Bool {
    switch (r) { case (#ok(_)) { true }; case (#err(_)) { false } };
  };

  func isOk2<T>(r : CoreTypes.Result<T>) : Bool {
    switch (r) { case (#ok(_)) { true }; case (#err(_)) { false } };
  };

  public func runTests() : async () {
    // ---------- world setup ----------
    let sim1 = await (with cycles = 2_000_000_000_000) Sim.Sim(); // the agent
    let sim2 = await (with cycles = 2_000_000_000_000) Sim.Sim(); // wrong-caller
    let self = await sim1.whoisCaller(); // this test actor = the client
    let agentP = Principal.fromActor(sim1);
    let wrongP = Principal.fromActor(sim2);

    let ledger = await (with cycles = 2_000_000_000_000) TestLedger.TestLedger({
      initialBalances = [
        (acct(self), 2_000_000_000), // client: 20 ICP
        (acct(agentP), 200_000_000), // agent: 2 ICP
        (acct(wrongP), 200_000_000),
      ];
      fee = FEE;
    });
    let ledgerP = Principal.fromActor(ledger);

    let escrow = await (with cycles = 2_000_000_000_000) Escrow.SquareEscrow({
      ledgerId = ledgerP;
      opCapE8s = 100_000_000; // 1 ICP operational cap
      minDeadlineNs = 0;
      reviewWindowNs = 3_600_000_000_000; // 1h: review timeout never fires here
    });
    let escrowP = Principal.fromActor(escrow);

    let escrowFast = await (with cycles = 2_000_000_000_000) Escrow.SquareEscrow({
      ledgerId = ledgerP;
      opCapE8s = 100_000_000;
      minDeadlineNs = 0;
      reviewWindowNs = 0; // review timeout fires immediately after deliver
    });
    let escrowFastP = Principal.fromActor(escrowFast);

    let core = await (with cycles = 2_000_000_000_000) Core.SquareCore({ escrowId = escrowP });
    let coreP = Principal.fromActor(core);

    func bal(p : Principal) : async Nat {
      await ledger.icrc1_balance_of(acct(p));
    };

    func approveSelf(spender : Principal, amount : Nat) : async () {
      let res = await ledger.icrc2_approve({
        from_subaccount = null;
        spender = acct(spender);
        amount;
        expected_allowance = null;
        expires_at = null;
        fee = ?FEE;
        memo = null;
        created_at_time = null;
      });
      switch (res) { case (#Ok(_)) {}; case (#Err(_)) { Runtime.trap("approve failed") } };
    };

    func statusOf(e : actor { getJob : shared query (Nat) -> async ?EscrowTypes.JobView }, jobId : Nat) : async EscrowTypes.JobStatus {
      switch (await e.getJob(jobId)) {
        case (?v) { v.status };
        case (null) { Runtime.trap("job not found") };
      };
    };

    // ---------- suites ----------

    await suite(
      "happy path: createJob -> bid -> select -> accept -> deliver -> acceptDelivery -> receipt",
      func() : async () {
        var jobId = 0;
        let clientStart = await bal(self);
        let agentStart = await bal(agentP);

        await test(
          "createJob escrow-locks gross + client bond via ICRC-2",
          func() : async () {
            await approveSelf(escrowP, G + CB + FEE);
            let res = await escrow.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, ["research"]);
            switch (res) {
              case (#ok(id)) { jobId := id };
              case (#err(_)) { Runtime.trap("createJob failed") };
            };
            assert (await statusOf(escrow, jobId)) == #open;
            // Escrow now holds exactly gross + client bond.
            assert (await bal(escrowP)) == G + CB;
          },
        );

        await test(
          "bid, selectBid, acceptJob locks the agent bond",
          func() : async () {
            assert isOk(await sim1.doBid(escrowP, jobId));
            assert isOk(await escrow.selectBid(jobId, agentP));
            assert (await sim1.approveLedger(ledgerP, escrowP, AB + FEE, FEE));
            assert isOk(await sim1.doAcceptJob(escrowP, jobId));
            assert (await statusOf(escrow, jobId)) == #assigned;
            assert (await bal(escrowP)) == G + CB + AB;
          },
        );

        await test(
          "deliver then acceptDelivery releases 95/3/2 with an exact receipt",
          func() : async () {
            assert isOk(await sim1.doDeliver(escrowP, jobId, hash32));
            assert (await statusOf(escrow, jobId)) == #delivered;
            assert isOk(await escrow.acceptDelivery(jobId));
            assert (await statusOf(escrow, jobId)) == #released;

            let receipt = switch (await escrow.getReceipt(jobId)) {
              case (?r) { r };
              case (null) { Runtime.trap("no receipt") };
            };
            // L11 exactness for 0.5 ICP.
            assert receipt.grossE8s == G;
            assert receipt.feeE8s == 2_500_000;
            assert receipt.netE8s == 47_500_000;
            assert receipt.burnOrEarmarkE8s == 1_500_000;
            assert receipt.treasuryE8s == 1_000_000;
            assert receipt.netE8s + receipt.burnOrEarmarkE8s + receipt.treasuryE8s == receipt.grossE8s;
            assert receipt.agent == agentP;
            assert receipt.client == self;
          },
        );

        await test(
          "ledger-level conservation: escrow retains exactly burn + treasury",
          func() : async () {
            assert (await bal(escrowP)) == 2_500_000;
            // Client: approve fee + (gross + bond + pull fee) out, bond - fee back.
            assert (await bal(self)) == clientStart - FEE - (G + CB + FEE) + (CB - FEE);
            // Agent: approve fee + (bond + pull fee) out, net - fee and bond - fee in.
            assert (await bal(agentP)) == agentStart - FEE - (AB + FEE) + (47_500_000 - FEE) + (AB - FEE);
          },
        );

        await test(
          "journal is fully resolved and receipts drive agent stats",
          func() : async () {
            for (entry in (await escrow.getJournal(jobId)).values()) {
              switch (entry.state) {
                case (#done(_)) {};
                case (_) { Runtime.trap("unresolved journal entry after release") };
              };
            };
            let stats = await escrow.getAgentStats(agentP);
            assert stats.completedJobs == 1;
            assert stats.netEarnedE8s == 47_500_000;
            assert (await escrow.getReceiptsForAgent(agentP)).size() == 1;
          },
        );
      },
    );

    await suite(
      "caps, bounds, and input validation",
      func() : async () {
        await test(
          "rejects bad spec hash, tiny gross, capped gross, past deadline, oversized skills",
          func() : async () {
            let far = Time.now() + 3_600_000_000_000;
            assert not isOk(await escrow.createJob(badHash, #icp, G, far, []));
            assert not isOk(await escrow.createJob(hash32, #icp, 999_999, far, [])); // below 0.01 ICP min
            assert not isOk(await escrow.createJob(hash32, #icp, 100_000_001, far, [])); // above 1 ICP op cap
            assert not isOk(await escrow.createJob(hash32, #icp, G, Time.now() - 1, []));
            let manySkills = Array.tabulate<Text>(17, func(_) { "x" });
            assert not isOk(await escrow.createJob(hash32, #icp, G, far, manySkills));
          },
        );
      },
    );

    await suite(
      "auth: wrong caller rejected on every state transition",
      func() : async () {
        var jobId = 0;
        await test(
          "set up an open job with a bid",
          func() : async () {
            await approveSelf(escrowP, G + CB + FEE);
            switch (await escrow.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, [])) {
              case (#ok(id)) { jobId := id };
              case (#err(_)) { Runtime.trap("createJob failed") };
            };
            assert isOk(await sim1.doBid(escrowP, jobId));
          },
        );
        await test(
          "non-client cannot selectBid / acceptDelivery / cancel; non-agent cannot accept/deliver",
          func() : async () {
            assert not isOk(await sim2.doSelectBid(escrowP, jobId, wrongP)); // not the client
            assert not isOk(await escrow.bid(jobId)); // client cannot bid on own job
            assert isOk(await escrow.selectBid(jobId, agentP));
            assert not isOk(await sim2.doAcceptJob(escrowP, jobId)); // not the selected agent
            assert (await sim1.approveLedger(ledgerP, escrowP, AB + FEE, FEE));
            assert isOk(await sim1.doAcceptJob(escrowP, jobId));
            assert not isOk(await escrow.deliver(jobId, hash32)); // client is not the agent
            assert not isOk(await sim2.doDeliver(escrowP, jobId, hash32)); // nor is sim2
            assert isOk(await sim1.doDeliver(escrowP, jobId, hash32));
            assert not isOk(await sim2.doAcceptDelivery(escrowP, jobId)); // only client accepts
            assert isOk(await escrow.acceptDelivery(jobId));
            assert (await statusOf(escrow, jobId)) == #released;
          },
        );
        await test(
          "terminal states refuse further transitions (double release)",
          func() : async () {
            assert not isOk(await escrow.acceptDelivery(jobId));
            assert not isOk(await escrow.cancelJob(jobId));
          },
        );
      },
    );

    await suite(
      "deposit compensation: transient, ambiguous, and definitive failures",
      func() : async () {
        await test(
          "transient reject -> depositPending -> reconcileDeposit completes the pull",
          func() : async () {
            await approveSelf(escrowP, G + CB + FEE);
            await ledger.setFailMode(#rejectTransferFromOnce);
            let res = await escrow.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, []);
            let jobId = switch (res) {
              case (#err(#depositUnresolved)) {
                // createJob told us it is unresolved; find it by scanning
                // recent ids (the id counter is monotonic).
                var found : ?Nat = null;
                var i = 0;
                while (i < 20) {
                  switch (await escrow.getJob(i)) {
                    case (?v) { if (v.status == #depositPending) { found := ?v.id } };
                    case (null) {};
                  };
                  i += 1;
                };
                switch (found) { case (?id) { id }; case (null) { Runtime.trap("no pending job") } };
              };
              case (_) { Runtime.trap("expected depositUnresolved") };
            };
            assert isOk(await escrow.reconcileDeposit(jobId));
            assert (await statusOf(escrow, jobId)) == #open;
            // Clean up; client gets gross + bond back (minus one ledger fee).
            let before = await bal(self);
            assert isOk(await escrow.cancelJob(jobId));
            assert (await statusOf(escrow, jobId)) == #refunded;
            assert (await bal(self)) == before + (G + CB - FEE);
          },
        );
        await test(
          "ambiguous outcome (funds moved, error reported) -> dedup makes reconcile safe",
          func() : async () {
            let escrowBefore = await bal(escrowP);
            await approveSelf(escrowP, G + CB + FEE);
            await ledger.setFailMode(#pullThenErrorOnce);
            let res = await escrow.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, []);
            switch (res) { case (#err(#depositUnresolved)) {}; case (_) { Runtime.trap("expected depositUnresolved") } };
            // The pull actually landed:
            assert (await bal(escrowP)) == escrowBefore + G + CB;
            var pendingId : ?Nat = null;
            var i = 0;
            while (i < 30) {
              switch (await escrow.getJob(i)) {
                case (?v) { if (v.status == #depositPending) { pendingId := ?v.id } };
                case (null) {};
              };
              i += 1;
            };
            let jobId = switch (pendingId) { case (?id) { id }; case (null) { Runtime.trap("no pending job") } };
            assert isOk(await escrow.reconcileDeposit(jobId));
            assert (await statusOf(escrow, jobId)) == #open;
            // No double pull: balance unchanged by reconciliation.
            assert (await bal(escrowP)) == escrowBefore + G + CB;
            assert isOk(await escrow.cancelJob(jobId));
          },
        );
        await test(
          "definitive failure (no allowance) aborts the job cleanly",
          func() : async () {
            let res = await escrow.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, []);
            switch (res) {
              case (#err(#ledgerError(_))) {};
              case (_) { Runtime.trap("expected ledgerError") };
            };
          },
        );
      },
    );

    await suite(
      "payout failure recovery and reentrancy (CallerGuard under concurrency)",
      func() : async () {
        var jobId = 0;
        await test(
          "release with a failing first payout leaves job #releasing with a retryable entry",
          func() : async () {
            await approveSelf(escrowP, G + CB + FEE);
            switch (await escrow.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, [])) {
              case (#ok(id)) { jobId := id };
              case (#err(_)) { Runtime.trap("createJob failed") };
            };
            assert isOk(await sim1.doBid(escrowP, jobId));
            assert isOk(await escrow.selectBid(jobId, agentP));
            assert (await sim1.approveLedger(ledgerP, escrowP, AB + FEE, FEE));
            assert isOk(await sim1.doAcceptJob(escrowP, jobId));
            assert isOk(await sim1.doDeliver(escrowP, jobId, hash32));
            await ledger.setFailMode(#rejectTransferOnce);
            assert isOk(await escrow.acceptDelivery(jobId));
            assert (await statusOf(escrow, jobId)) == #releasing;
          },
        );
        await test(
          "concurrent processPayouts: one proceeds, one is rejected by the guard",
          func() : async () {
            let f1 = escrow.processPayouts(jobId);
            let f2 = escrow.processPayouts(jobId);
            let r1 = await f1;
            let r2 = await f2;
            let lockedCount =
              (switch (r1) { case (#err(#locked)) { 1 }; case (_) { 0 } })
              + (switch (r2) { case (#err(#locked)) { 1 }; case (_) { 0 } });
            let okCount =
              (switch (r1) { case (#ok(_)) { 1 }; case (_) { 0 } })
              + (switch (r2) { case (#ok(_)) { 1 }; case (_) { 0 } });
            assert lockedCount == 1;
            assert okCount == 1;
            // The retry completed the stuck payout; job is now terminal.
            assert (await statusOf(escrow, jobId)) == #released;
            switch (await escrow.getReceipt(jobId)) { case (?_) {}; case (null) { Runtime.trap("no receipt") } };
          },
        );
      },
    );

    await suite(
      "timeouts: review-window release",
      // Deadline-EXPIRY boundaries can't be crossed on PocketIC's frozen test
      // clock; they are frozen as pure boundary tests in lifecycle.test.mo,
      // and the escrow routes every time decision through that same lib. The
      // refund machinery itself is exercised by cancelJob above.
      func() : async () {
        await test(
          "delivered job past review window releases to the agent (agent-driven)",
          func() : async () {
            await approveSelf(escrowFastP, G + CB + FEE);
            let jobId = switch (await escrowFast.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, [])) {
              case (#ok(id)) { id };
              case (#err(_)) { Runtime.trap("createJob failed") };
            };
            assert isOk(await sim1.doBid(escrowFastP, jobId));
            assert isOk(await escrowFast.selectBid(jobId, agentP));
            assert (await sim1.approveLedger(ledgerP, escrowFastP, AB + FEE, FEE));
            assert isOk(await sim1.doAcceptJob(escrowFastP, jobId));
            let agentBefore = await bal(agentP);
            assert isOk(await sim1.doDeliver(escrowFastP, jobId, hash32));
            // Review window is 0: the agent can claim right away — and this
            // also proves timeoutJob is drivable by any authenticated party.
            assert isOk(await sim1.doTimeout(escrowFastP, jobId));
            assert (await statusOf(escrowFast, jobId)) == #released;
            switch (await escrowFast.getReceipt(jobId)) { case (?_) {}; case (null) { Runtime.trap("no receipt") } };
            // Agent got net + bond back (each minus one ledger fee).
            assert (await bal(agentP)) == agentBefore + (47_500_000 - FEE) + (AB - FEE);
          },
        );
      },
    );

    await suite(
      "heartbeat job cards and live trust info",
      func() : async () {
        var jobId = 0;
        await test(
          "heartbeat serves skill-filtered cards with exact economics",
          func() : async () {
            await approveSelf(escrowP, G + CB + FEE);
            switch (await escrow.createJob(hash32, #icp, G, Time.now() + 3_600_000_000_000, ["research"])) {
              case (#ok(id)) { jobId := id };
              case (#err(_)) { Runtime.trap("createJob failed") };
            };
            let page = await escrow.heartbeat(null, []);
            let card = switch (page.job_cards.find(func(c) { c.jobId == jobId })) {
              case (?c) { c };
              case (null) { Runtime.trap("new job missing from heartbeat") };
            };
            // Deterministic promise: net to the e8s, plus the flat ledger fee.
            assert card.grossE8s == G;
            assert card.agentNetE8s == 47_500_000;
            assert card.ledgerFeeE8s == FEE;
            assert card.agentBondE8s == AB;
            // Three releases happened on this escrow so far, all by this client.
            assert card.clientRep == 3;
            // Skill filtering: no overlap excludes, overlap includes.
            let none = await escrow.heartbeat(null, ["nosuchskill"]);
            assert none.job_cards.find(func(c) { c.jobId == jobId }) == null;
            let hit = await escrow.heartbeat(null, ["research", "extra"]);
            assert hit.job_cards.find(func(c) { c.jobId == jobId }) != null;
            // The client sees its own jobs as escrow events.
            assert page.escrow_events.size() > 0;
            assert page.dispute_deadlines.size() == 0;
          },
        );
        await test(
          "getTrustInfo carries the exact formula and running totals",
          func() : async () {
            let info = await escrow.getTrustInfo();
            assert info.feeFormula.contains(#text "floor(gross * 500 / 10_000)");
            assert info.feeFormula.contains(#text "ledger_transfer_fee");
            assert info.feeBps == 500;
            assert info.burnSharePct == 60;
            assert info.receiptsCount == 3;
            assert info.totalGrossSettledE8s == 3 * G;
            assert info.totalNetPaidE8s == 3 * 47_500_000;
            assert info.burnReserveE8s == 3 * 1_500_000;
            assert info.treasuryReserveE8s == 3 * 1_000_000;
            // Leave state clean for later suites.
            assert isOk(await escrow.cancelJob(jobId));
          },
        );
      },
    );

    await suite(
      "square_core: profiles, posts, cooldown, rep from receipts",
      func() : async () {
        await test(
          "register + validation + duplicate rejection",
          func() : async () {
            switch (await core.register("ez", "too short handle")) {
              case (#err(#invalidInput(_))) {};
              case (_) { Runtime.trap("expected invalidInput") };
            };
            assert isOk2(await core.register("client-1", "the client"));
            switch (await core.register("client-1b", "again")) {
              case (#err(#alreadyRegistered)) {};
              case (_) { Runtime.trap("expected alreadyRegistered") };
            };
          },
        );
        await test(
          "posts flagged untrusted, cooldown enforced",
          func() : async () {
            assert isOk2(await core.createPost(#general, "hello square"));
            switch (await core.createPost(#general, "again immediately")) {
              case (#err(#cooldown(_))) {};
              case (_) { Runtime.trap("expected cooldown") };
            };
            let page = await core.getPosts(#general, 0, 10);
            assert page.untrusted_content;
            assert page.posts.size() == 1;
          },
        );
        await test(
          "rep flows from escrow receipts via the query-only reader",
          func() : async () {
            assert isOk2(await sim1.doRegisterCore(coreP, "agent-1", "the agent"));
            let snap = switch (await core.refreshRep(agentP)) {
              case (#ok(s)) { s };
              case (#err(_)) { Runtime.trap("refreshRep failed") };
            };
            assert snap.completedJobs >= 3; // happy path + auth suite + payout suite + fast release
            let profile = switch (await core.getProfile(agentP)) {
              case (?p) { p };
              case (null) { Runtime.trap("no profile") };
            };
            switch (profile.rep) {
              case (?r) { assert r.completedJobs == snap.completedJobs };
              case (null) { Runtime.trap("rep not cached") };
            };
          },
        );
      },
    );

    // ============ REGRESSION SUITE (adversarial-review findings) ============
    // Each test reproduces a finding's HARM and asserts the fix. Comments note
    // what the pre-fix code did (fail-before), which these now prevent.
    await suite(
      "regression: deposit safety and anti-inflation (review F1/F2 + rollback)",
      func() : async () {
        let rLedger = await (with cycles = 2_000_000_000_000) TestLedger.TestLedger({
          initialBalances = [(acct(self), 5_000_000_000)];
          fee = FEE;
        });
        let rLedgerP = Principal.fromActor(rLedger);
        let rEscrow = await (with cycles = 2_000_000_000_000) Escrow.SquareEscrow({
          ledgerId = rLedgerP;
          opCapE8s = 100_000_000;
          minDeadlineNs = 0;
          reviewWindowNs = 3_600_000_000_000;
        });
        let rEscrowP = Principal.fromActor(rEscrow);
        let far = Time.now() + 3_600_000_000_000;

        func rApprove(amount : Nat) : async () {
          switch (await rLedger.icrc2_approve({ from_subaccount = null; spender = acct(rEscrowP); amount; expected_allowance = null; expires_at = null; fee = ?FEE; memo = null; created_at_time = null })) {
            case (#Ok(_)) {}; case (#Err(_)) { Runtime.trap("rApprove failed") };
          };
        };
        func rStatus(jobId : Nat) : async ?EscrowTypes.JobStatus {
          switch (await rEscrow.getJob(jobId)) { case (?v) { ?v.status }; case (null) { null } };
        };

        await test(
          "F1: a landed deposit reporting an already-owned block PARKS and recovers, never strands (pre-fix: #aborted, funds lost)",
          func() : async () {
            await rApprove(G + CB + FEE);
            switch (await rEscrow.createJob(hash32, #icp, G, far, [])) {
              case (#ok(0)) {}; case (_) { Runtime.trap("job 0 should open") };
            };
            let job0Block = switch (await rEscrow.getJob(0)) { case (?v) { switch (v.depositBlockIndex) { case (?b) { b }; case (null) { Runtime.trap("no block") } } }; case (null) { Runtime.trap("no job0") } };
            let escrowBefore = await rLedger.icrc1_balance_of(acct(rEscrowP));

            await rLedger.forceNextTransferFromBlock(job0Block);
            await rApprove(G + CB + FEE);
            switch (await rEscrow.createJob(hash32, #icp, G, far, [])) {
              case (#err(#depositUnresolved)) {};
              case (_) { Runtime.trap("F1: expected parked #depositUnresolved") };
            };
            assert (await rLedger.icrc1_balance_of(acct(rEscrowP))) == escrowBefore + G + CB;
            assert (await rStatus(1)) == ?(#depositPending);

            switch (await rEscrow.reconcileDeposit(1)) { case (#ok(1)) {}; case (_) { Runtime.trap("F1: reconcile should open job 1") } };
            assert (await rStatus(1)) == ?(#open);
          },
        );

        await test(
          "rollback: a definitively-failed createJob (no allowance) leaves ZERO persistent state (pre-fix: leaked #aborted job per call = free DoS)",
          func() : async () {
            let idBefore = 2;
            switch (await rEscrow.createJob(hash32, #icp, G, far, [])) {
              case (#err(#ledgerError(_))) {}; case (_) { Runtime.trap("expected ledgerError") };
            };
            assert (await rEscrow.getJob(idBefore)) == null;
            switch (await rEscrow.createJob(hash32, #icp, G, far, [])) { case (#err(_)) {}; case (_) { Runtime.trap("expected err") } };
            assert (await rEscrow.getJob(idBefore)) == null;
            assert (await rEscrow.getJob(idBefore + 1)) == null;
          },
        );

        await test(
          "F2: a reconcile after the dedup window PARKS #depositPending, never strands (pre-fix: #TooOld -> #aborted, funds lost)",
          func() : async () {
            await rApprove(G + CB + FEE);
            await rLedger.setFailMode(#pullThenErrorOnce);
            let jobId = switch (await rEscrow.createJob(hash32, #icp, G, far, [])) {
              case (#err(#depositUnresolved)) {
                var found : ?Nat = null; var i = 0;
                while (i < 12) { switch (await rEscrow.getJob(i)) { case (?v) { if (v.status == #depositPending) { found := ?v.id } }; case (null) {} }; i += 1 };
                switch (found) { case (?id) { id }; case (null) { Runtime.trap("no pending job") } };
              };
              case (_) { Runtime.trap("expected depositUnresolved from pullThenError") };
            };
            let escrowHeld = await rLedger.icrc1_balance_of(acct(rEscrowP));

            await rLedger.advanceDedupHorizon(Nat64.fromNat(Int.abs(Time.now()) + 3_600_000_000_000));
            switch (await rEscrow.reconcileDeposit(jobId)) {
              case (#err(#depositUnresolved)) {};
              case (_) { Runtime.trap("F2: expected safe park, not abort") };
            };
            assert (await rStatus(jobId)) == ?(#depositPending);
            assert (await rLedger.icrc1_balance_of(acct(rEscrowP))) == escrowHeld;
            await rLedger.advanceDedupHorizon(0);
          },
        );

        await test(
          "heartbeat/index: open jobs indexed, removed on terminal",
          func() : async () {
            await rApprove(G + CB + FEE);
            let jid = switch (await rEscrow.createJob(hash32, #icp, G, far, ["idx"])) { case (#ok(id)) { id }; case (#err(_)) { Runtime.trap("createJob failed") } };
            let p1 = await rEscrow.heartbeat(null, ["idx"]);
            assert p1.job_cards.find(func(c) { c.jobId == jid }) != null;
            switch (await rEscrow.cancelJob(jid)) { case (#ok(_)) {}; case (#err(_)) { Runtime.trap("cancel failed") } };
            let p2 = await rEscrow.heartbeat(null, ["idx"]);
            assert p2.job_cards.find(func(c) { c.jobId == jid }) == null;
          },
        );

        // Re-review Finding 1: an agent-bond pull that becomes un-confirmable
        // after the dedup window must NOT hold the client's gross+bond hostage.
        await test(
          "re-review F1: post-window unresolvable agent bond is abandoned so the client's deposit can be refunded (pre-fix: job wedged forever)",
          func() : async () {
            // Fresh agent principal for a clean bond flow.
            let sim = await (with cycles = 2_000_000_000_000) Sim.Sim();
            let ag = Principal.fromActor(sim);
            // fund the agent on rLedger
            switch (await rLedger.icrc2_approve({ from_subaccount = null; spender = acct(rEscrowP); amount = 0; expected_allowance = null; expires_at = null; fee = ?FEE; memo = null; created_at_time = null })) { case (_) {} };
            // seed agent balance by minting via a transfer from self
            switch (await rLedger.icrc1_transfer({ from_subaccount = null; to = acct(ag); amount = 10_000_000; fee = ?FEE; memo = null; created_at_time = null })) { case (#Ok(_)) {}; case (#Err(_)) { Runtime.trap("seed agent failed") } };

            await rApprove(G + CB + FEE);
            let jid = switch (await rEscrow.createJob(hash32, #icp, G, far, [])) { case (#ok(id)) { id }; case (#err(_)) { Runtime.trap("createJob failed") } };
            assert isOk(await sim.doBid(rEscrowP, jid));
            assert isOk(await rEscrow.selectBid(jid, ag));
            // Agent approves bond, but the pull returns an AMBIGUOUS result.
            assert (await sim.approveLedger(rLedgerP, rEscrowP, AB + FEE, FEE));
            await rLedger.setFailMode(#pullThenErrorOnce);
            switch (await sim.doAcceptJob(rEscrowP, jid)) {
              case (#err(#depositUnresolved)) {}; // ambiguous bond -> #unknown entry
              case (_) { Runtime.trap("expected ambiguous bond") };
            };
            // Client cannot refund yet — the unresolved bond blocks it.
            switch (await rEscrow.cancelJob(jid)) {
              case (#err(#depositUnresolved)) {}; // correctly blocked while resolvable
              case (_) { Runtime.trap("cancel should be blocked by unresolved bond") };
            };
            // Window passes; the bond can never be confirmed via retry.
            await rLedger.advanceDedupHorizon(Nat64.fromNat(Int.abs(Time.now()) + 3_600_000_000_000));
            // resolveAgentBond must ABANDON the bond (terminal escape), NOT wedge.
            switch (await rEscrow.resolveAgentBond(jid)) { case (#ok(_)) {}; case (#err(_)) { Runtime.trap("re-review F1: resolveAgentBond should abandon a post-window bond") } };
            // Reset the window so the refund transfer itself isn't rejected.
            await rLedger.advanceDedupHorizon(0);
            // Now the client CAN get their gross+bond back.
            let clientBefore = await rLedger.icrc1_balance_of(acct(self));
            switch (await rEscrow.cancelJob(jid)) { case (#ok(_)) {}; case (#err(_)) { Runtime.trap("re-review F1: cancel must succeed after bond abandoned") } };
            switch (await rEscrow.getJob(jid)) { case (?v) { assert v.status == #refunded }; case (null) { Runtime.trap("no job") } };
            assert (await rLedger.icrc1_balance_of(acct(self))) == clientBefore + (G + CB - FEE);
            await rLedger.setFailMode(#none);
          },
        );
      },
    );
  };
};
