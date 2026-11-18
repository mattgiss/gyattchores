// Makes the website's pictures of the app from the Play Store phone screenshots.
//
//   cd tools/brand && npm install && node site-images.js
//
// Writes six 540 x 960 JPEGs and social.png to tools/brand/out/site-img/. The website lives on
// the main branch: copy them into its img/ folder there.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const root = path.join(__dirname, '..', '..');
const shots = path.join(root, 'android/PlayStore/screenshots/phone');
const out = path.join(__dirname, 'out', 'site-img');
const names = [['01-scoreboard', 'scoreboard'], ['02-private-by-design', 'welcome'], ['03-pick-chores', 'pick'],
  ['04-todays-card', 'card'], ['05-your-own-chores', 'chores'], ['06-approvals', 'approvals']];
(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  for (const [from, to] of names) {
    const page = await browser.newPage({ viewport: { width: 540, height: 960 }, deviceScaleFactor: 1 });
    await page.setContent('<body style="margin:0;background:#000"><img id="i" style="width:540px;height:960px;display:block"></body>');
    const data = fs.readFileSync(path.join(shots, from + '.png')).toString('base64');
    await page.evaluate((d) => new Promise((done) => { const i = document.getElementById('i'); i.onload = done; i.src = 'data:image/png;base64,' + d; }), data);
    await page.screenshot({ path: path.join(out, to + '.jpg'), type: 'jpeg', quality: 84 });
    await page.close();
  }
  await browser.close();
  fs.copyFileSync(path.join(root, 'android/PlayStore/graphics/feature-graphic.png'), path.join(out, 'social.png'));
  console.log('Website pictures written to tools/brand/out/site-img/.');
})();
