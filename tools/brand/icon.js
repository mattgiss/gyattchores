// Redraws the "dyw" icon everywhere it lives, from one definition.
//
//   cd tools/brand && npm install && node icon.js
//
// Writes, in the repo: launch/brand/dyw-icon.svg and dyw-mark.svg, the Android launcher's
// foreground vector, the iOS app icon (1024) and the Play listing icon (512).
// Writes to tools/brand/out/: dyw-icon.svg (rounded) and apple-touch-icon.png for the website,
// which lives on the main branch; copy them there by hand.
const fs = require('fs');
const path = require('path');
const opentype = require('opentype.js');
const { chromium } = require('playwright');

const root = path.join(__dirname, '..', '..');
const out = path.join(__dirname, 'out');
const buf = fs.readFileSync(require.resolve('@fontsource/pacifico/files/pacifico-latin-400-normal.woff'));
const font = opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));

// The mark: "dyw" in Pacifico (SIL Open Font License), as outlines, fitted to a width and centred in a 512 box.
function mark(width, cx = 256, cy = 256) {
  const b = font.getPath('dyw', 0, 0, 200).getBoundingBox();
  const size = 200 * width / (b.x2 - b.x1);
  const bb = font.getPath('dyw', 0, 0, size).getBoundingBox();
  const p = font.getPath('dyw', cx - (bb.x1 + bb.x2) / 2, cy - (bb.y1 + bb.y2) / 2, size);
  return { d: p.toPathData(1), box: p.getBoundingBox() };
}
// Top to bottom of the lettering. Change the colours here and run again.
const stops = [['0', '#FF3B2F'], ['0.55', '#E2751C'], ['1', '#EDB82A']];
function svg({ width, bg, round }) {
  const m = mark(width);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs><linearGradient id="heat" gradientUnits="userSpaceOnUse" x1="0" y1="${m.box.y1.toFixed(1)}" x2="0" y2="${m.box.y2.toFixed(1)}">
${stops.map(([o, c]) => `    <stop offset="${o}" stop-color="${c}"/>`).join('\n')}
  </linearGradient></defs>
${bg ? `  <rect width="512" height="512" ${round ? 'rx="112" ' : ''}fill="#000"/>\n` : ''}  <path fill="url(#heat)" d="${m.d}"/>
</svg>
`;
}

fs.mkdirSync(out, { recursive: true });
const square = svg({ width: 330, bg: true, round: false });   // full square: iOS and Play round the corners themselves
const rounded = svg({ width: 330, bg: true, round: true });   // the website's own icon
fs.writeFileSync(path.join(root, 'launch/brand/dyw-icon.svg'), square);
fs.writeFileSync(path.join(root, 'launch/brand/dyw-mark.svg'), svg({ width: 400, bg: false }));
fs.writeFileSync(path.join(out, 'dyw-icon.svg'), rounded);

// Android adaptive foreground: a launcher only promises to show the middle 61% of the layer.
const a = mark(250);
fs.writeFileSync(path.join(root, 'android/app/src/main/res/drawable/ic_launcher_foreground.xml'), `<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="512" android:viewportHeight="512">
    <!-- "dyw" in Pacifico (SIL Open Font License), as outlines. Kept inside the middle of the layer, the
         only part every launcher shape shows. The same shape is the themed (monochrome) icon. -->
    <path android:pathData="${a.d}">
        <aapt:attr name="android:fillColor">
            <gradient android:type="linear" android:startX="0" android:startY="${a.box.y1.toFixed(1)}" android:endX="0" android:endY="${a.box.y2.toFixed(1)}">
${stops.map(([o, c]) => `                <item android:offset="${o}" android:color="#FF${c.slice(1)}" />`).join('\n')}
            </gradient>
        </aapt:attr>
    </path>
</vector>
`);

(async () => {
  const browser = await chromium.launch();
  const jobs = [
    [square, 1024, path.join(root, 'ios/GyattChores/Assets.xcassets/AppIcon.appiconset/icon-1024.png'), false],
    [square, 512, path.join(root, 'android/PlayStore/graphics/icon-512.png'), false],
    [rounded, 360, path.join(out, 'apple-touch-icon.png'), true],
  ];
  for (const [source, px, file, transparent] of jobs) {
    const page = await browser.newPage({ viewport: { width: px, height: px }, deviceScaleFactor: 1 });
    await page.setContent(`<body style="margin:0;background:${transparent ? 'transparent' : '#000'}">${source.replace('width="512" height="512"', `width="${px}" height="${px}" style="display:block"`)}</body>`);
    await page.screenshot({ path: file, omitBackground: transparent });
    await page.close();
  }
  await browser.close();
  console.log('Icon redrawn. For the website, copy tools/brand/out/dyw-icon.svg and apple-touch-icon.png to the main branch.');
})();
