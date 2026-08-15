// Town-square hero life: rain-code canvas + count-up numbers. CSS/canvas only —
// no deps, no network, no audio. Everything honors prefers-reduced-motion and
// stops itself when the home route unmounts (canvas leaves the DOM).

export function reducedMotion() {
  return typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

// Matrix rain scoped to the hero. ~6% opacity is set in CSS; the canvas stops
// drawing as soon as it is detached (route change) so no rAF loop leaks.
export function startRain(canvas) {
  if (reducedMotion()) return;
  const host = canvas.parentElement;
  const x = canvas.getContext("2d");
  if (!x) return;
  const glyphs = "01ｱｲｳｴｵｶｷｸｹｺ日ノ0123456789ABCDEF＄◇△▽".split("");
  const fs = 15, frameMs = 1000 / 18; // slow
  let W = 0, H = 0, cols = 0, drops = [], last = 0;
  function resize() {
    W = canvas.width = host.clientWidth;
    H = canvas.height = host.clientHeight;
    cols = Math.floor(W / fs);
    drops = Array.from({ length: cols }, () => Math.random() * -40);
  }
  resize();
  const onResize = () => { if (canvas.isConnected) resize(); };
  addEventListener("resize", onResize);
  function draw(ts) {
    if (!canvas.isConnected) { removeEventListener("resize", onResize); return; }
    requestAnimationFrame(draw);
    if (document.hidden || ts - last < frameMs) return;
    last = ts;
    x.fillStyle = "rgba(5,7,10,0.28)";
    x.fillRect(0, 0, W, H);
    x.font = fs + "px ui-monospace, monospace";
    for (let i = 0; i < cols; i++) {
      const g = glyphs[(Math.random() * glyphs.length) | 0];
      x.fillStyle = Math.random() < 0.02 ? "rgba(190,255,210,0.9)" : "rgba(0,255,65,0.6)";
      x.fillText(g, i * fs, drops[i] * fs);
      if (drops[i] * fs > H && Math.random() > 0.975) drops[i] = 0; else drops[i] += 0.6;
    }
  }
  requestAnimationFrame(draw);
}

// Count-up for the pulse rail. Values are the LIVE numbers passed in by the
// caller (loadPulse) — this only animates the reveal; reduced-motion renders
// them static immediately.
export function countUp(el, target, { decimals = 0, ms = 850 } = {}) {
  const fmt = (v) => decimals ? v.toFixed(decimals) : String(Math.round(v));
  if (reducedMotion()) { el.textContent = fmt(target); return; }
  let start = null;
  function step(ts) {
    if (!el.isConnected) return;
    if (start === null) start = ts;
    const p = Math.min((ts - start) / ms, 1);
    el.textContent = fmt(p * target);
    if (p < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}
