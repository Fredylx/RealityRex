import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title2.weight(.bold))

                Text("Last updated: February 11, 2026")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text("Summary")
                    .font(.headline)
                Text("RealityRex does not collect, store, or share personal data. All AR experiences run locally on your device.")

                Text("Camera")
                    .font(.headline)
                Text("The camera is used to provide the augmented reality experience. Camera data is processed on-device and is not stored or transmitted.")

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
