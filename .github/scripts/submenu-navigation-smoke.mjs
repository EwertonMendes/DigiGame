import { chromium } from 'playwright';

const url = process.env.DIGIGAME_URL ?? 'http://127.0.0.1:8000';
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_BIN ?? '/usr/bin/google-chrome',
});

function assertScreensDiffer(before, after, description) {
  if (before.equals(after)) {
    throw new Error(`${description} did not visibly change the rendered game.`);
  }
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

try {
  const page = await browser.newPage({ viewport: { width: 1365, height: 685 } });
  const runtimeErrors = [];
  page.on('pageerror', error => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on('console', message => {
    if (message.type() === 'error') runtimeErrors.push(`console: ${message.text()}`);
  });
  await waitForGame(page);

  const commandMenu = await page.screenshot();

  // Opening Techniques from keyboard must immediately focus the first usable
  // technique. Enter therefore chooses it without requiring an extra arrow key.
  await page.keyboard.press('Digit3');
  await page.waitForTimeout(350);
  const submenuOpen = await page.screenshot();
  assertScreensDiffer(commandMenu, submenuOpen, 'Technique submenu opening');

  await page.keyboard.press('Enter');
  await page.waitForTimeout(400);
  const targeting = await page.screenshot();
  assertScreensDiffer(submenuOpen, targeting, 'Immediate first-technique keyboard selection');

  // Cancel targeting returns to Skill. Reopen the submenu and verify horizontal
  // navigation closes the child menu and restores focus to its parent command.
  await page.keyboard.press('Escape');
  await page.waitForTimeout(250);
  await page.keyboard.press('Digit3');
  await page.waitForTimeout(350);
  const submenuReopened = await page.screenshot();

  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(250);
  const returnedToSkill = await page.screenshot();
  assertScreensDiffer(submenuReopened, returnedToSkill, 'Horizontal submenu return');

  // If focus really returned to Skill, Enter opens Techniques again. This catches
  // the intermittent focus loss that previously left no submenu item selected.
  await page.keyboard.press('Enter');
  await page.waitForTimeout(350);
  const reopenedFromParentFocus = await page.screenshot();
  assertScreensDiffer(returnedToSkill, reopenedFromParentFocus, 'Restored Skill parent focus');
  await page.screenshot({ path: 'build/keyboard-technique-submenu.png', fullPage: true });

  // Left is accepted as the symmetric/back-friendly horizontal gesture too.
  await page.keyboard.press('ArrowLeft');
  await page.waitForTimeout(200);

  if (runtimeErrors.length > 0) {
    throw new Error(`Technique submenu runtime errors:\n${runtimeErrors.join('\n')}`);
  }

  console.log('Technique submenu keyboard navigation smoke test passed.');
} finally {
  await browser.close();
}
