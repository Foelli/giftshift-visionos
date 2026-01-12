//
//  CubeGameController.swift
//  GiftShift
//

import Combine
import Foundation
import RealityKit
import SwiftUI

@MainActor
final class CubeGameController {

    // MARK: - Dependencies
    private let factory: EntityFactory

    // MARK: - Tuning
    private let spawnInterval: TimeInterval = 5.0
    private let cubeLifetime: TimeInterval = 5.0
    private let loseThreshold: Int = 5

    // MARK: - Scene references (set by ImmersiveView)
    weak var root: Entity?
    weak var table: Entity?
    weak var appModel: AppModel?

    // Bowl trigger entities (from Reality Composer)
    private weak var blueTrigger: Entity?
    private weak var redTrigger: Entity?
    private weak var greenTrigger: Entity?

    // MARK: - State
    private(set) var cubes: [ModelEntity] = []
    private(set) var spawnTimer: Timer?

    private(set) var despawnedCubesCount: Int = 0
    private(set) var showLostMessage: Bool = false
    private(set) var points: Int = 0

    private var scoreEntity: ModelEntity?

    // Per-cube despawn timers
    private var despawnTimers: [ObjectIdentifier: Timer] = [:]

    // ✅ Collision subscriptions (RealityKit returns Combine cancellables on your SDK)
    private var collisionCancellables: [AnyCancellable] = []
    private var didSetupBowlSubscriptions = false

    // MARK: - Init
    init(factory: EntityFactory = EntityFactory()) {
        self.factory = factory
    }

    // MARK: - Attach / Setup
    func attach(root: Entity, table: Entity?, appModel: AppModel?) {
        self.root = root
        self.table = table
        self.appModel = appModel

        setupBowlSubscriptionsIfPossible()
    }

    func setBowlTriggers(blue: Entity?, red: Entity?, green: Entity?) {
        self.blueTrigger = blue
        self.redTrigger = red
        self.greenTrigger = green

        setupBowlSubscriptionsIfPossible()
    }

    private func setupBowlSubscriptionsIfPossible() {
        guard !didSetupBowlSubscriptions else { return }
        guard let root, let scene = root.scene else { return }
        guard let blueTrigger, let redTrigger, let greenTrigger else { return }

        didSetupBowlSubscriptions = true

        func subscribe(_ trigger: Entity, expects color: CubeColor) {
            let cancellable = scene.subscribe(
                to: CollisionEvents.Began.self,
                on: trigger
            ) { [weak self] event in
                self?.handleBowlCollision(event: event, expected: color)
            }

            // ✅ Wrap into AnyCancellable so it stores cleanly
            collisionCancellables.append(AnyCancellable(cancellable))
        }

        subscribe(blueTrigger, expects: .blue)
        subscribe(redTrigger, expects: .red)
        subscribe(greenTrigger, expects: .green)

        print("✅ Bowl collision subscriptions set up.")
    }

    // MARK: - Public lifecycle
    func startIfNeeded() {
        guard spawnTimer == nil else { return }
        appModel?.gameState = .playing
        startCubeSpawner()
    }

    func stopAll() {
        appModel!.gameState = .afterRound
        stopCubeSpawner()
        cancelAllDespawnTimers()
        appModel!.shouldShowWindow = true
        // keep collision subscriptions alive (scene lifecycle)
    }

    // Toggle from in-world StopButton tap
    func toggleSpawner() {
        if spawnTimer != nil {
            appModel!.gameState = .paused
            stopCubeSpawner()
            appModel!.shouldShowWindow = true
        } else {
            resumeSpawnerFromUI()
        }
    }

    // MARK: - Resume/start branch extracted from toggleSpawner's else
    private func resumeSpawnerFromUI() {
        appModel!.shouldCloseWindow = true
        appModel!.gameState = .playing
        startCubeSpawner()
    }

    // MARK: - React to external gameState changes (e.g., Resume button in 2D window)
    func handleGameStateChanged(_ newState: AppModel.GameState) {
        switch newState {
        case .playing:
            // Only resume if not already spawning
            if spawnTimer == nil {
                resumeSpawnerFromUI()
            }
        default:
            break
        }
    }

