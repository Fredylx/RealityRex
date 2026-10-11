import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title2.weight(.bold))

                Text("Last updated: October 10, 2026")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text("Summary")
                    .font(.headline)
                Text("RealityRex itself does not collect or store personal data. All AR experiences run locally on your device. A small banner ad is shown by Google AdMob (see Advertising).")

                Text("Camera")
                    .font(.headline)
                Text("The camera is used to provide the augmented reality experience. Camera data is processed on-device and is not stored or transmitted.")

                Text("Advertising")
                    .font(.headline)
                Text("RealityRex shows one small banner ad from Google AdMob. Because the app is made for families with children, every ad request is marked as directed to children (COPPA), limited to content suitable for all ages, and never personalized. The app does not ask for tracking permission or use your advertising identifier. Google may process limited technical data (such as IP address and device type) to serve and measure ads, as described at policies.google.com/technologies/partner-sites.")

                Text("Analytics and Tracking")
                    .font(.headline)
                Text("We do not use third‑party analytics or tracking SDKs in the app.")

                Text("Contact")
                    .font(.headline)
                Text("If you have questions about this policy, contact us at the support email provided in the App Store listing.")
            }
            .padding()
        }
    }
}
