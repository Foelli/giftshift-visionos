// CubeGameController.swift

import Foundation
import RealityKit

@MainActor
final class CubeGameController {

    // MARK: - Dependencies

    private let factory: EntityFactory

    // MARK: - Tuning (kept identical to your current behavior)

    private let spawnInterval: TimeInterval = 5.0
    private let cubeLifetime: TimeInterval = 5.0
    private let loseThreshold: Int = 5

    // MARK: - Scene references (set by ImmersiveView)

    weak var root: Entity?
    weak var table: Entity?
    weak var appModel: AppModel?

    // MARK: - State

    private(set) var cubes: [ModelEntity] = []
    private(set) var spawnTimer: Timer?

    private(set) var despawnedCubesCount: Int = 0
    private(set) var showLostMessage: Bool = false

    private var scoreEntity: ModelEntity?

    // Per-cube despawn timers
    private var despawnTimers: [ObjectIdentifier: Timer] = [:]

    // MARK: - Init

    init(factory: EntityFactory = EntityFactory()) {
        self.factory = factory
    }

    // MARK: - Attach

    func attach(root: Entity, table: Entity?, appModel: AppModel?) {
        self.root = root
        self.table = table
        self.appModel = appModel
    }

    // MARK: - Public lifecycle

    func startIfNeeded() {
        guard spawnTimer == nil else { return }
        startCubeSpawner()
    }

    func stopAll() {
        stopCubeSpawner()
        cancelAllDespawnTimers()
    }

    func toggleSpawner() {
        if spawnTimer != nil {
            stopCubeSpawner()
        } else {
            startCubeSpawner()
        }
    }

    // MARK: - Score text

    func ensureScoreEntityExists() {
        guard let root else { return }
        guard scoreEntity == nil else { return }

        let entity = factory.makeScoreEntity(despawnedCubesCount: despawnedCubesCount)
        root.addChild(entity)
        scoreEntity = entity
    }

    private func refreshScoreEntity() {
        scoreEntity?.removeFromParent()
        scoreEntity = nil
        ensureScoreEntityExists()
    }

    // MARK: - Restart game (merged from main)

    func restartGame() {
        print("🔁 Restarting game")

        stopCubeSpawner()
        cancelAllDespawnTimers()

        for cube in cubes {
            cube.removeFromParent()
        }
        cubes.removeAll()

        scoreEntity?.removeFromParent()
        scoreEntity = nil

        despawnedCubesCount = 0
        showLostMessage = false

        // recreate score text immediately (same behavior as before)
        ensureScoreEntityExists()

        startCubeSpawner()
    }

    // MARK: - Gestures hooks

    func onManipulationBegan(_ cube: Entity) {
        cancelDespawn(for: cube)
    }

    func onManipulationEnded(_ cube: Entity) {
        scheduleDespawn(for: cube, after: cubeLifetime)
    }

    // MARK: - Spawner

    private func startCubeSpawner() {
        guard spawnTimer == nil else { return }

        spawnOneCube() // instant first cube

        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
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

        let cube = factory.makePhysicalCube(above: table)
        cubes.append(cube)
        root.addChild(cube)

        scheduleDespawn(for: cube, after: cubeLifetime)

        print("Spawned cube at \(cube.position)")
    }

    // MARK: - Despawn management

    private func scheduleDespawn(for cube: Entity, after seconds: TimeInterval) {
        cancelDespawn(for: cube)

        let id = ObjectIdentifier(cube)

        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self else { return }

            DispatchQueue.main.async {
                cube.removeFromParent()
                self.cubes.removeAll { $0 === cube }
                self.despawnTimers[id] = nil

                self.despawnedCubesCount += 1
                print("Cube despawned. Count: \(self.despawnedCubesCount)")

                self.refreshScoreEntity()

                // ✅ merged main behavior: lose at >= 5, stop spawner, show window
                if self.despawnedCubesCount >= self.loseThreshold {
                    self.showLostMessage = true
                    self.stopCubeSpawner()
                    self.appModel?.shouldShowWindow = true
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
