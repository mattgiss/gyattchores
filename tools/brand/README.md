# Brand tools

Three small scripts that redraw the pictures the stores and the website use. Each one rewrites
files that are already in the repo, so running them without changing anything leaves `git status`
clean; that is the check that they still work.

```
cd tools/brand
npm install                      # once
npx playwright install chromium  # once, if this computer has never run Playwright
```

| Script | What it redraws | When to run it |
|---|---|---|
| `node icon.js` | The "dyw" icon: `launch/brand/*.svg`, the Android launcher vector, the iOS 1024 icon, the Play 512 icon | After changing the lettering, its size or its colours (all at the top of `icon.js`) |
| `node banner.js` | `android/PlayStore/graphics/feature-graphic.png`, from `banner.html` | After retaking the phone screenshots, or changing the banner's words |
| `node site-images.js` | The website's pictures of the app, into `out/site-img/` | After retaking the phone screenshots |

The website is on the `main` branch, so its copies are not rewritten in place. `icon.js` leaves the
website's icon in `out/`, and `site-images.js` leaves its pictures in `out/site-img/`; copy them
to the site's root and its `img/` folder on `main`.

Order when the app's look changes: `android/PlayStore/take-screenshots.sh`, then `banner.js`,
then `site-images.js`.

The player characters have their own tool, `tools/characters/`.
