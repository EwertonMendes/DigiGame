import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const suite = process.env.SMOKE_SUITE ?? 'desktop';
const configuredAttempts = Number(process.env.BROWSER_SMOKE_ATTEMPTS ?? (suite === 'mobile' ? 3 : 1));
const attempts = Number.isFinite(configuredAttempts) && configuredAttempts > 0
  ? Math.floor(configuredAttempts)
  : 1;
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const coreScript = path.join(scriptDir, 'browser-smoke-core.mjs');
let lastStatus = 1;

for (let attempt = 1; attempt <= attempts; attempt += 1) {
  if (attempts > 1) {
    console.log(`[Smoke] ${suite} clean-browser attempt ${attempt}/${attempts}`);
  }

  const result = spawnSync(process.execPath, [coreScript], {
    stdio: 'inherit',
    env: process.env,
  });

  if (result.error) {
    console.error(`[Smoke] could not start ${suite} browser suite: ${result.error.message}`);
    lastStatus = 1;
  } else if (result.status === 0) {
    process.exit(0);
  } else {
    lastStatus = result.status ?? 1;
  }

  if (attempt < attempts) {
    console.warn(`[Smoke] ${suite} attempt ${attempt} failed; retrying from a fresh Node/Chromium process.`);
  }
}

process.exit(lastStatus);
