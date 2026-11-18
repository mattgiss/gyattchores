// Redraws the Play Store feature graphic from banner.html and the current phone screenshots.
// Retake the screenshots first (android/PlayStore/take-screenshots.sh) if the app has changed.
//
//   cd tools/brand && npm install && node banner.js
//
// Rewrites android/PlayStore/graphics/feature-graphic.png, and img/social.png, the same picture,
// which the website uses as its link preview.
const path = require('path');
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 500 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'banner.html'));
  await page.waitForLoadState('load');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(400);
  const root = path.join(__dirname, '..', '..');
  await page.screenshot({ path: path.join(root, 'android/PlayStore/graphics/feature-graphic.png') });
  await browser.close();
  require('fs').copyFileSync(path.join(root, 'android/PlayStore/graphics/feature-graphic.png'), path.join(root, 'img/social.png'));
  console.log('Banner redrawn.');
})();
