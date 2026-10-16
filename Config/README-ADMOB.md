# AdMob banner (child-directed)

Debug builds use Google's public test IDs. Release currently has empty GAD_APPLICATION_IDENTIFIER and ADMOB_BANNER_UNIT_ID, so the bootstrap starts no SDK and shows no banner until real company IDs are configured.

Follow [the production-ad release checklist](PRODUCTION-ADS.md), including the compiled archive preflight and device tests. A merged source change is not an App Store release or proof of ad serving.

The runtime sets child-directed treatment, under-age-of-consent treatment, G content rating and non-personalized requests before requesting ads. Verify AdMob audience settings and App Store Connect audience/privacy metadata before enabling production serving; do not assume those flags alone meet the requirements.

Apple's current Kids guidance generally excludes third-party ads, with limited contextual-ad exceptions under Guideline 1.3. Review the actual app audience and documented ad-network practices rather than relying on the former blanket statement that changing store category would solve this.

Official references:
- https://developer.apple.com/app-store/review/guidelines/#kids-category
- https://developers.google.com/admob/ios/targeting
