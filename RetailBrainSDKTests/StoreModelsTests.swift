import XCTest
@testable import RetailBrainSDK

final class StoreModelsTests: XCTestCase {

    func testStoreItemEquality_UsesLocationNameOnly() {
        let first = StoreItem(name: "Apple", imageName: "a", locationName: "L1", spaceId: "s1")
        let second = StoreItem(name: "Nike", imageName: "n", locationName: "L1", spaceId: "s2")

        XCTAssertEqual(first, second)
    }

    func testStoreItemHash_UsesLocationNameOnly() {
        let first = StoreItem(name: "A", imageName: "1", locationName: "Same", spaceId: "s1")
        let second = StoreItem(name: "B", imageName: "2", locationName: "Same", spaceId: "s2")

        XCTAssertEqual(first.hashValue, second.hashValue)
    }

    func testStoreDetailsInitFromStoreItem_CopiesExpectedValues() {
        let item = StoreItem(name: "Starbucks", imageName: "starbucks", locationName: "Food Court", spaceId: "space-1")

        let details = StoreDetails(from: item, coordinates: (10.0, 20.0))

        XCTAssertEqual(details.name, "Starbucks")
        XCTAssertEqual(details.imageName, "starbucks")
        XCTAssertEqual(details.locationName, "Food Court")
        XCTAssertEqual(details.spaceId, "space-1")
        XCTAssertEqual(details.coordinates?.0, 10.0)
        XCTAssertEqual(details.coordinates?.1, 20.0)
    }

    func testRetailBrainConfigInit_AssignsAllProperties() {
        let config = RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map")

        XCTAssertEqual(config.apiKey, "key")
        XCTAssertEqual(config.apiSecret, "secret")
        XCTAssertEqual(config.mapId, "map")
    }
}
