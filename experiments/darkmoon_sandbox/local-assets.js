// Read one pinned atlas from a user-selected ZIP. No file data leaves the browser.
const ATLAS_NAME = 'Darkmoon_City_Assets/darkmoon_city/tiles_8x8.png';
const ATLAS_SHA = 'a9abb47ff5433abdcdc82632b6e6e748bb4389f1919e2e452e3f92e493a1226a';
const ATLAS_PATH = '/assets/local/darkmoon_sandbox/darkmoon_city/tiles_8x8.png';

async function readCityAtlas(file) {
  if (file.size > 32 * 1024 * 1024) throw new Error('Choose the supplied city asset ZIP (maximum 32 MB).');
  const bytes = new Uint8Array(await file.arrayBuffer());
  const view = new DataView(bytes.buffer);
  let end = -1;
  for (let offset = bytes.length - 22; offset >= Math.max(0, bytes.length - 65557); offset--) {
    if (view.getUint32(offset, true) === 0x06054b50 && offset + 22 + view.getUint16(offset + 20, true) === bytes.length) {
      end = offset; break;
    }
  }
  if (end < 0 || view.getUint16(end + 4, true) || view.getUint16(end + 6, true)) throw new Error('This is not a supported city asset ZIP.');
  let cursor = view.getUint32(end + 16, true);
  const count = view.getUint16(end + 10, true);
  for (let index = 0; index < count; index++) {
    if (cursor + 46 > end || view.getUint32(cursor, true) !== 0x02014b50) throw new Error('Invalid ZIP directory.');
    const flags = view.getUint16(cursor + 8, true);
    const method = view.getUint16(cursor + 10, true);
    const packedSize = view.getUint32(cursor + 20, true);
    const size = view.getUint32(cursor + 24, true);
    const nameLength = view.getUint16(cursor + 28, true);
    const extraLength = view.getUint16(cursor + 30, true);
    const commentLength = view.getUint16(cursor + 32, true);
    const local = view.getUint32(cursor + 42, true);
    const next = cursor + 46 + nameLength + extraLength + commentLength;
    if (next > end) throw new Error('Invalid ZIP entry.');
    const name = new TextDecoder().decode(bytes.subarray(cursor + 46, cursor + 46 + nameLength));
    cursor = next;
    if (name !== ATLAS_NAME) continue;
    if ((flags & 1) || ![0, 8].includes(method) || size > 2 * 1024 * 1024 || local + 30 > bytes.length || view.getUint32(local, true) !== 0x04034b50) throw new Error('Unsupported atlas ZIP entry.');
    const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
    if (start + packedSize > bytes.length) throw new Error('Truncated atlas.');
    let atlas = bytes.slice(start, start + packedSize);
    if (method === 8) {
      const stream = new Blob([atlas]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
      atlas = new Uint8Array(await new Response(stream).arrayBuffer());
    }
    if (atlas.length !== size) throw new Error('Atlas size check failed.');
    const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', atlas));
    const hash = Array.from(digest, value => value.toString(16).padStart(2, '0')).join('');
    if (hash !== ATLAS_SHA) throw new Error('The city atlas does not match the supplied asset pack.');
    return atlas;
  }
  throw new Error('The ZIP does not contain the supplied 8×8 city atlas.');
}

window.selectSandboxAssets = function (engine) {
  // Explicit diagnostic mode for public CI; it never opens by default.
  if (new URLSearchParams(location.search).get('geometry') === '1') return Promise.resolve();
  document.getElementById('canvas').style.visibility = 'hidden';
  const panel = document.createElement('section');
  panel.id = 'city-assets';
  panel.innerHTML = `<h1>Build with your city assets</h1>
    <p>Choose <strong>Darkmoon_City_Assets_Only.zip</strong> to explore the scene with its original pixel art.</p>
    <p>Your file stays on this device. It is read locally and never uploaded.</p>
    <label class="city-file-button">Choose city ZIP<input id="city-zip" type="file" accept=".zip,application/zip"></label>
    <p id="city-asset-status" role="status" aria-live="polite"></p>`;
  const style = document.createElement('style');
  style.textContent = '#city-assets{position:fixed;inset:0;z-index:20;display:flex;flex-direction:column;justify-content:center;align-items:center;gap:12px;padding:24px;background:#14182a;color:#edf5ff;font:17px/1.5 system-ui;text-align:center}#city-assets h1{font-size:30px;margin:0}#city-assets p{max-width:540px;margin:0}.city-file-button{position:relative;display:block;border:1px solid #9de0f4;border-radius:6px;padding:12px 24px;background:#263951;margin-top:16px;cursor:pointer}.city-file-button input{position:absolute;inset:0;opacity:0;width:100%;cursor:pointer}#city-assets:has(input:focus-visible) .city-file-button{outline:3px solid #edf5ff}#city-asset-status{min-height:28px}';
  document.head.appendChild(style);
  document.body.appendChild(panel);
  return new Promise(resolve => {
    const input = panel.querySelector('input');
    const status = panel.querySelector('[role=status]');
    input.addEventListener('change', async () => {
      const file = input.files[0];
      if (!file) return;
      input.disabled = true;
      status.textContent = 'Checking city pieces…';
      try {
        const atlas = await readCityAtlas(file);
        await engine.preloadFile(atlas, ATLAS_PATH);
        panel.remove();
        document.getElementById('canvas').style.visibility = '';
        resolve();
      } catch (error) {
        status.textContent = error.message;
        input.disabled = false;
        input.value = '';
      }
    });
  });
};
