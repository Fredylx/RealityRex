//
//  AdBanner.swift
//  RealityRex
//
//  One small AdMob banner, configured for a CHILD-DIRECTED app (families with
//  children 6–12): every request is tagged for child-directed treatment
//  (COPPA) and capped at G-rated content, consent is requested as under the
//  age of consent, and ads are never personalized. No tracking prompt.
//
//  Debug uses Google's test IDs. Release ships with empty IDs, so the SDK
//  never starts and nothing shows until the real AdMob IDs are set
//  (starting Google Mobile Ads without a valid app ID crashes at launch).
//

import Combine
import Foundation
import OSLog
import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

enum AdsConfig {
    static var applicationID: String { value("GADApplicationIdentifier") }
    static var bannerUnitID: String { value("ADMOB_BANNER_UNIT_ID") }
    static var isConfigured: Bool { looksReal(applicationID) && looksReal(bannerUnitID) }

    private static func value(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func looksReal(_ id: String) -> Bool {
        id.hasPrefix("ca-app-pub-") && !id.contains("REPLACE") && !id.contains("$(")
    }
}

@MainActor
final class AdsBootstrap: ObservableObject {
    static let shared = AdsBootstrap()
    @Published private(set) var canShowAds = false
    private var started = false
    private let logger = Logger(subsystem: "RealityRex", category: "Ads")

    func start() {
        guard !started else { return }
        started = true
        guard AdsConfig.isConfigured else {
            logger.debug("AdMob not configured for this build; no banner")
            return
        }
        #if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
        // Child-directed settings must be in place before the SDK starts or any request is made.
        let config = MobileAds.shared.requestConfiguration
        config.tagForChildDirectedTreatment = true
        config.tagForUnderAgeOfConsent = true
        config.maxAdContentRating = .general
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = true
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error { self.logger.error("UMP consent update failed: \(error.localizedDescription, privacy: .public)") }
                guard ConsentInformation.shared.canRequestAds else { return }
                MobileAds.shared.start()
                self.canShowAds = true
            }
        }
        #endif
    }
}

/// Takes no space until AdMob is configured and consent allows ads.
struct AdBannerView: View {
    @ObservedObject private var ads = AdsBootstrap.shared

    var body: some View {
        if ads.canShowAds {
            GeometryReader { proxy in
                BannerContainer(width: proxy.size.width)
            }
            .frame(height: 50)
            .accessibilityLabel("Advertisement")
        }
    }
}

#if canImport(GoogleMobileAds)
private struct BannerContainer: UIViewRepresentable {
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: max(width, 320)))
        banner.adUnitID = AdsConfig.bannerUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
#else
private struct BannerContainer: View {
    let width: CGFloat
    var body: some View { EmptyView() }
}
#endif
