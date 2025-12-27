//
//  GameConfig.swift
//  GiftShift
//
//  Created by Simon Felhofer on 19.12.25.
//

import Foundation

struct GameConfig{
    // Spawn tuning
    let spawnInterval: TimeInterval = 5.0
    
    // Despawn tuning
    let cubeLifetime: TimeInterval = 10.0
    
    // Stop spawner when despawn count reaces this
    let loseStopThreshold: Int = 3
}
