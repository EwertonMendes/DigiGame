import { chromium } from 'playwright';

const url = process.env.DIGIGAME_URL ?? 'http://127.0.0.1:8000';
const debugHubUrl = (() => {
  const target = new URL(url);
  target.searchParams.set('debug', '1');
  target.searchParams.set('test_hub', '1');
  return target.toString();
})();
const debugInteriorUrl = (() => {
  const target = new URL(url);
  target.searchParams.set('debug', '1');
  target.searchParams.set('interior_test', 'digilab');
  return target.toString();
})();
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

async function openWorld(page) {
  const ready = waitForConsole(page, '[World] READY', 60000);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForCanvas(page);
  await ready;
  await settleFrames(page, 4);
}

async function openInterior(page) {
  const worldReady = waitForConsole(page, '[World] READY', 60000);
  const interiorReady = waitForConsole(page, '[World] INTERIOR_ENTER id=debug_digilab', 60000);
  await page.goto(debugInteriorUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await waitForCanvas(page);
  await worldReady;
  await interiorReady;
  await settleFrames(page, 5);
}

async function openHub(page) {
  const ready = waitForConsole(page, '[Hub] READY', 60000);
  await page.goto(debugHubUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
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

async function confirmBasicBattleProgram(page) {
  // The workspace opens on the committed Basic Battle selection. Navigation is
  // distinct from selection: Right moves to the selected battlefield, Right
  // again moves to the persistent START BATTLE action, then Enter launches.
  // This path is shared by desktop and compact Program/Field layouts.
  await page.keyboard.press('ArrowRight');
  await settleFrames(page, 1);
  await page.keyboard.press('ArrowRight');
  await settleFrames(page, 1);
  await page.keyboard.press('Enter');
}

async function waitForBattlePresentation(page) {
  // The intro animation is presentation, not the browser test contract. Prefer
  // its completion marker, but do not fail solely because a throttled headless
  // renderer delivers Tween.finished late. Combat QA below still proves that
  // the battle loop is interactive, and page/WASM errors remain hard failures.
  await Promise.race([
    waitForConsole(page, '[BattleIntro] BATTLE_START', 9000).catch(() => null),
    page.waitForTimeout(7000),
  ]);
  await settleFrames(page, 3);
}

async function enterTestBattle(page, captureDialogue = false) {
  const dialogueOpened = waitForConsole(page, '[Hub] DIALOGUE_OPEN');
  await page.keyboard.down('KeyE');
  // Capture while the key-down frame is still inside the authored 0.34 s
  // construction window. Waiting for DIALOGUE_OPEN first made the old snapshots
  // too late to catch one-frame/early-frame rendering defects.
  if (captureDialogue) {
    await page.waitForTimeout(28);
    await page.screenshot({ path: 'build/hub-battle-dialog-opening-early.png', fullPage: true });
    await page.waitForTimeout(70);
    await page.screenshot({ path: 'build/hub-battle-dialog-opening-mid.png', fullPage: true });
  }
  await page.keyboard.up('KeyE');
  await dialogueOpened;
  // Inputs are intentionally blocked while the digital construction owns the UI.
  // Wait beyond the authored 0.34 s open duration before navigating the workspace.
  await page.waitForTimeout(380);
  if (captureDialogue) {
    await page.screenshot({ path: 'build/hub-battle-dialog.png', fullPage: true });
  }

  const battleStarted = waitForConsole(page, '[Hub] START_BATTLE_PROGRAM program=basic');
  const battleReady = waitForConsole(page, '[Battle] READY', 30000);
  await confirmBasicBattleProgram(page);
  await Promise.all([battleStarted, battleReady]);
  await waitForBattlePresentation(page);
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

async function exerciseBattleOperatorCloseTransition(page) {
  const dialogueOpened = waitForConsole(page, '[Hub] DIALOGUE_OPEN');
  await page.keyboard.press('KeyE');
  await dialogueOpened;
  await page.waitForTimeout(380);
  await page.keyboard.down('Escape');
  await page.waitForTimeout(24);
  await page.screenshot({ path: 'build/hub-battle-dialog-closing-early.png', fullPage: true });
  await page.waitForTimeout(60);
  await page.screenshot({ path: 'build/hub-battle-dialog-closing-mid.png', fullPage: true });
  await page.keyboard.up('Escape');
  await page.waitForTimeout(320);
  await page.screenshot({ path: 'build/hub-battle-dialog-closed.png', fullPage: true });
}


async function runDesktopSuite() {
  const page = await browser.newPage({ viewport: desktopViewports[0] });
  watchRuntimeErrors(page, 'desktop');
  await openWorld(page);
  await page.screenshot({ path: 'build/world-smoke.png', fullPage: true });

  // Smoke the V2 menu surface from the actual campaign world.

  await page.keyboard.press('KeyM');
  await settleFrames(page, 3);
  await page.screenshot({ path: 'build/digimon-technique-library.png', fullPage: true });
  await page.keyboard.press('Escape');

  // Keep a real keyboard movement interaction in coverage.
  await page.keyboard.down('KeyA');
  await page.waitForTimeout(300);
  await page.keyboard.up('KeyA');
  await settleFrames(page, 2);
  await page.screenshot({ path: 'build/world-movement.png', fullPage: true });

  // Review a real large interior in the same browser pass. This uses a
  // developer-only route so QA does not depend on scripted walking coordinates.
  await openInterior(page);
  await page.screenshot({ path: 'build/world-interior-digilab.png', fullPage: true });

  // Combat QA still uses the preserved Test Hub, reached only through the
  // developer-only query route. Normal players never enter this scene.
  await openHub(page);
  await page.screenshot({ path: 'build/hub-smoke.png', fullPage: true });
  await exerciseBattleOperatorCloseTransition(page);
  await enterTestBattle(page, true);
  await page.screenshot({ path: 'build/web-smoke.png', fullPage: true });

  // Resizing itself is the contract here. Godot/Web may update the backing
  // canvas on a later renderer tick, so exact CSS pixel equality is too brittle.
  for (const viewport of desktopViewports) {
    await page.setViewportSize(viewport);
    await settleFrames(page, 4);
    await page.screenshot({ path: `build/desktop-${viewport.width}x${viewport.height}.png`, fullPage: true });
  }

  await page.close();
}

async function runCombatVfxSuite() {
  const page = await browser.newPage({ viewport: desktopViewports[0] });
  watchRuntimeErrors(page, 'combat-vfx');
  await openHub(page);
  await enterTestBattle(page);

  // Validate the battle itself, not fragile command-menu pixels. Advancing turns
  // must produce a real attack and its presentation/VFX/audio markers.
  const impactEvent = waitForConsole(page, '[CombatFX] IMPACT', 30000);
  const presentationStartEvent = waitForConsole(page, '[CombatPresentation] phase=start', 30000);
  const presentationImpactEvent = waitForConsole(page, '[CombatPresentation] phase=impact', 30000);

  const startMessage = await advanceUntilMarker(page, '[CombatFX] START', 48, 320);
  const presentationStartMessage = await presentationStartEvent;
  await page.screenshot({ path: 'build/combat-vfx-windup.png', fullPage: true });

  const impactMessage = await impactEvent;
  const presentationImpactMessage = await presentationImpactEvent;
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
  await openWorld(page);
  await page.screenshot({ path: 'build/world-mobile-portrait.png', fullPage: true });

  // V2 menu should open/close on the mobile-sized viewport, but exact pixels are
  // deliberately not part of this regression contract.
  await page.keyboard.press('KeyM');
  await settleFrames(page, 3);
  await page.screenshot({ path: 'build/digimon-technique-library-mobile.png', fullPage: true });
  await page.keyboard.press('Escape');

  const client = await page.context().newCDPSession(page);
  const worldTouchStarted = waitForConsole(page, '[World] TOUCH_MOVE');
  // The new campaign HUD anchors a compact joystick to the lower-left safe
  // area. Start in its center and drag right, matching a real thumb gesture.
  await dispatchTouch(client, 'touchStart', [{ x: 29, y: 815 }]);
  await page.waitForTimeout(60);
  await dispatchTouch(client, 'touchMove', [{ x: 43, y: 815 }]);
  await worldTouchStarted;
  await page.waitForTimeout(300);
  await dispatchTouch(client, 'touchEnd', []);
  await settleFrames(page, 2);
  await page.screenshot({ path: 'build/world-mobile-movement.png', fullPage: true });

  // Switch to the developer-only Test Hub for the existing battle interaction
  // coverage; this also proves the legacy Hub remains independently runnable.
  await openHub(page);
  await page.screenshot({ path: 'build/hub-mobile-portrait.png', fullPage: true });
  const mobileDialogueOpened = waitForConsole(page, '[Hub] DIALOGUE_OPEN');
  await page.touchscreen.tap(320, 776);
  await mobileDialogueOpened;
  await settleFrames(page, 2);
  await page.screenshot({ path: 'build/hub-mobile-dialog.png', fullPage: true });

  const battleStarted = waitForConsole(page, '[Hub] START_BATTLE_PROGRAM program=basic');
  const battleReady = waitForConsole(page, '[Battle] READY', 30000);
  await confirmBasicBattleProgram(page);
  await Promise.all([battleStarted, battleReady]);
  await waitForBattlePresentation(page);
  await page.screenshot({ path: 'build/mobile-portrait.png', fullPage: true });

  await page.setViewportSize(mobileViewports[1]);
  await settleFrames(page, 4);
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
