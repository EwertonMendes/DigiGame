import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const browser = await chromium.launch({
  executablePath: process.env.CHROME_BIN || '/usr/bin/google-chrome',
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage'],
});

async function assertNoOverflow(page, label) {
  const sizes = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  assert.ok(sizes.scrollWidth <= sizes.clientWidth + 1, `${label} has horizontal overflow: ${JSON.stringify(sizes)}`);
}

try {
  const desktop = await browser.newPage({ viewport: { width: 1440, height: 960 }, locale: 'en-US' });
  await desktop.goto('http://127.0.0.1:8000/', { waitUntil: 'networkidle' });
  await desktop.locator('h1').waitFor();
  await assertNoOverflow(desktop, 'Desktop landing');
  assert.match(await desktop.locator('h1').innerText(), /Build your team/i);
  assert.match(await desktop.locator('.build-note').innerText(), /not open yet/i);
  assert.equal(await desktop.locator('a[href*="/play/"]').count(), 0, 'Pre-gate landing must not link to the game build');
  assert.match(await desktop.locator('.disclaimer').innerText(), /not affiliated with or endorsed by Bandai/i);

  await desktop.locator('[data-locale="pt-BR"]').click();
  assert.equal(await desktop.locator('html').getAttribute('lang'), 'pt-BR');
  assert.match(await desktop.locator('h1').innerText(), /Monte sua equipe/i);
  assert.match(await desktop.locator('.build-note').innerText(), /AINDA NÃO ABERTO/i);

  await desktop.locator('[data-locale="es"]').click();
  assert.equal(await desktop.locator('html').getAttribute('lang'), 'es');
  assert.match(await desktop.locator('h1').innerText(), /Forma tu equipo/i);
  await desktop.screenshot({ path: 'build/landing-desktop.png', fullPage: true });

  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, locale: 'pt-BR' });
  await mobile.goto('http://127.0.0.1:8000/', { waitUntil: 'networkidle' });
  await mobile.locator('h1').waitFor();
  await assertNoOverflow(mobile, 'Mobile landing');
  assert.equal(await mobile.locator('html').getAttribute('lang'), 'pt-BR');
  assert.match(await mobile.locator('h1').innerText(), /Monte sua equipe/i);
  await mobile.screenshot({ path: 'build/landing-mobile.png', fullPage: true });

  const gameResponse = await mobile.request.get('http://127.0.0.1:8000/play/index.html');
  assert.equal(gameResponse.status(), 200, 'Assembled site must preserve the tested game under /play/');
  console.log('Landing page multilingual and responsive smoke passed.');
} finally {
  await browser.close();
}
