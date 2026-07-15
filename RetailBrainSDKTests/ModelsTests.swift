//
//  ModelsTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
//

import XCTest
@testable import RetailBrainSDK

// MARK: - StoreItem Tests

final class StoreItemTests: XCTestCase {

    func test_init_storesName() {
        let item = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        XCTAssertEqual(item.name, "Nike")
    }

    func test_init_storesImageName() {
        let item = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        XCTAssertEqual(item.imageName, "nike.png")
    }

    func test_init_storesLocationName() {
        let item = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        XCTAssertEqual(item.locationName, "A1")
    }

    func test_init_defaultSpaceIdIsNil() {
        let item = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        XCTAssertNil(item.spaceId)
    }

    func test_init_storesSpaceId() {
        let item = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1", spaceId: "space-001")
        XCTAssertEqual(item.spaceId, "space-001")
    }

    func test_id_isUniquePerInstance() {
        let item1 = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        let item2 = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        XCTAssertNotEqual(item1.id, item2.id)
    }

    // MARK: - Equatable (by locationName)

    func test_equality_sameLocationName_areEqual() {
        let item1 = StoreItem(name: "Nike", imageName: "a.png", locationName: "A1")
        let item2 = StoreItem(name: "Adidas", imageName: "b.png", locationName: "A1")
        XCTAssertEqual(item1, item2)
    }

    func test_equality_differentLocationName_areNotEqual() {
        let item1 = StoreItem(name: "Nike", imageName: "a.png", locationName: "A1")
        let item2 = StoreItem(name: "Nike", imageName: "a.png", locationName: "B2")
        XCTAssertNotEqual(item1, item2)
    }

    // MARK: - Hashable (by locationName)

    func test_hash_sameLocationName_produceSameHash() {
        let item1 = StoreItem(name: "Nike", imageName: "a.png", locationName: "A1")
        let item2 = StoreItem(name: "Adidas", imageName: "b.png", locationName: "A1")
        XCTAssertEqual(item1.hashValue, item2.hashValue)
    }

    func test_hashable_canBeUsedInSet() {
        let item1 = StoreItem(name: "Nike", imageName: "a.png", locationName: "A1")
        let item2 = StoreItem(name: "Adidas", imageName: "b.png", locationName: "A1")
        let item3 = StoreItem(name: "Puma", imageName: "c.png", locationName: "B2")
        let set: Set<StoreItem> = [item1, item2, item3]
        XCTAssertEqual(set.count, 2) // item1 and item2 collide by locationName
    }
}

// MARK: - ShoppingItem Tests

final class ShoppingItemTests: XCTestCase {

    func test_init_storesName() {
        let item = ShoppingItem(name: "T-Shirt", storeName: "Nike")
        XCTAssertEqual(item.name, "T-Shirt")
    }

    func test_init_storesStoreName() {
        let item = ShoppingItem(name: "T-Shirt", storeName: "Nike")
        XCTAssertEqual(item.storeName, "Nike")
    }

    func test_init_defaultDescriptionIsNil() {
        let item = ShoppingItem(name: "T-Shirt", storeName: "Nike")
        XCTAssertNil(item.description)
    }

    func test_init_storesDescription() {
        let item = ShoppingItem(name: "T-Shirt", storeName: "Nike", description: "Slim fit")
        XCTAssertEqual(item.description, "Slim fit")
    }

    func test_init_defaultIdIsUUID() {
        let item = ShoppingItem(name: "T-Shirt", storeName: "Nike")
        XCTAssertNotNil(item.id)
    }

    func test_init_defaultIds_areUnique() {
        let item1 = ShoppingItem(name: "T-Shirt", storeName: "Nike")
        let item2 = ShoppingItem(name: "T-Shirt", storeName: "Nike")
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func test_init_withExplicitId_usesProvidedId() {
        let uuid = UUID()
        let item = ShoppingItem(id: uuid, name: "T-Shirt", storeName: "Nike")
        XCTAssertEqual(item.id, uuid)
    }

    func test_hashable_canBeUsedInSet() {
        let id = UUID()
        let item1 = ShoppingItem(id: id, name: "T-Shirt", storeName: "Nike")
        let item2 = ShoppingItem(id: id, name: "T-Shirt", storeName: "Nike")
        let set: Set<ShoppingItem> = [item1, item2]
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: - StoreDetails Tests

final class StoreDetailsTests: XCTestCase {

    func test_init_fromStoreItem_copiesName() {
        let storeItem = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1", spaceId: "s1")
        let details = StoreDetails(from: storeItem)
        XCTAssertEqual(details.name, "Nike")
    }

    func test_init_fromStoreItem_copiesImageName() {
        let storeItem = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        let details = StoreDetails(from: storeItem)
        XCTAssertEqual(details.imageName, "nike.png")
    }

    func test_init_fromStoreItem_copiesLocationName() {
        let storeItem = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        let details = StoreDetails(from: storeItem)
        XCTAssertEqual(details.locationName, "A1")
    }

    func test_init_fromStoreItem_copiesSpaceId() {
        let storeItem = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1", spaceId: "s1")
        let details = StoreDetails(from: storeItem)
        XCTAssertEqual(details.spaceId, "s1")
    }

    func test_init_fromStoreItem_defaultCoordinatesNil() {
        let storeItem = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        let details = StoreDetails(from: storeItem)
        XCTAssertNil(details.coordinates)
    }

    func test_init_fromStoreItem_withCoordinates_storesCoordinates() {
        let storeItem = StoreItem(name: "Nike", imageName: "nike.png", locationName: "A1")
        let details = StoreDetails(from: storeItem, coordinates: (37.5, -122.4))
        XCTAssertEqual(details.coordinates?.0, 37.5)
        XCTAssertEqual(details.coordinates?.1, -122.4)
    }

    func test_init_directInit_storesAllProperties() {
        let details = StoreDetails(
            name: "Adidas",
            imageName: "adidas.png",
            locationName: "B2",
            spaceId: "sp2",
            coordinates: (1.0, 2.0)
        )
        XCTAssertEqual(details.name, "Adidas")
        XCTAssertEqual(details.imageName, "adidas.png")
        XCTAssertEqual(details.locationName, "B2")
        XCTAssertEqual(details.spaceId, "sp2")
        XCTAssertEqual(details.coordinates?.0, 1.0)
        XCTAssertEqual(details.coordinates?.1, 2.0)
    }

    func test_id_isUniquePerInstance() {
        let details1 = StoreDetails(name: "Nike", imageName: "", locationName: "A1")
        let details2 = StoreDetails(name: "Nike", imageName: "", locationName: "A1")
        XCTAssertNotEqual(details1.id, details2.id)
    }
}
