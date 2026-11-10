// SPDX-License-Identifier: MIT
// common.js: helpers shared by the WebGPU pages of tools/regress/regress.sh.
//
// Each page reports one block of text with POST /log (srv.c appends it to log.txt), which regress.sh reads:
//   PAGE <name>
//   INFO <anything>            context only (adapter, three.js revision)
//   PASS <case>: <detail>      one checked case
//   FAIL <case>: <detail>      one failed case (also: uncaught errors, timeouts, uncaptured WebGPU errors)
//   SKIP <case>: <detail>      a case that could not run for a reason outside the driver (no network for the CDN)
//   END
// A page reports once: the first finish() wins, a later one (a timeout after the result) is dropped.

const lines = [];
let sent = false;
let pageName = location.pathname.replace(/^.*\//, '').replace(/\.html$/, '') || 'index';

// say: one result line, shown on the page too (so a screenshot of a failed run shows it).
export function say(line) {
  lines.push(line);
  const o = document.getElementById('o');
  if (o) o.textContent += line + '\n';
}

// finish: post the block once; regress.sh waits for "PAGE <name>" ... "END" in log.txt.
export async function finish() {
  if (sent) return;
  sent = true;
  const body = ['PAGE ' + pageName, ...lines, 'END'].join('\n');
  try {
    await fetch('/log', { method: 'POST', body });
  } catch (e) {
    console.log('post failed', e);
  }
}

// guard: uncaught errors and rejections fail the page; after ms the page fails with a timeout (a GPU hang or a
// promise that never settles), so regress.sh always gets a block before its own, longer timeout.
export function guard(ms) {
  window.addEventListener('error', (e) => { say('FAIL uncaught: ' + (e.message || e)); finish(); });
  window.addEventListener('unhandledrejection', (e) => {
    const r = e.reason;
    say('FAIL rejection: ' + ((r && (r.message || r.stack)) || String(r)));
    finish();
  });
  setTimeout(() => { say('FAIL timeout: no result after ' + ms / 1000 + ' s'); finish(); }, ms);
}

// device: the WebGPU adapter and device; an uncaptured WebGPU error (validation, out of memory) fails the page.
export async function device() {
  if (!navigator.gpu) throw new Error('no navigator.gpu (WebGPU off in this browser)');
  const ad = await navigator.gpu.requestAdapter();
  if (!ad) throw new Error('requestAdapter returned null');
  const i = ad.info || {};
  say('INFO adapter: ' + [i.vendor, i.architecture, i.device, i.description].filter(Boolean).join(' / '));
  const dev = await ad.requestDevice();
  dev.onuncapturederror = (e) => say('FAIL uncaptured WebGPU error: ' + e.error.message);
  return dev;
}

// readPixels: the whole of a 2D texture of 4 bytes per texel (rgba8unorm, bgra8unorm) as tightly packed rows.
// copyTextureToBuffer needs rows of a multiple of 256 bytes; the padding is dropped here.
export async function readPixels(dev, tex, w, h) {
  const bpr = Math.ceil((w * 4) / 256) * 256;
  const buf = dev.createBuffer({ size: bpr * h, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
  const enc = dev.createCommandEncoder();
  enc.copyTextureToBuffer({ texture: tex }, { buffer: buf, bytesPerRow: bpr }, { width: w, height: h });
  dev.queue.submit([enc.finish()]);
  await buf.mapAsync(GPUMapMode.READ);
  const src = new Uint8Array(buf.getMappedRange());
  const out = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) out.set(src.subarray(y * bpr, y * bpr + w * 4), y * w * 4);
  buf.unmap();
  buf.destroy();
  return out;
}

// pixel: [r, g, b, a] at (x, y) of readPixels' result; bgra: the texture is bgra8unorm (a canvas on macOS).
export function pixel(px, w, x, y, bgra) {
  const o = (y * w + x) * 4;
  return bgra ? [px[o + 2], px[o + 1], px[o], px[o + 3]] : [px[o], px[o + 1], px[o + 2], px[o + 3]];
}

// near: every component of got within tol of want (compares as many components as want has).
export function near(got, want, tol) {
  return want.every((v, k) => Math.abs(got[k] - v) <= tol);
}

// check: one PASS/FAIL line for a pixel against what it should be.
export function check(name, got, want, tol) {
  const ok = near(got, want, tol);
  say(`${ok ? 'PASS' : 'FAIL'} ${name}: got ${Array.from(got).join(',')} want ${want.join(',')}${ok ? '' : ' (tolerance ' + tol + ')'}`);
  return ok;
}
