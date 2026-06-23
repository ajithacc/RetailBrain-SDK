//
//  RetailBrainSDK.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 22/06/26.
//

import Foundation

public final class RetailBrainManager {
    
    public static let shared = RetailBrainManager()
    
    private init() {}
    
    public private(set) var config: RetailBrainConfig?
    
    public func initialize(
        
        config: RetailBrainConfig
        
    ) {
        self.config = config
        print("SDK Initialized")
        print("Map ID: \(config.mapId)")
    }
}
