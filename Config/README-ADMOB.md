# AdMob banner (child-directed)

- Debug builds use Google's public **test** IDs ("Test mode" banner).
- Release builds ship with **empty** IDs, so no SDK starts and no banner shows, until the real IDs are set in the RealityRex target's Release build settings: `GAD_APPLICATION_IDENTIFIER` and `ADMOB_BANNER_UNIT_ID`.
- In AdMob: mark the app as **directed to children** (App settings → "Tag for child-directed treatment"), and in **Blocking controls** keep the max content rating at G.
- App Store Connect: update **App Privacy** for Google Mobile Ads. Do **not** put the app in the Kids category: Apple does not allow third-party ads there.
