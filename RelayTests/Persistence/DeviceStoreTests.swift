import XCTest
@testable import Relay

final class DeviceStoreTests: XCTestCase {
    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("relay-store-tests-\(UUID().uuidString).json")
    }

    func testUpsertAndReloadRoundTrips() async throws {
        let url = tempFileURL()
        let store = DeviceStore(fileURL: url)

        let room = Room(name: "Living Room")
        await store.upsert(room: room)

        let device = Device(name: "Test TV", brand: .mock, host: "10.0.0.1", capabilities: [.volume], adapterDeviceID: "abc")
        await store.upsert(device: device)

        let reloaded = DeviceStore(fileURL: url)
        let rooms = await reloaded.allRooms()
        let devices = await reloaded.allDevices()

        XCTAssertEqual(rooms.count, 1)
        XCTAssertEqual(rooms.first?.name, "Living Room")
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.name, "Test TV")
    }

    func testDeleteDeviceClearsRoomReferences() async throws {
        let store = DeviceStore(fileURL: tempFileURL())
        var room = Room(name: "Office")
        let device = Device(name: "Office Display", brand: .mock, host: "10.0.0.2", adapterDeviceID: "xyz")
        room.deviceIDs = [device.id]
        room.primaryDeviceID = device.id

        await store.upsert(room: room)
        await store.upsert(device: device)
        await store.deleteDevice(id: device.id)

        let rooms = await store.allRooms()
        XCTAssertTrue(rooms.first?.deviceIDs.isEmpty ?? false)
        XCTAssertNil(rooms.first?.primaryDeviceID)
    }

    func testQuickActionUpsertAndDelete() async throws {
        let store = DeviceStore(fileURL: tempFileURL())
        let action = QuickAction(name: "Movie Night")
        await store.upsert(quickAction: action)
        XCTAssertEqual((await store.allQuickActions()).count, 1)

        await store.deleteQuickAction(id: action.id)
        XCTAssertTrue((await store.allQuickActions()).isEmpty)
    }
}
