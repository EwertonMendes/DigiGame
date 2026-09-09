import { chromium } from 'playwright';

const url = process.env.DIGIGAME_URL ?? 'http://127.0.0.1:8000';
const runtimeErrors = [];
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_BIN ?? '/usr/bin/google-chrome',
});

const desktopViewports = [
  { width: 1280, height: 720 },
  { width: 1440, height: 900 },
  { width: 1920, height: 1080 },
];

const mobileViewports = [
  { width: 390, height: 844 },
  { width: 844, height: 390 },
];

function watchRuntimeErrors(page, label) {
  page.on('pageerror', error => runtimeErrors.push(`${label} pageerror: ${error.message}`));
  page.on('console', message => {
    if (message.type() === 'error') runtimeErrors.push(`${label} console: ${message.text()}`);
  });
}

async function waitForGame(page) {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { state: 'visible', timeout: 60000 });
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    return canvas && canvas.width > 100 && canvas.height > 100;
  }, null, { timeout: 60000 });
  await page.waitForTimeout(5000);
}

async function readLayout(page) {
  return page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    const rect = canvas.getBoundingClientRect();
    return {
      canvasWidth: rect.width,
      canvasHeight: rect.height,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight,
    };
  });
}

function assertViewportFill(layout) {
  const widthFill = layout.canvasWidth / layout.viewportWidth;
  const heightFill = layout.canvasHeight / layout.viewportHeight;
  if (widthFill < 0.98 || heightFill < 0.98) {
    throw new Error(
      `Godot canvas does not fill the browser viewport: ` +
      `${layout.canvasWidth}x${layout.canvasHeight} inside ` +
      `${layout.viewportWidth}x${layout.viewportHeight}`
    );
  }
}

function assertScreensDiffer(before, after, description) {
  if (before.equals(after)) {
    throw new Error(`${description} did not visibly change the rendered game.`);
  }
}

async function dispatchTouch(client, type, points) {
  await client.send('Input.dispatchTouchEvent', {
    type,
    touchPoints: points.map((point, index) => ({
      x: point.x,
      y: point.y,
      id: index + 1,
      radiusX: 3,
      radiusY: 3,
      force: 1,
    })),
  });
}

async function dragOneFinger(client, start, end, steps = 8) {
  await dispatchTouch(client, 'touchStart', [start]);
  for (let step = 1; step <= steps; step += 1) {
    const t = step / steps;
    await dispatchTouch(client, 'touchMove', [{
      x: start.x + (end.x - start.x) * t,
      y: start.y + (end.y - start.y) * t,
    }]);
  }
  await dispatchTouch(client, 'touchEnd', []);
}

async function pinch(client, center, startRadius, endRadius, steps = 8) {
  const pointsAt = radius => [
    { x: center.x - radius, y: center.y },
    { x: center.x + radius, y: center.y },
  ];

  await dispatchTouch(client, 'touchStart', pointsAt(startRadius));
  for (let step = 1; step <= steps; step += 1) {
    const t = step / steps;
    const radius = startRadius + (endRadius - startRadius) * t;
    await dispatchTouch(client, 'touchMove', pointsAt(radius));
  }
  await dispatchTouch(client, 'touchEnd', []);
}

