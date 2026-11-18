// Redraws the Play Store feature graphic from banner.html and the current phone screenshots.
// Retake the screenshots first (android/PlayStore/take-screenshots.sh) if the app has changed.
//
//   cd tools/brand && npm install && node banner.js
//
// Writes android/PlayStore/graphics/feature-graphic.png. The website uses the same picture as
// its link preview (img/social.png on the main branch).
const path = require('path');
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 500 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'banner.html'));
  await page.waitForLoadState('load');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(__dirname, '..', '..', 'android/PlayStore/graphics/feature-graphic.png') });
  await browser.close();
  console.log('Banner redrawn.');
})();
