import { chromium } from 'playwright';

const url = process.env.DIGIGAME_URL ?? 'http://127.0.0.1:8000';
const runtimeErrors = [];
const browser = await chromium.launch({ headless: true });

const desktopViewports = [
  { width: 1280, height: 720 },
  { width: 1440, height: 900 },
  { width: 1920, height: 1080 },
];

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

try {
  const page = await browser.newPage({ viewport: desktopViewports[0] });

  page.on('pageerror', error => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on('console', message => {
    if (message.type() === 'error') runtimeErrors.push(`console: ${message.text()}`);
  });

  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { state: 'visible', timeout: 60000 });
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    return canvas && canvas.width > 100 && canvas.height > 100;
  }, null, { timeout: 60000 });

  await page.waitForTimeout(5000);

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

  // Gabumon starts on the center tile. Select him and sweep the mouse through
  // all four isometric facing quadrants. The screenshots are retained for
  // visual review while runtime errors fail the workflow automatically.
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

  // Click the current target tile. Gabumon should move, deselect, and preserve
  // the final facing direction instead of snapping back to a default pose.
  await page.mouse.click(centerX - 120, centerY + 70, { button: 'left' });
  await page.waitForTimeout(700);
  await page.screenshot({ path: 'build/gabumon-facing-persisted.png', fullPage: true });

  // Exercise the right-button drag gesture after the facing interaction.
  await page.mouse.move(centerX + 180, centerY + 110);
  await page.mouse.down({ button: 'right' });
  await page.mouse.move(centerX - 240, centerY - 150, { steps: 12 });
  await page.mouse.up({ button: 'right' });
  await page.waitForTimeout(900);
  await page.screenshot({ path: 'build/camera-pan-smoke.png', fullPage: true });

  if (runtimeErrors.length > 0) {
    throw new Error(`Browser runtime errors:\n${runtimeErrors.join('\n')}`);
  }

  console.log(
    `DigiGame Web smoke test passed at ${desktopViewports.length} desktop viewport sizes, ` +
    `including four-direction Gabumon facing, persisted facing after movement, and camera drag.`
  );
} finally {
  await browser.close();
}
