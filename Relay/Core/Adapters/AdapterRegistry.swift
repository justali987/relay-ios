import Foundation

/// Owns one adapter instance per `DeviceBrand` and is the only place in the app that maps a brand
/// to a concrete adapter type. Feature code should depend on `AdapterRegistry`, never import a
/// concrete adapter (e.g. `RokuAdapter`) directly.
actor AdapterRegistry {
    private var adaptersByBrand: [DeviceBrand: any DeviceAdapter] = [:]

    init(adapters: [any DeviceAdapter]) {
        for adapter in adapters {
            adaptersByBrand[adapter.brand] = adapter
        }
    }

    func adapter(for brand: DeviceBrand) -> (any DeviceAdapter)? {
        adaptersByBrand[brand]
    }

    func adapter(for device: Device) -> (any DeviceAdapter)? {
        adaptersByBrand[device.brand]
    }

    /// All registered adapters except the mock — used to fan discovery out across every real
    /// protocol adapter at once.
    var realAdapters: [any DeviceAdapter] {
        adaptersByBrand.values.filter { $0.brand != .mock }
    }

    /// Every registered adapter, mock included — used by the Discovery screen, which should show
    /// mock devices alongside any real ones found on the network.
    var allAdapters: [any DeviceAdapter] {
        Array(adaptersByBrand.values)
    }

    /// Builds the production registry. `tokenStore` is threaded into the adapters that persist a
    /// pairing credential (Tizen's WebSocket token today; webOS/Android TV as they land) so pairing
    /// and command-time reconnection can read/write the Keychain without each adapter owning its own
    /// store. Roku and the mock need no token and ignore it.
    static func makeDefault(tokenStore: KeychainTokenStore) -> AdapterRegistry {
        AdapterRegistry(adapters: [
            MockAdapter(),
            RokuAdapter(),
            WebOSAdapter(),
            TizenAdapter(tokenStore: tokenStore),
            AndroidTVAdapter(),
            FireTVAdapter(),
            AppleTVAdapter(),
        ])
    }
}
