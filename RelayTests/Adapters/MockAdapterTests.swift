import XCTest
@testable import Relay

final class MockAdapterTests: XCTestCase {
    var adapter: MockAdapter!

    override func setUp() {
        super.setUp()
        adapter = MockAdapter()
    }

    func testDiscoverYieldsAllScenarioDevices() async {
        var found: [DiscoveredDevice] = []
        for await device in adapter.discover() {
            found.append(device)
        }
        XCTAssertEqual(found.count, MockScenarios.allDiscoverable.count)
        XCTAssertTrue(found.contains { $0.id == MockScenarios.livingRoomFullyCapable.id })
    }

    func testPairWithoutCodeOnPINDeviceThrowsCodeRequired() async {
        do {
            _ = try await adapter.pair(with: MockScenarios.officeRequiresPIN, code: nil)
            XCTFail("Expected pairingCodeRequired")
        } catch AdapterError.pairingCodeRequired {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPairWithWrongCodeIsRejected() async {
        do {
            _ = try await adapter.pair(with: MockScenarios.officeRequiresPIN, code: "0000")
            XCTFail("Expected pairingRejected")
        } catch AdapterError.pairingRejected {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPairWithCorrectCodeSucceeds() async throws {
        let device = try await adapter.pair(with: MockScenarios.officeRequiresPIN, code: "1234")
        XCTAssertEqual(device.status, .connected)
        XCTAssertFalse(device.capabilities.isEmpty)
    }

    func testPairingUnreachableDeviceThrows() async {
        do {
            _ = try await adapter.pair(with: MockScenarios.unreachableDevice, code: nil)
            XCTFail("Expected unreachable")
        } catch AdapterError.unreachable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendUnsupportedCommandThrows() async throws {
        let device = try await adapter.pair(with: MockScenarios.bedroomPartialCapability, code: nil)
        XCTAssertFalse(device.capabilities.contains(.playback))
        do {
            try await adapter.send(.play, to: device)
            XCTFail("Expected unsupportedCommand")
        } catch AdapterError.unsupportedCommand {
            // expected
        }
    }

    func testCheckHealthReflectsDisconnectedScenario() async throws {
        let discovered = MockScenarios.unreachableDevice
        let device = Device(
            name: discovered.name,
            brand: .mock,
            host: discovered.host,
            capabilities: [],
            adapterDeviceID: discovered.id
        )
        let status = await adapter.checkHealth(device)
        XCTAssertEqual(status, .unavailable)
    }

    func testStatusOverrideWins() async throws {
        let discovered = MockScenarios.livingRoomFullyCapable
        let device = try await adapter.pair(with: discovered, code: nil)
        adapter.setStatusOverride(.sleeping, forDeviceID: discovered.id)
        let status = await adapter.checkHealth(device)
        XCTAssertEqual(status, .sleeping)
    }
}
