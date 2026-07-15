//
//  ShoppingItemsProviderTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
//

import XCTest
@testable import RetailBrainSDK

final class ShoppingItemsProviderTests: XCTestCase {

    private var provider: ShoppingItemsProvider!
    private var mockDelegate: MockRetailBrainSDKDelegate!

    override func setUp() {
        super.setUp()
        provider = ShoppingItemsProvider()
        mockDelegate = MockRetailBrainSDKDelegate()
        RetailBrainManager.shared.delegate = mockDelegate
    }

    override func tearDown() {
        RetailBrainManager.shared.delegate = nil
        provider = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialCustomItems_isEmpty() {
        XCTAssertTrue(provider.customItems.isEmpty)
    }

    func test_getItems_initially_returnsEmptyArray() {
        XCTAssertEqual(provider.getItems().count, 0)
    }

    // MARK: - setCustomItems

    func test_setCustomItems_storesItems() {
        let items = [
            ShoppingItem(name: "Shoes", storeName: "Nike"),
            ShoppingItem(name: "Bag", storeName: "Adidas")
        ]
        provider.setCustomItems(items)
        XCTAssertEqual(provider.customItems.count, 2)
    }

    func test_setCustomItems_replacesExistingItems() {
        provider.setCustomItems([ShoppingItem(name: "Shoes", storeName: "Nike")])
        provider.setCustomItems([ShoppingItem(name: "Hat", storeName: "Puma"), ShoppingItem(name: "Shirt", storeName: "Reebok")])
        XCTAssertEqual(provider.customItems.count, 2)
        XCTAssertEqual(provider.customItems.first?.name, "Hat")
    }

    func test_setCustomItems_withEmptyArray_clearsItems() {
        provider.setCustomItems([ShoppingItem(name: "Shoes", storeName: "Nike")])
        provider.setCustomItems([])
        XCTAssertTrue(provider.customItems.isEmpty)
    }

    func test_setCustomItems_notifiesDelegateAddProductToMap() {
        provider.setCustomItems([ShoppingItem(name: "Shoes", storeName: "Nike")])
        XCTAssertTrue(mockDelegate.addProductToMapCalled)
    }

    func test_setCustomItems_withNoDelegate_doesNotCrash() {
        RetailBrainManager.shared.delegate = nil
        let items = [ShoppingItem(name: "Shoes", storeName: "Nike")]
        XCTAssertNoThrow(provider.setCustomItems(items))
    }

    // MARK: - getItems

    func test_getItems_returnsStoredItems() {
        let items = [
            ShoppingItem(name: "Shoes", storeName: "Nike"),
            ShoppingItem(name: "Bag", storeName: "Adidas")
        ]
        provider.setCustomItems(items)
        let result = provider.getItems()
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "Shoes")
        XCTAssertEqual(result[1].name, "Bag")
    }

    func test_getItems_preservesItemOrder() {
        let items = (1...5).map { ShoppingItem(name: "Item\($0)", storeName: "Store") }
        provider.setCustomItems(items)
        let result = provider.getItems()
        for (index, item) in result.enumerated() {
            XCTAssertEqual(item.name, "Item\(index + 1)")
        }
    }

    // MARK: - Shared Instance

    func test_shared_returnsSameInstance() {
        let first = ShoppingItemsProvider.shared
        let second = ShoppingItemsProvider.shared
        XCTAssertTrue(first === second)
    }
}
