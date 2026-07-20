import XCTest
@testable import Relay

@MainActor
final class AppStateTests: XCTestCase {
    private func makeAppState() -> AppState {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("relay-tests-\(UUID().uuidString).json")
        return AppState(
            deviceStore: DeviceStore(fileURL: tempURL),
            tokenStore: KeychainTokenStore(),
            adapterRegistry: AdapterRegistry(adapters: [MockAdapter()]),
            settings: AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
    }

    func testAddRoomAndPairedDevice() async throws {
        let appState = makeAppState()
        await appState.loadFromDisk()

        await appState.addRoom(named: "Living Room")
        XCTAssertEqual(appState.rooms.count, 1)
        let room = try XCTUnwrap(appState.rooms.first)

        let paired = try await appState.pair(MockScenarios.livingRoomFullyCapable, code: nil)
        await appState.addPairedDevice(paired, toRoom: room.id)

        XCTAssertEqual(appState.devices.count, 1)
        XCTAssertEqual(appState.devices(in: room.id).count, 1)
        XCTAssertEqual(appState.rooms.first?.primaryDeviceID, appState.devices.first?.id)
    }

    func testRemoveDeviceClearsRoomReferences() async throws {
        let appState = makeAppState()
        await appState.loadFromDisk()
        await appState.addRoom(named: "Bedroom")
        let room = try XCTUnwrap(appState.rooms.first)

        let paired = try await appState.pair(MockScenarios.bedroomPartialCapability, code: nil)
        await appState.addPairedDevice(paired, toRoom: room.id)
        let deviceID = try XCTUnwrap(appState.devices.first?.id)

        await appState.removeDevice(deviceID)

        XCTAssertTrue(appState.devices.isEmpty)
        XCTAssertNil(appState.rooms.first?.primaryDeviceID)
        XCTAssertTrue(appState.rooms.first?.deviceIDs.isEmpty ?? false)
    }

    func testRunQuickActionReturnsPerDeviceResults() async throws {
        let appState = makeAppState()
        await appState.loadFromDisk()
        await appState.addRoom(named: "Living Room")
        let room = try XCTUnwrap(appState.rooms.first)

        let paired = try await appState.pair(MockScenarios.livingRoomFullyCapable, code: nil)
        await appState.addPairedDevice(paired, toRoom: room.id)
        let deviceID = try XCTUnwrap(appState.devices.first?.id)

        let action = QuickAction(
            name: "Movie Night",
            roomID: room.id,
            steps: [QuickActionStep(deviceID: deviceID, command: .volumeUp)]
        )

        let results = await appState.run(action)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].succeeded)
    }

    func testRunQuickActionReportsFailureForUnsupportedCommand() async throws {
        let appState = makeAppState()
        await appState.loadFromDisk()
        await appState.addRoom(named: "Bedroom")
        let room = try XCTUnwrap(appState.rooms.first)

        // Bedroom mock device doesn't support .playback (see MockScenarios.capabilities).
        let paired = try await appState.pair(MockScenarios.bedroomPartialCapability, code: nil)
        await appState.addPairedDevice(paired, toRoom: room.id)
        let deviceID = try XCTUnwrap(appState.devices.first?.id)

        let action = QuickAction(
            name: "Bad Action",
            roomID: room.id,
            steps: [QuickActionStep(deviceID: deviceID, command: .play)]
        )

        let results = await appState.run(action)
        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].succeeded)
    }

    /// Guards the privacy contract in `AppState.discoverAllDevices`: real users must never see
    /// simulated devices in their discovery list. `makeAppState()`'s registry is mock-only, so with
    /// Demo Mode off the fan-out has nothing left to iterate and the stream should complete empty.
    func testDiscoverExcludesMockWhenDemoModeOff() async {
        let appState = makeAppState()
        appState.settings.demoModeEnabled = false

        var found: [DiscoveredDevice] = []
        for await device in appState.discoverAllDevices() {
            found.append(device)
        }

        XCTAssertTrue(found.isEmpty)
    }

    func testDiscoverIncludesMockWhenDemoModeOn() async {
        let appState = makeAppState()
        appState.settings.demoModeEnabled = true

        var found: [DiscoveredDevice] = []
        for await device in appState.discoverAllDevices() {
            found.append(device)
        }

        XCTAssertEqual(found.count, MockScenarios.allDiscoverable.count)
    }

    func testMarkRemoteScreenVisitedDoesNotQualifyBeforeThreshold() async {
        let appState = makeAppState()
        for _ in 0..<4 {
            XCTAssertFalse(appState.markRemoteScreenVisited(), "Shouldn't qualify before 5 visits across 3 days")
        }
    }

    /// `AppState.markRemoteScreenVisited` reports whether a review prompt is due, gated on
    /// `AppSettings.qualifiesForReviewPrompt` (>= 5 sessions across >= 3 distinct calendar days —
    /// see docs/06-ux-screen-spec.md). Seeds sessions directly via `AppSettings` across real
    /// distinct days so the distinct-day gate is genuinely exercised, not just the count. Must
    /// request a review at most once per launch even once the threshold is met.
    func testMarkRemoteScreenVisitedRequestsReviewOnceThresholdIsMet() async {
        let appState = makeAppState()
        let calendar = Calendar.current
        let today = Date()

        for dayOffset in [0, 1, 1, 2, 2] {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            appState.settings.recordSuccessfulSession(on: date)
        }
        XCTAssertTrue(appState.settings.qualifiesForReviewPrompt)

        XCTAssertTrue(appState.markRemoteScreenVisited(), "Should request review once the threshold is met")
        XCTAssertFalse(appState.markRemoteScreenVisited(), "Should not request review twice in one launch")
    }
}