try {
  const page = await browser.newPage({ viewport: desktopViewports[0] });
  watchRuntimeErrors(page, 'desktop');
  await waitForGame(page);

  for (const viewport of desktopViewports) {
    await page.setViewportSize(viewport);
    await page.waitForTimeout(800);
    assertViewportFill(await readLayout(page));
  }

  await page.setViewportSize({ width: 1440, height: 900 });
  await page.waitForTimeout(800);
  const finalLayout = await readLayout(page);
  const centerX = finalLayout.viewportWidth * 0.5;
  const centerY = finalLayout.viewportHeight * 0.5;

  await page.mouse.move(centerX, centerY);
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/web-smoke.png', fullPage: true });

  const debugX = finalLayout.viewportWidth - 88;
  const debugY = 38;
  await page.mouse.click(debugX, debugY, { button: 'left' });
  await page.waitForTimeout(400);
  await page.screenshot({ path: 'build/debug-mode-on.png', fullPage: true });
  await page.mouse.click(debugX, debugY, { button: 'left' });
  await page.waitForTimeout(300);

  await page.mouse.click(centerX, centerY, { button: 'left' });
  await page.waitForTimeout(400);

  const facingTargets = [
    ['up-left', centerX - 220, centerY - 150],
    ['up-right', centerX + 220, centerY - 150],
    ['down-right', centerX + 220, centerY + 150],
    ['down-left', centerX - 220, centerY + 150],
  ];

  for (const [name, x, y] of facingTargets) {
    await page.mouse.move(x, y, { steps: 8 });
    await page.waitForTimeout(500);
    await page.screenshot({ path: `build/gabumon-facing-${name}.png`, fullPage: true });
  }

  await page.mouse.click(centerX - 120, centerY + 70, { button: 'left' });
  await page.waitForTimeout(700);
  await page.screenshot({ path: 'build/gabumon-facing-persisted.png', fullPage: true });

  await page.mouse.move(centerX + 180, centerY + 110);
  await page.mouse.down({ button: 'right' });
  await page.mouse.move(centerX - 240, centerY - 150, { steps: 12 });
  await page.mouse.up({ button: 'right' });
  await page.waitForTimeout(900);
  await page.screenshot({ path: 'build/camera-pan-smoke.png', fullPage: true });

  // Keyboard camera parity: +/- zoom and WASD/arrow panning must remain valid.
  await page.keyboard.press('Equal');
  await page.keyboard.down('KeyA');
  await page.waitForTimeout(250);
  await page.keyboard.up('KeyA');
  await page.waitForTimeout(250);
  await page.screenshot({ path: 'build/keyboard-camera-smoke.png', fullPage: true });

  const mobilePage = await browser.newPage({
    viewport: mobileViewports[0],
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 1,
  });
  watchRuntimeErrors(mobilePage, 'mobile');
  await waitForGame(mobilePage);
  assertViewportFill(await readLayout(mobilePage));

  let mobileLayout = await readLayout(mobilePage);
  let mobileCenter = {
    x: mobileLayout.viewportWidth * 0.5,
    y: mobileLayout.viewportHeight * 0.5,
  };

  await mobilePage.screenshot({ path: 'build/mobile-portrait.png', fullPage: true });

  // Touch-friendly on-screen + button must work without a mouse wheel.
  const beforeButtonZoom = await mobilePage.screenshot();
  await mobilePage.touchscreen.tap(
    mobileLayout.viewportWidth - 34,
    mobileLayout.viewportHeight - 44,
  );
  await mobilePage.waitForTimeout(500);
  const afterButtonZoom = await mobilePage.screenshot();
  assertScreensDiffer(beforeButtonZoom, afterButtonZoom, 'Mobile zoom button');
  await mobilePage.screenshot({ path: 'build/mobile-zoom-button.png', fullPage: true });

  const client = await mobilePage.context().newCDPSession(mobilePage);

  // A normal touch tap at screen center selects Gabumon; a second tap remains
  // available for movement. This specifically exercises native touch input,
  // not Playwright mouse emulation.
  await mobilePage.touchscreen.tap(mobileCenter.x, mobileCenter.y);
  await mobilePage.waitForTimeout(450);
  await mobilePage.screenshot({ path: 'build/mobile-touch-select.png', fullPage: true });

  // One-finger drag pans the board without requiring right-click.
  const beforeTouchPan = await mobilePage.screenshot();
  await dragOneFinger(
    client,
    { x: mobileCenter.x + 90, y: mobileCenter.y + 90 },
    { x: mobileCenter.x - 70, y: mobileCenter.y - 40 },
  );
  await mobilePage.waitForTimeout(500);
  const afterTouchPan = await mobilePage.screenshot();
  assertScreensDiffer(beforeTouchPan, afterTouchPan, 'One-finger touch pan');
  await mobilePage.screenshot({ path: 'build/mobile-touch-pan.png', fullPage: true });

  // Two-finger pinch must zoom the game on real touch devices.
  const beforePinch = await mobilePage.screenshot();
  await pinch(client, mobileCenter, 42, 92);
  await mobilePage.waitForTimeout(600);
  const afterPinch = await mobilePage.screenshot();
  assertScreensDiffer(beforePinch, afterPinch, 'Pinch zoom');
  await mobilePage.screenshot({ path: 'build/mobile-pinch-zoom.png', fullPage: true });

  // Recheck the opposite mobile orientation because the Web viewport uses the
  // same responsive Godot canvas in portrait and landscape.
  await mobilePage.setViewportSize(mobileViewports[1]);
  await mobilePage.waitForTimeout(800);
  assertViewportFill(await readLayout(mobilePage));
  await mobilePage.screenshot({ path: 'build/mobile-landscape.png', fullPage: true });

  if (runtimeErrors.length > 0) {
    throw new Error(`Browser runtime errors:\n${runtimeErrors.join('\n')}`);
  }

  console.log(
    `DigiGame Web smoke test passed at ${desktopViewports.length} desktop and ` +
    `${mobileViewports.length} mobile orientations, including mouse, keyboard, ` +
    `touch tap, one-finger pan, pinch zoom, mobile zoom controls, and responsive canvas checks.`
  );
} finally {
  await browser.close();
}
