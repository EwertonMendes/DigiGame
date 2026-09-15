import { chromium } from 'playwright';

const url = process.env.DIGIGAME_URL ?? 'http://127.0.0.1:8000';
const requestedSuite = process.env.SMOKE_SUITE ?? 'desktop';
const suite = requestedSuite === 'combat' || requestedSuite === 'vfx' ? 'combat-vfx' : requestedSuite;
const runtimeErrors = [];
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_BIN ?? '/usr/bin/google-chrome',
});

const desktopViewports = [
  { width: 1365, height: 685 },
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

function waitForConsole(page, marker, timeout = 15000) {
  return page.waitForEvent('console', {
    predicate: message => message.text().includes(marker),
    timeout,
  });
}

async function settleFrames(page, frames = 3) {
  await page.evaluate(async frameCount => {
    for (let index = 0; index < frameCount; index += 1) {
      await new Promise(resolve => requestAnimationFrame(() => resolve()));
    }
  }, frames);
}

async function waitForCanvas(page) {
  await page.waitForSelector('canvas', { state: 'visible', timeout: 60000 });
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    return canvas && canvas.width > 100 && canvas.height > 100;
  }, null, { timeout: 60000 });
}

async function openHub(page) {
  const ready = waitForConsole(page, '[Hub] READY', 60000);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForCanvas(page);
  await ready;
  await settleFrames(page, 3);
}

async function reloadHub(page) {
  const ready = waitForConsole(page, '[Hub] READY', 60000);
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForCanvas(page);
  await ready;
  await settleFrames(page, 3);
}

async function confirmBattleDialog(page) {
  // UI V2 deliberately focuses the safe/cancel action first. Navigate to the
  // affirmative action explicitly so browser QA validates the same keyboard /
  // controller focus contract players use instead of relying on old defaults.
  await page.keyboard.press('ArrowRight');
  await settleFrames(page, 1);
  await page.keyboard.press('Enter');
}

async function waitForBattlePresentation(page) {
  // The battle scene being ready is the functional contract. The intro banner
  // is presentation and should not make browser QA flaky on throttled renderers.
  // Prefer its real completion marker when it arrives, but fall back to the
  // authored intro window. Core combat tests below still prove that gameplay is
  // interactive, and any WASM/page runtime error remains a hard failure.
  await Promise.race([
    waitForConsole(page, '[BattleIntro] BATTLE_START', 9000).catch(() => null),
    page.waitForTimeout(7000),
  ]);
  await settleFrames(page, 4);
}

