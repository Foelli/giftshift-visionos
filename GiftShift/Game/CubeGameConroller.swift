//
//  CubeGameConroller.swift
//  GiftShift
//
//  Created by Simon Felhofer, Emma Sysel, Jasmin Rechberger on 19.12.25.
//

import Foundation
import RealityKit

@MainActor
final class CubeGameController {

    // MARK: - Dependencies / Config

    private let factory: EntityFactory
    private let spawnInterval: TimeInterval
    private let cubeLifetime: TimeInterval
    private let stopAtDespawnCount: Int

    // MARK: - Scene references (set by ImmersiveView)

    weak var root: Entity?
    weak var table: Entity?

    // MARK: - Game state (moved out of ImmersiveView)

    private(set) var cubes: [ModelEntity] = []
    private(set) var spawnTimer: Timer?

    private(set) var despawnedCubesCount: Int = 0
    private(set) var showLostMessage: Bool = false

    private var loseEntity: ModelEntity?

    // Store per-cube despawn timer (same approach as your current code)
    private var despawnTimers: [ObjectIdentifier: Timer] = [:]

    // MARK: - Init

    init(
        factory: EntityFactory? = nil,
        spawnInterval: TimeInterval = 5.0,
        cubeLifetime: TimeInterval = 5.0,
        stopAtDespawnCount: Int = 3
    ) {
        self.factory = factory ?? EntityFactory()
        self.spawnInterval = spawnInterval
        self.cubeLifetime = cubeLifetime
        self.stopAtDespawnCount = stopAtDespawnCount
    }

    // MARK: - Public API (called by ImmersiveView)

    func attach(root: Entity, table: Entity?) {
        self.root = root
        self.table = table
    }

    func ensureScoreEntityExists() {
        guard let root else { return }
        guard loseEntity == nil else { return }

        let message = factory.makeScoreEntity(despawnedCubesCount: despawnedCubesCount)
        root.addChild(message)
        loseEntity = message
    }

    func startIfNeeded() {
        guard spawnTimer == nil else { return }
        startCubeSpawner()
    }

    func stopAll() {
        stopCubeSpawner()
        cancelAllDespawnTimers()
    }

    func toggleSpawner() {
        if spawnTimer != nil { stopCubeSpawner() }
        else { startCubeSpawner() }
    }

    // These two are used by your gestures
    func onManipulationBegan(_ cube: Entity) {
        cancelDespawn(for: cube)
    }

    func onManipulationEnded(_ cube: Entity) {
        scheduleDespawn(for: cube, after: cubeLifetime)
    }

    // MARK: - Spawner (same behavior)

    private func startCubeSpawner() {
        guard spawnTimer == nil else { return }

        Task { @MainActor in
            self.spawnOneCube() // instant first cube
        }

        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.spawnOneCube()
            }
        }

        print("Spawner started.")
    }

    private func stopCubeSpawner() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        print("Spawner stopped.")
    }

    private func spawnOneCube() {
        guard let root, let table else { return }

        let cube = factory.makePhysicalCube(above: table)
        cubes.append(cube)
        root.addChild(cube)

        scheduleDespawn(for: cube, after: cubeLifetime)

        print("Spawned cube at \(cube.position)")
    }

    // MARK: - Despawn timers (same logic as your current code)

    private func scheduleDespawn(for cube: Entity, after seconds: TimeInterval) {
        cancelDespawn(for: cube)

        let id = ObjectIdentifier(cube)

        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self else { return }

            DispatchQueue.main.async {
                // Remove cube
                cube.removeFromParent()
                self.cubes.removeAll { $0 === cube }
                self.despawnTimers[id] = nil

                // Increment counter
                self.despawnedCubesCount += 1
                print("Cube despawned. Count: \(self.despawnedCubesCount)")

                // Replace score text
                if let lose = self.loseEntity {
                    lose.removeFromParent()
                    self.loseEntity = nil
                }
                if let root = self.root {
                    let messageEntity = self.factory.makeScoreEntity(despawnedCubesCount: self.despawnedCubesCount)
                    root.addChild(messageEntity)
                    self.loseEntity = messageEntity
                }

                // Stop spawner at >= 3 (unchanged)
                if self.despawnedCubesCount >= self.stopAtDespawnCount {
                    self.showLostMessage = true
                    self.stopCubeSpawner()
                }
            }
        }

        despawnTimers[id] = t
    }

    private func cancelDespawn(for cube: Entity) {
        let id = ObjectIdentifier(cube)
        despawnTimers[id]?.invalidate()
        despawnTimers[id] = nil
    }

    private func cancelAllDespawnTimers() {
        for (_, t) in despawnTimers {
            t.invalidate()
        }
        despawnTimers.removeAll()
    }
}

