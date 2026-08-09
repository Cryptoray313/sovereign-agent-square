// Self-contained QR (bundled qrcode-generator; no runtime/CDN fetch).
import qrcode from "qrcode-generator";

export function qrSvg(text, cellSize = 4) {
  const q = qrcode(0, "M"); // auto type, error-correction level M
  q.addData(String(text));
  q.make();
  return q.createSvgTag({ cellSize, margin: 2, scalable: true });
}