async function enterTestBattle(page, captureDialogue = false) {
  const dialogueOpened = waitForConsole(page, '[Hub] DIALOGUE_OPEN');
  await page.keyboard.press('KeyE');
  await dialogueOpened;
  await settleFrames(page, 2);
  if (captureDialogue) {
    await page.screenshot({ path: 'build/hub-battle-dialog.png', fullPage: true });
  }

  const battleStarted = waitForConsole(page, '[Hub] START_TEST_BATTLE');
  const battleReady = waitForConsole(page, '[Battle] READY', 30000);
  await confirmBattleDialog(page);
  await Promise.all([battleStarted, battleReady]);
  await waitForBattlePresentation(page);
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

async function advanceUntilMarker(page, marker, attempts = 48, intervalMs = 320) {
  const markerPromise = waitForConsole(page, marker, 30000);
  let stopped = false;
  const advance = (async () => {
    for (let attempt = 0; attempt < attempts && !stopped; attempt += 1) {
      await page.keyboard.press('Digit5');
      await page.waitForTimeout(intervalMs);
    }
  })();
  const message = await markerPromise;
  stopped = true;
  await advance;
  return message;
}

async function runDesktopSuite() {
  const page = await browser.newPage({ viewport: desktopViewports[0] });
  watchRuntimeErrors(page, 'desktop');
  await openHub(page);

  const beforeDigimonMenu = await page.screenshot();
  await page.keyboard.press('KeyM');
  await settleFrames(page, 3);
  const techniqueLibrary = await page.screenshot();
  assertScreensDiffer(beforeDigimonMenu, techniqueLibrary, 'Digimon technique library opening');
  await page.screenshot({ path: 'build/digimon-technique-library.png', fullPage: true });
  await page.keyboard.press('Escape');
  await settleFrames(page, 2);

  const hubBaseline = await page.screenshot();
  await page.keyboard.down('KeyA');
  await page.waitForTimeout(350);
  await page.keyboard.up('KeyA');
  await settleFrames(page, 2);
  const hubMoved = await page.screenshot();
  assertScreensDiffer(hubBaseline, hubMoved, 'Overworld player movement');
  await page.screenshot({ path: 'build/hub-movement.png', fullPage: true });

  await reloadHub(page);
  await page.screenshot({ path: 'build/hub-smoke.png', fullPage: true });
  await enterTestBattle(page, true);

  for (const viewport of desktopViewports) {
    await page.setViewportSize(viewport);
    await settleFrames(page, 3);
    assertViewportFill(await readLayout(page));
    if (viewport.width === 1365 && viewport.height === 685) {
      await page.mouse.move(viewport.width * 0.5, viewport.height * 0.5);
      await settleFrames(page, 2);
      await page.screenshot({ path: 'build/laptop-1365x685.png', fullPage: true });
    }
  }

  await page.setViewportSize(desktopViewports[0]);
  await settleFrames(page, 3);
  const finalLayout = await readLayout(page);
  const centerX = finalLayout.viewportWidth * 0.5;
  const centerY = finalLayout.viewportHeight * 0.5;
  await page.mouse.move(centerX, centerY);
  await settleFrames(page, 2);
  await page.screenshot({ path: 'build/web-smoke.png', fullPage: true });

  await page.mouse.click(centerX, centerY, { button: 'left' });
  await settleFrames(page, 2);
  const facingTargets = [
    ['up-left', centerX - 220, centerY - 150],
    ['up-right', centerX + 220, centerY - 150],
    ['down-right', centerX + 220, centerY + 150],
    ['down-left', centerX - 220, centerY + 150],
  ];
  for (const [name, x, y] of facingTargets) {
    await page.mouse.move(x, y, { steps: 6 });
    await page.waitForTimeout(120);
    await page.screenshot({ path: `build/gabumon-facing-${name}.png`, fullPage: true });
  }

  await page.mouse.click(centerX - 120, centerY + 70, { button: 'left' });
  await page.waitForTimeout(420);
  await page.screenshot({ path: 'build/gabumon-facing-persisted.png', fullPage: true });

  await page.mouse.move(centerX + 180, centerY + 110);
  await page.mouse.down({ button: 'right' });
  await page.mouse.move(centerX - 240, centerY - 150, { steps: 10 });
  await page.mouse.up({ button: 'right' });
  await page.waitForTimeout(240);
  await page.screenshot({ path: 'build/camera-pan-smoke.png', fullPage: true });

  await page.keyboard.press('Equal');
  await page.keyboard.down('KeyA');
  await page.waitForTimeout(250);
  await page.keyboard.up('KeyA');
  await settleFrames(page, 3);
  await page.screenshot({ path: 'build/keyboard-camera-smoke.png', fullPage: true });
  await page.close();
}

async function runCombatVfxSuite() {
  const page = await browser.newPage({ viewport: { width: 1365, height: 685 } });
  watchRuntimeErrors(page, 'combat-vfx');
  await openHub(page);
  await enterTestBattle(page);

  const baseline = await page.screenshot();
  await page.keyboard.press('Digit2');
  await settleFrames(page, 3);
  const attackTargeting = await page.screenshot();
  assertScreensDiffer(baseline, attackTargeting, 'Basic attack targeting mode');
  await page.screenshot({ path: 'build/combat-attack-targeting.png', fullPage: true });
  await page.keyboard.press('Escape');
  await settleFrames(page, 2);

  const beforeSkillMenu = await page.screenshot();
  await page.keyboard.press('Digit3');
  await settleFrames(page, 3);
  const submenuOpen = await page.screenshot();
  assertScreensDiffer(beforeSkillMenu, submenuOpen, 'Technique submenu opening');
  await page.screenshot({ path: 'build/combat-skill-menu.png', fullPage: true });

  await page.keyboard.press('Enter');
  await settleFrames(page, 3);
  const targeting = await page.screenshot();
  assertScreensDiffer(submenuOpen, targeting, 'Immediate first-technique keyboard selection');
  await page.keyboard.press('Escape');
  await settleFrames(page, 2);

  await page.keyboard.press('Digit3');
  await settleFrames(page, 3);
  const submenuReopened = await page.screenshot();
  await page.keyboard.press('ArrowRight');
  await settleFrames(page, 2);
  const returnedToSkill = await page.screenshot();
  assertScreensDiffer(submenuReopened, returnedToSkill, 'Horizontal submenu return');

  await page.keyboard.press('Enter');
  await settleFrames(page, 3);
  const reopenedFromParentFocus = await page.screenshot();
  assertScreensDiffer(returnedToSkill, reopenedFromParentFocus, 'Restored Skill parent focus');
  await page.screenshot({ path: 'build/keyboard-technique-submenu.png', fullPage: true });
  await page.keyboard.press('ArrowLeft');
  await settleFrames(page, 2);

  const beforeTurnProgression = await page.screenshot();
  const impactEvent = waitForConsole(page, '[CombatFX] IMPACT', 30000);
  const presentationStartEvent = waitForConsole(page, '[CombatPresentation] phase=start', 30000);
  const presentationImpactEvent = waitForConsole(page, '[CombatPresentation] phase=impact', 30000);

  const startMessage = await advanceUntilMarker(page, '[CombatFX] START', 48, 320);
  const presentationStartMessage = await presentationStartEvent;
  await settleFrames(page, 2);
  const windup = await page.screenshot();
  assertScreensDiffer(beforeTurnProgression, windup, 'CT turn progression, enemy AI and attack windup');
  await page.screenshot({ path: 'build/combat-vfx-windup.png', fullPage: true });

  const impactMessage = await impactEvent;
  const presentationImpactMessage = await presentationImpactEvent;
  await settleFrames(page, 2);
  const afterImpact = await page.screenshot();
  assertScreensDiffer(beforeTurnProgression, afterImpact, 'Combat impact presentation');
  await page.screenshot({ path: 'build/combat-vfx-impact.png', fullPage: true });

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
  await page.close();
}

async function runMobileSuite() {
  const page = await browser.newPage({
    viewport: mobileViewports[0],
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 1,
  });
  watchRuntimeErrors(page, 'mobile');
  await openHub(page);
  assertViewportFill(await readLayout(page));
  await page.screenshot({ path: 'build/hub-mobile-portrait.png', fullPage: true });

  const beforeMobileMenu = await page.screenshot();
  await page.keyboard.press('KeyM');
  await settleFrames(page, 3);
  const mobileTechniqueLibrary = await page.screenshot();
  assertScreensDiffer(beforeMobileMenu, mobileTechniqueLibrary, 'Mobile Digimon technique library opening');
  await page.screenshot({ path: 'build/digimon-technique-library-mobile.png', fullPage: true });
  await page.keyboard.press('Escape');
  await settleFrames(page, 2);

  const client = await page.context().newCDPSession(page);
  const hubTouchStarted = waitForConsole(page, '[Hub] TOUCH_MOVE direction=right pressed=true');
  await dispatchTouch(client, 'touchStart', [{ x: 163, y: 739 }]);
  await hubTouchStarted;
  await page.waitForTimeout(350);
  await dispatchTouch(client, 'touchEnd', []);
  await settleFrames(page, 2);
  await page.screenshot({ path: 'build/hub-mobile-movement.png', fullPage: true });

  await reloadHub(page);
  const mobileDialogueOpened = waitForConsole(page, '[Hub] DIALOGUE_OPEN');
  await page.touchscreen.tap(320, 776);
  await mobileDialogueOpened;
  await settleFrames(page, 2);
  await page.screenshot({ path: 'build/hub-mobile-dialog.png', fullPage: true });

  const battleStarted = waitForConsole(page, '[Hub] START_TEST_BATTLE');
  const battleReady = waitForConsole(page, '[Battle] READY', 30000);
  await confirmBattleDialog(page);
  await Promise.all([battleStarted, battleReady]);
  await waitForBattlePresentation(page);

  let layout = await readLayout(page);
  let center = { x: layout.viewportWidth * 0.5, y: layout.viewportHeight * 0.5 };
  await page.screenshot({ path: 'build/mobile-portrait.png', fullPage: true });

  const beforeButtonZoom = await page.screenshot();
  await page.touchscreen.tap(layout.viewportWidth - 30, layout.viewportHeight - 256);
  await settleFrames(page, 4);
  const afterButtonZoom = await page.screenshot();
  assertScreensDiffer(beforeButtonZoom, afterButtonZoom, 'Mobile zoom button');
  await page.screenshot({ path: 'build/mobile-zoom-button.png', fullPage: true });

  await page.touchscreen.tap(center.x, center.y);
  await settleFrames(page, 3);
  await page.screenshot({ path: 'build/mobile-touch-select.png', fullPage: true });

  const beforeTouchPan = await page.screenshot();
  await dragOneFinger(
    client,
    { x: center.x + 90, y: center.y + 90 },
    { x: center.x - 70, y: center.y - 40 },
  );
  await settleFrames(page, 4);
  const afterTouchPan = await page.screenshot();
  assertScreensDiffer(beforeTouchPan, afterTouchPan, 'One-finger touch pan');
  await page.screenshot({ path: 'build/mobile-touch-pan.png', fullPage: true });

  const beforePinch = await page.screenshot();
  await pinch(client, center, 42, 92);
  await settleFrames(page, 5);
  const afterPinch = await page.screenshot();
  assertScreensDiffer(beforePinch, afterPinch, 'Pinch zoom');
  await page.screenshot({ path: 'build/mobile-pinch-zoom.png', fullPage: true });

  await page.setViewportSize(mobileViewports[1]);
  await settleFrames(page, 4);
  assertViewportFill(await readLayout(page));
  await page.screenshot({ path: 'build/mobile-landscape.png', fullPage: true });
  await page.close();
}

const suites = {
  desktop: runDesktopSuite,
  'combat-vfx': runCombatVfxSuite,
  mobile: runMobileSuite,
};

try {
  const runner = suites[suite];
  if (!runner) {
    throw new Error(`Unknown SMOKE_SUITE '${requestedSuite}'. Expected one of: desktop, combat-vfx, mobile.`);
  }
  const startedAt = Date.now();
  await runner();
  if (runtimeErrors.length > 0) {
    throw new Error(`Browser runtime errors:\n${runtimeErrors.join('\n')}`);
  }
  console.log(`[Smoke] ${suite} suite passed in ${((Date.now() - startedAt) / 1000).toFixed(1)}s.`);
} finally {
  await browser.close();
}
