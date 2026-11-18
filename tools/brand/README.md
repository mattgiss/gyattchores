# Brand tools

Three small scripts that redraw the pictures the stores and the website use. Each one rewrites
files that are already in the repo, in place. Run right after the screenshots were last taken and
with nothing changed, they should leave `git status` clean; that is the check that they still work.

```
cd tools/brand
npm install                      # once
npx playwright install chromium  # once, if this computer has never run Playwright
```

| Script | What it redraws | When to run it |
|---|---|---|
| `node icon.js` | The "dyw" icon: `launch/brand/*.svg`, the Android launcher vector, the iOS 1024 icon, the Play 512 icon, and the website's `dyw-icon.svg` and `apple-touch-icon.png` | After changing the lettering, its size or its colours (all at the top of `icon.js`) |
| `node banner.js` | `android/PlayStore/graphics/feature-graphic.png` and the website's `img/social.png`, from `banner.html` | After retaking the phone screenshots, or changing the banner's words |
| `node site-images.js` | The website's six pictures of the app in `img/` | After retaking the phone screenshots |

Order when the app's look changes: `android/PlayStore/take-screenshots.sh`, then `banner.js`,
then `site-images.js`.

The player characters have their own tool, `tools/characters/`.
