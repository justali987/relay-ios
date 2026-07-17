import SwiftUI

/// Optional one-time/annual purchase for genuinely additive features. The core remote stays free
/// and fully useful without this — see PRD monetization principles. Purchase logic is stubbed
/// (no StoreKit wiring yet); this screen establishes the UI and copy.
struct RelayPlusView: View {
    @State private var isPurchasing = false
    @State private var purchaseState: PurchaseState = .notPurchased

    private enum PurchaseState { case notPurchased, purchased }

    private let features = [
        ("wand.and.stars", "Advanced multi-device scenes", "Chain more devices and conditions into a single Quick Action."),
        ("applewatch", "Apple Watch companion", "Volume, D-pad, and favorites from your wrist."),
        ("paintpalette", "Custom themes & layouts", "Personalize the Remote screen's look and control arrangement."),
        ("questionmark.circle", "Premium diagnostics & support", "Priority troubleshooting help and deeper connection diagnostics."),
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: RelaySpacing.sm) {
                    Text("Relay Plus")
                        .font(.relayTitle)
                    Text("The core remote is free, forever — no account, no ads, no forced trial. Relay Plus adds a few genuinely extra features for people who want them.")
                        .font(.relaySubheadline)
                        .foregroundStyle(Color.relayTextSecondary)
                }
                .padding(.vertical, RelaySpacing.sm)
            }

            Section("What's included") {
                ForEach(features, id: \.1) { feature in
                    Label {
                        VStack(alignment: .leading) {
                            Text(feature.1).font(.relayBodyEmphasized)
                            Text(feature.2).font(.relayCaption).foregroundStyle(Color.relayTextSecondary)
                        }
                    } icon: {
                        Image(systemName: feature.0).foregroundStyle(Color.relayAccent)
                    }
                }
            }

            Section {
                if purchaseState == .purchased {
                    Label("Relay Plus is active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Color.relayStatusConnected)
                } else {
                    Button {
                        Task { await purchase() }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                        } else {
                            Text("Get Relay Plus")
                        }
                    }
                    .buttonStyle(RelayPrimaryButtonStyle())
                    .listRowBackground(Color.clear)
                }

                Button("Restore Purchases") {
                    Task { await restore() }
                }
            }
        }
        .navigationTitle("Relay Plus")
    }

    private func purchase() async {
        // TODO: wire to StoreKit 2 when a specific product/price is finalized.
        isPurchasing = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isPurchasing = false
    }

    private func restore() async {
        // TODO: StoreKit 2 `AppStore.sync()` + entitlement re-check.
    }
}

#Preview {
    NavigationStack {
        RelayPlusView()
    }
}
