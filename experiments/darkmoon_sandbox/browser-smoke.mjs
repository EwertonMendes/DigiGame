import { chromium } from 'playwright';

const url = process.env.SANDBOX_URL ?? 'http://127.0.0.1:8000/sandbox.html';
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_BIN ?? '/usr/bin/google-chrome',
});
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1365, height: 768 } });
  let position = null;
  let mode = null;
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    const text = message.text();
    if (message.type() === 'error' || /SCRIPT ERROR|Parse Error|ROUTE FAIL/.test(text)) {
      errors.push(text);
      console.error(text);
    }
    const match = text.match(/\[DarkmoonSandbox\] POSITION (-?[\d.]+) (-?[\d.]+)/);
    if (match) position = { x: Number(match[1]), y: Number(match[2]) };
    if (text.includes('[DarkmoonSandbox] READY')) mode = text;
  });
  const ready = page.waitForEvent('console', {
    predicate: message => message.text().includes('[DarkmoonSandbox] READY'), timeout: 90000,
  });
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await ready;
  await page.waitForTimeout(500);
  if (!position) throw new Error('Missing actor position telemetry');
  if (process.env.EXPECT_PRIVATE !== '1' && !mode.includes('Original preview art')) {
    throw new Error(`Public export unexpectedly contains private art: ${mode}`);
  }
  if (process.env.EXPECT_PRIVATE === '1' && !mode.includes('Private local atlas')) {
    throw new Error('Local Web test did not load private palette');
  }
  await page.screenshot({ path: 'build/sandbox-desktop.png' });
  // Real browser keyboard input, eight directions; R returns to valid spawn.
  for (const keys of [['ArrowLeft'], ['ArrowRight'], ['ArrowUp'], ['ArrowDown'],
    ['ArrowLeft', 'ArrowUp'], ['ArrowRight', 'ArrowUp'],
    ['ArrowLeft', 'ArrowDown'], ['ArrowRight', 'ArrowDown']]) {
    await page.keyboard.press('r');
    await page.waitForTimeout(400);
    const start = { ...position };
    for (const key of keys) await page.keyboard.down(key);
    await page.waitForTimeout(220);
    for (const key of keys) await page.keyboard.up(key);
    await page.waitForTimeout(400);
    if (Math.hypot(position.x - start.x, position.y - start.y) < 8) {
      throw new Error(`Browser actor did not move: ${keys}`);
    }
  }
  await page.keyboard.press('r');
  // Actor-level route and collision checks use the same controller as manual play.
  const route = page.waitForEvent('console', {
    predicate: message => message.text().includes('[DarkmoonSandbox] ROUTE PASS'), timeout: 30000,
  });
  await page.keyboard.press('F4');
  await route;
  // Hold directly into the fountain; neither frontal nor diagonal motion
  // may enter its base (the headless suite also probes full clearance and voids).
  await page.keyboard.down('ArrowUp');
  await page.waitForTimeout(1800);
  await page.keyboard.up('ArrowUp');
  await page.waitForTimeout(400);
  if (position.y < 140 || position.y > 170) throw new Error(`Fountain collision failed: ${JSON.stringify(position)}`);
  await page.screenshot({ path: 'build/sandbox-fountain-collision.png' });
  await page.keyboard.press('r');
  const map = page.waitForEvent('console', {
    predicate: message => message.text().includes('[DarkmoonSandbox] MAP true'), timeout: 5000,
  });
  await page.keyboard.press('Tab');
  await map;
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'build/sandbox-map.png' });
  await page.keyboard.press('F3');
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'build/sandbox-collision.png' });
  await page.keyboard.press('F3');
  for (const viewport of [{ width: 1920, height: 1080 }, { width: 390, height: 844 }, { width: 844, height: 390 }]) {
    await page.setViewportSize(viewport);
    await page.waitForTimeout(500);
    const box = await page.locator('canvas').boundingBox();
    if (!box || box.width < viewport.width - 2 || box.height < viewport.height - 2 || box.x > 1 || box.y > 1) {
      throw new Error(`Canvas does not fill viewport: ${JSON.stringify({ viewport, box })}`);
    }
    await page.screenshot({ path: `build/sandbox-${viewport.width}x${viewport.height}.png` });
  }
  if (errors.length) throw new Error(errors.join('\n'));
  console.log('Sandbox browser smoke PASS: keyboard, route, collision, responsive canvas');
} finally {
  await browser.close();
}
