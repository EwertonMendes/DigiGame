import { chromium } from 'playwright';

const url = process.env.DIGIGAME_URL ?? 'http://127.0.0.1:8000';
const runtimeErrors = [];
const browser = await chromium.launch({ headless: true });

try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

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

  await page.waitForTimeout(6000);

  const layout = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    const rect = canvas.getBoundingClientRect();
    return {
      canvasWidth: rect.width,
      canvasHeight: rect.height,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight,
    };
  });

  const widthFill = layout.canvasWidth / layout.viewportWidth;
  const heightFill = layout.canvasHeight / layout.viewportHeight;
  if (widthFill < 0.98 || heightFill < 0.98) {
    throw new Error(
      `Godot canvas does not fill the browser viewport: ` +
      `${layout.canvasWidth}x${layout.canvasHeight} inside ` +
      `${layout.viewportWidth}x${layout.viewportHeight}`
    );
  }

  await page.mouse.move(layout.viewportWidth * 0.5, layout.viewportHeight * 0.5);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'build/web-smoke.png', fullPage: true });

  if (runtimeErrors.length > 0) {
    throw new Error(`Browser runtime errors:\n${runtimeErrors.join('\n')}`);
  }

  console.log(
    `DigiGame Web smoke test passed: canvas fills viewport ` +
    `(${layout.canvasWidth}x${layout.canvasHeight}) and runtime is error-free.`
  );
} finally {
  await browser.close();
}