    // MARK: - Score text
    func ensureScoreEntityExists() {
        guard let root else { return }
        guard scoreEntity == nil else { return }

        let entity = factory.makeScoreEntity(
            points: points,
            despawnedCubesCount: despawnedCubesCount
        )
        root.addChild(entity)
        scoreEntity = entity

        setupBowlSubscriptionsIfPossible()
    }

    private func refreshScoreEntity() {
        scoreEntity?.removeFromParent()
        scoreEntity = nil
        ensureScoreEntityExists()
    }

    // MARK: - Restart game
    func restartGame() {
        print("🔁 Restarting game")

        stopCubeSpawner()
        cancelAllDespawnTimers()

        for cube in cubes { cube.removeFromParent() }
        cubes.removeAll()

        scoreEntity?.removeFromParent()
        scoreEntity = nil

        despawnedCubesCount = 0
        showLostMessage = false
        points = 0

        ensureScoreEntityExists()
        appModel!.gameState = .playing
        startCubeSpawner()
    }

    func endGame() {
        self.showLostMessage = true

        self.stopCubeSpawner()
        self.cancelAllDespawnTimers()
        appModel?.lastPoints = points
        appModel?.gameState = .afterRound

        self.appModel?.shouldShowWindow = true
    }

    // MARK: - Gesture hooks
    func onManipulationBegan(_ cube: Entity) {
        cancelDespawn(for: cube)
    }

    func onManipulationEnded(_ cube: Entity) {
        scheduleDespawn(for: cube, after: cubeLifetime)
    }

    // MARK: - Spawner
    private func startCubeSpawner() {
        guard spawnTimer == nil else { return }
        guard !showLostMessage else { return }

        spawnOneCube()  // instant first cube

        spawnTimer = Timer.scheduledTimer(
            withTimeInterval: spawnInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            guard !self.showLostMessage else { return }
            self.spawnOneCube()
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
        guard !showLostMessage else { return }

        let cube = factory.makePhysicalCube(above: table)
        cubes.append(cube)
        root.addChild(cube)

        scheduleDespawn(for: cube, after: cubeLifetime)

        print("Spawned cube at \(cube.position)")
    }

    // MARK: - Collision scoring
    private func handleBowlCollision(
        event: CollisionEvents.Began,
        expected: CubeColor
    ) {
        // Debug: confirm collisions actually fire
        print(
            "💥 collision between \(event.entityA.name) and \(event.entityB.name) expected \(expected)"
        )

        let a = event.entityA
        let b = event.entityB

        let cubeEntity: Entity?
        if a.name == "SpawnedCube" {
            cubeEntity = a
        } else if b.name == "SpawnedCube" {
            cubeEntity = b
        } else {
            cubeEntity = nil
        }

        guard let cube = cubeEntity as? ModelEntity else { return }

        guard let comp = cube.components[CubeColorComponent.self] else {
            return
        }
        guard comp.color == expected else { return }

        points += 1
        print("✅ Scored! Points: \(points)")

        cancelDespawn(for: cube)
        cube.removeFromParent()
        cubes.removeAll { $0 === cube }

        refreshScoreEntity()
    }

    // MARK: - Despawn management
    private func scheduleDespawn(for cube: Entity, after seconds: TimeInterval)
    {
        cancelDespawn(for: cube)
        let id = ObjectIdentifier(cube)

        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false)
        { [weak self] _ in
            guard let self else { return }

            DispatchQueue.main.async {
                if self.showLostMessage { return }

                cube.removeFromParent()
                self.cubes.removeAll { $0 === cube }
                self.despawnTimers[id] = nil

                self.despawnedCubesCount += 1
                print("Cube despawned. Count: \(self.despawnedCubesCount)")

                self.refreshScoreEntity()

                if self.despawnedCubesCount >= self.loseThreshold {
                    self.endGame()
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
        for (_, t) in despawnTimers { t.invalidate() }
        despawnTimers.removeAll()
    }
}
