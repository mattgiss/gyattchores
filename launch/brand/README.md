# The DOYOURWORK mark

"dyw", joined up, in the app's heat colours on black.

| File | What it is |
|---|---|
| `dyw-icon.svg` | The icon as a full square. The stores and the phones round the corners themselves. |
| `dyw-mark.svg` | The lettering alone, with no background, for use on anything dark. |

Where the icon lives in the apps:

- iPhone and iPad: `ios/GyattChores/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- Android: `android/app/src/main/res/drawable/ic_launcher_foreground.xml` (the lettering, as a
  vector) over a black background (`ic_launcher_background` in `values/colors.xml`)
- Google Play listing: `android/PlayStore/graphics/icon-512.png`

The lettering is the font Pacifico, used under the SIL Open Font License, drawn as outlines so
nothing needs the font installed. The colours run from `#FF3B2F` through `#E2751C` to `#EDB82A`.

## The player characters

`characters.svg` is a sheet of the sixteen characters players choose from for their scoreboard
tile: Ninja, Cat, Wizard, Robot, Bear, Bunny, Alien, Monster, Frog, Owl, Octopus, Star, King,
Astronaut, Mushroom and Flame. They are drawn for this app, in two colours, so they take on
whichever theme the phone is using.

The drawings live in one place, `tools/characters/art.mjs`, and `node tools/characters/build.mjs`
writes them out for both apps and redraws the sheet. To add or change a character, edit the
drawing there and run that; don't edit the files it writes.
