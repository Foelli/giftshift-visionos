//
//  AppModel.swift
//  GiftShift
//
//  Created by Simon Felhofer on 21.11.25.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var shouldShowWindow = false
    var shouldCloseWindow = false
    var startNewGameToken = UUID()
    enum GameState {
        case firstStart
        case playing
        case paused
        case afterRound
    }
    var gameState = GameState.firstStart
    var lastPoints = 0
}
