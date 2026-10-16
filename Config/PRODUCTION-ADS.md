# RealityRex production-ad release

Requested October 16, 2026. Status: blocked on real AdMob application/banner IDs, store metadata verification and a signed device-tested archive; ads are not reported as live.

## Current source evidence

- Release GAD_APPLICATION_IDENTIFIER and ADMOB_BANNER_UNIT_ID are empty; Debug contains Google's test IDs.
- MainARView invokes AdsBootstrap.start(), which refuses missing IDs and waits for consent before starting the SDK.
- Child-directed treatment, under-age-of-consent treatment, G content rating and non-personalized requests are already present. Verify their actual SDK behavior on a device before submission.
- The public App Store listing currently says Data Not Collected and Made for Ages 0–5. Do not assume that this remains accurate after adding an ad SDK.

## Complete the release

1. Obtain the real application ID and banner ad-unit ID from the correct AdMob app, and verify both belong to the company publisher. Do not substitute Google's test IDs in Release.
2. Set RealityRex target Release GAD_APPLICATION_IDENTIFIER and ADMOB_BANNER_UNIT_ID through the release configuration or build pipeline. Keep Debug test IDs intact.
3. Confirm the SDK's data practices and the App Store Connect audience/category and privacy declarations. Apple allows third-party contextual ads for child-directed apps only in limited cases with the required documented practices; G rating and non-personalized flags alone do not establish eligibility.
4. Build a signed Release archive on the configured Mac, then check the resolved archive plist:

```bash
python3 scripts/check_release_ads.py /path/to/RealityRex.xcarchive/Products/Applications/RealityRex.app/Info.plist
python3 -m unittest discover -s scripts -p 'test_release_ads.py' -v
```

5. On a registered test device, verify launch, consent, banner placement and ad failure/no-fill behavior without clicking live ads. Confirm SDK modules are present and no request occurs before the required treatment settings.
6. Upload the verified archive, submit accurate metadata for review, then record the accepted build/version and AdMob serving evidence. Merging code into main does not publish a new App Store build.

The preflight checks resolved ID syntax and rejects Google's public test publisher. It does not verify account ownership, ad serving, consent correctness, child-directed policy eligibility or App Store release status.

Official references, checked October 16, 2026:
- https://developer.apple.com/app-store/review/guidelines/#kids-category
- https://developers.google.com/admob/ios/quick-start
- https://developers.google.com/admob/ios/targeting

No signing credentials or real publisher IDs were available in this session. No ad-serving or billing setting was changed.
