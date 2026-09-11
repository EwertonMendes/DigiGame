import { chromium } from 'playwright';

const url = process.env.DIGIGAME_URL ?? 'http://127.0.0.1:8000';
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_BIN ?? '/usr/bin/google-chrome',
});

const runtimeErrors = [];

async function waitForGame(page) {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { state: 'visible', timeout: 60000 });
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    return canvas && canvas.width > 100 && canvas.height > 100;
  }, null, { timeout: 60000 });
  await page.waitForTimeout(5000);
}

async function enterTestBattle(page) {
  const battleStarted = page.waitForEvent('console', {
    predicate: message => message.text().includes('[Hub] START_TEST_BATTLE'),
    timeout: 10000,
  });
  await page.keyboard.press('KeyE');
  await page.waitForTimeout(350);
  await page.keyboard.press('Enter');
  await battleStarted;
  await page.waitForTimeout(5000);
}

try {
  const page = await browser.newPage({ viewport: { width: 1365, height: 685 } });
  page.on('pageerror', error => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on('console', message => {
    if (message.type() === 'error') runtimeErrors.push(`console: ${message.text()}`);
  });

  await waitForGame(page);
  await enterTestBattle(page);
  const baseline = await page.screenshot();

  // Register all waits before advancing turns so a fast Web build cannot race
  // past either the base cinematic layer or the data-driven technique layer.
  const startEvent = page.waitForEvent('console', {
    predicate: message => message.text().includes('[CombatFX] START'),
    timeout: 15000,
  });
  const impactEvent = page.waitForEvent('console', {
    predicate: message => message.text().includes('[CombatFX] IMPACT'),
    timeout: 15000,
  });
  const presentationStartEvent = page.waitForEvent('console', {
    predicate: message => message.text().includes('[CombatPresentation] phase=start'),
    timeout: 15000,
  });
  const presentationImpactEvent = page.waitForEvent('console', {
    predicate: message => message.text().includes('[CombatPresentation] phase=impact'),
    timeout: 15000,
  });

  let keepAdvancing = true;
  const advanceTurns = (async () => {
    for (let attempt = 0; attempt < 16 && keepAdvancing; attempt += 1) {
      await page.keyboard.press('Digit5');
      await page.waitForTimeout(650);
    }
  })();

  const startMessage = await startEvent;
  const presentationStartMessage = await presentationStartEvent;
  await page.waitForTimeout(85);
  const windup = await page.screenshot();
  if (baseline.equals(windup)) {
    throw new Error('CombatFX START fired but attack windup produced no visible frame change.');
  }
  await page.screenshot({ path: 'build/combat-vfx-windup.png', fullPage: true });

  const impactMessage = await impactEvent;
  const presentationImpactMessage = await presentationImpactEvent;
  await page.waitForTimeout(45);
  await page.screenshot({ path: 'build/combat-vfx-impact.png', fullPage: true });
  keepAdvancing = false;
  await advanceTurns;

  if (!startMessage.text().includes('actor=') || !startMessage.text().includes('target=')) {
    throw new Error(`CombatFX START log is missing actor/target ids: ${startMessage.text()}`);
  }
  if (!impactMessage.text().includes('damage=')) {
    throw new Error(`CombatFX IMPACT log is missing damage: ${impactMessage.text()}`);
  }
  if (!presentationStartMessage.text().includes('start_fx=') || !presentationStartMessage.text().includes('audio=true')) {
    throw new Error(`Technique presentation did not start VFX/audio: ${presentationStartMessage.text()}`);
  }
  if (!presentationImpactMessage.text().includes('fx=') || !presentationImpactMessage.text().includes('audio=true')) {
    throw new Error(`Technique presentation did not resolve impact VFX/audio: ${presentationImpactMessage.text()}`);
  }
  if (runtimeErrors.length > 0) {
    throw new Error(`Combat VFX runtime errors:\n${runtimeErrors.join('\n')}`);
  }

  console.log(
    `Combat VFX smoke passed: ${startMessage.text()} | ${presentationStartMessage.text()} | ` +
    `${impactMessage.text()} | ${presentationImpactMessage.text()}`
  );
  await page.close();
} finally {
  await browser.close();
}
