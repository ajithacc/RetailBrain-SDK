//
//  ShoppingItem.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 24/06/26.
//

import Foundation

public struct ShoppingItem: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let storeName: String // Maps to store location name in the map
    public let description: String?
    
    public init(
        name: String,
        storeName: String,
        description: String? = nil
    ) {
        self.name = name
        self.storeName = storeName
        self.description = description
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ShoppingItem, rhs: ShoppingItem) -> Bool {
        lhs.id == rhs.id
    }
}


