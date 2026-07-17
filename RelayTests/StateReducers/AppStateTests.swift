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
}
