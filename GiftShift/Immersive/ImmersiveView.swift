//
//  ImmersiveView.swift
//  GiftShift
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @State private var root = Entity()
    @State private var immersiveRoot: Entity? = nil

    @State private var ground: ModelEntity? = nil
    @State private var table: Entity? = nil
    @State private var stopButton: ModelEntity? = nil

    // Head-locked anchor (object follows the user's head)
    @State private var headAnchor = AnchorEntity(.head)

    @State private var cubes: [ModelEntity] = []
    @State private var spawnTimer: Timer?

    // MARK: - Spawn tuning
    private let spawnInterval: TimeInterval = 5.0

    // MARK: - Despawn tuning
    private let cubeLifetime: TimeInterval = 5.0

    // Store per-cube despawn timer so we can cancel/reset it
    @State private var despawnTimers: [ObjectIdentifier: Timer] = [:]

    // MARK: - Gesture state (prevents snapping)
    @State private var dragStartPosition: SIMD3<Float>? = nil
    @State private var dragStartTouchWorld: SIMD3<Float>? = nil
    @State private var rotateStartOrientation: simd_quatf? = nil

    var body: some View {
        TimelineView(.animation) { _ in
            RealityView { content in

                // World root
                content.add(root)

                // Head anchor (must be added to content, not to root)
                content.add(headAnchor)

                if immersiveRoot == nil,
                   let immersiveContentEntity = try? await Entity(
                        named: "Immersive",
                        in: realityKitContentBundle
                   ) {
                    immersiveRoot = immersiveContentEntity
                    content.add(immersiveContentEntity)

                    // Still keep table reference if you need it later for basket placement etc.
                    table = immersiveContentEntity.findEntity(named: "Table")
                }

                if ground == nil {
                    let g = makeGround()
                    root.addChild(g)
                    ground = g
                }

                if stopButton == nil {
                    let button = makeStopButton()
                    root.addChild(button)
                    stopButton = button
                }

            } update: { _ in
                // Physics runs automatically
            }
            .gesture(dragGesture.simultaneously(with: rotateGesture))
            .gesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        if value.entity.name == "StopButton" {
                            if spawnTimer != nil {
                                stopCubeSpawner()
                            } else {
                                startCubeSpawner()
                            }
                        }
                    }
            )
        }
        .task {
            if spawnTimer == nil {
                startCubeSpawner()
            }
        }
        .onDisappear {
            stopCubeSpawner()
            cancelAllDespawnTimers()
        }
    }

    // MARK: - Gestures

    var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                let entity = value.entity
                guard entity.name == "SpawnedCube" else { return }
                guard let parent = entity.parent else { return }

                // While touching/manipulating: cube should NOT despawn
                cancelDespawn(for: entity)

                // Ensure cube is head-locked while being manipulated
                beginHeadLockedManipulation(entity)

                // Re-fetch parent (it may have changed due to reparenting)
                guard let newParent = entity.parent else { return }

                let touchWorld = value.convert(value.location3D, from: .local, to: newParent)

                if dragStartPosition == nil {
                    dragStartPosition = entity.position(relativeTo: newParent)
                    dragStartTouchWorld = touchWorld
                }

                if let startPos = dragStartPosition, let startTouch = dragStartTouchWorld {
                    let delta = touchWorld - startTouch
                    entity.position = startPos + delta
                }
            }
            .onEnded { value in
                let entity = value.entity
                guard entity.name == "SpawnedCube" else { return }

                dragStartPosition = nil
                dragStartTouchWorld = nil

                // Drop into world space when released
                dropToWorld(entity)

                // Reset despawn timer when released
                scheduleDespawn(for: entity, after: cubeLifetime)
            }
    }

    var rotateGesture: some Gesture {
        RotateGesture3D()
            .targetedToAnyEntity()
            .onChanged { value in
                let entity = value.entity
                guard entity.name == "SpawnedCube" else { return }

                // While touching/manipulating: cube should NOT despawn
                cancelDespawn(for: entity)

                // Ensure cube is head-locked while being manipulated
                beginHeadLockedManipulation(entity)

                if rotateStartOrientation == nil {
                    rotateStartOrientation = entity.transform.rotation
                }
                guard let start = rotateStartOrientation else { return }

                let delta = simd_quatf(value.rotation)
                entity.transform.rotation = start * delta
            }
            .onEnded { value in
                let entity = value.entity
                guard entity.name == "SpawnedCube" else { return }

                rotateStartOrientation = nil

                // Drop into world space when released
                dropToWorld(entity)

                // Reset despawn timer when released
                scheduleDespawn(for: entity, after: cubeLifetime)
            }
    }

    // MARK: - Head-locked manipulation helpers

    /// While manipulating: make kinematic and parent to headAnchor (preserving world transform).
    private func beginHeadLockedManipulation(_ entity: Entity) {
        // Freeze physics while manipulating
        if var body = entity.components[PhysicsBodyComponent.self], body.mode != .kinematic {
            body.mode = .kinematic
            entity.components.set(body)
        }

        // Already head-locked
        if entity.parent === headAnchor { return }

        // Preserve world transform while reparenting to head anchor
        let world = entity.transformMatrix(relativeTo: nil)
        entity.removeFromParent()
        headAnchor.addChild(entity)
        entity.setTransformMatrix(world, relativeTo: nil)
    }

    /// On release: preserve world transform, reparent to world root, switch back to dynamic.
    private func dropToWorld(_ entity: Entity) {
        let world = entity.transformMatrix(relativeTo: nil)

        entity.removeFromParent()
        root.addChild(entity)
        entity.setTransformMatrix(world, relativeTo: nil)

        if var body = entity.components[PhysicsBodyComponent.self] {
            body.mode = .dynamic
            entity.components.set(body)
        }
    }

    // MARK: - Cube Spawner

    func startCubeSpawner() {
        guard spawnTimer == nil else { return }

        spawnOneCube() // instant first cube

        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            spawnOneCube()
        }

        print("Spawner started.")
    }

    func stopCubeSpawner() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        print("Spawner stopped.")
    }

    private func spawnOneCube() {
        let cube = makeHeadLockedCube()
        cubes.append(cube)

        // Spawn as child of headAnchor so it stays in front while the user turns
        headAnchor.addChild(cube)

        // Start despawn countdown when spawned
        scheduleDespawn(for: cube, after: cubeLifetime)

        print("Spawned head-locked cube at \(cube.position)")
    }

    // MARK: - Despawn management (cancel/reset per cube)

    private func scheduleDespawn(for cube: Entity, after seconds: TimeInterval) {
        cancelDespawn(for: cube)

        let id = ObjectIdentifier(cube)
        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            self.despawnTimers[id] = nil
            cube.removeFromParent()
            self.cubes.removeAll { $0 === cube }
            print("Cube despawned.")
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

    // MARK: - Cube Factory (Head-locked spawn)

    func makeHeadLockedCube() -> ModelEntity {
        let size: Float = 0.4

        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: randomCubeColor(), isMetallic: true)
        let cube = ModelEntity(mesh: mesh, materials: [material])

        cube.name = "SpawnedCube"

        // Spawn in front of the user's head (headAnchor local space)
        let x = Float.random(in: -0.15...0.15)
        let y = Float.random(in: -0.05...0.10)
        let z: Float = -0.7
        cube.position = [x, y, z]

        cube.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [size, size, size])]
            )
        )
        cube.components.set(InputTargetComponent())

        let physicsMat = PhysicsMaterialResource.generate(
            friction: 3.0,
            restitution: 0.0
        )

        // Kinematic while head-locked so gravity doesn't pull it away
        cube.components.set(
            PhysicsBodyComponent(
                massProperties: .default,
                material: physicsMat,
                mode: .kinematic
            )
        )

        return cube
    }

    // MARK: - Stop Button

    func makeStopButton() -> ModelEntity {
        let mesh = MeshResource.generateBox(size: 0.15)
        let material = SimpleMaterial(color: .red, isMetallic: false)
        let button = ModelEntity(mesh: mesh, materials: [material])

        button.name = "StopButton"
        button.position = [0, 1.5, -1.0]

        button.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [0.2, 0.08, 0.05])]
            )
        )
        button.components.set(InputTargetComponent())

        return button
    }

    // MARK: - Colors

    func randomCubeColor() -> UIColor {
        [.red, .orange, .green].randomElement()!
    }

    // MARK: - Ground

    func makeGround() -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: 4, depth: 4)
        let material = SimpleMaterial(color: .gray, isMetallic: false)
        let ground = ModelEntity(mesh: mesh, materials: [material])

        ground.name = "Ground"
        ground.position = [0, -0.01, 0]

        ground.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [4, 0.02, 4])]
            )
        )

        let groundPhysicsMat = PhysicsMaterialResource.generate(
            friction: 4.0,
            restitution: 0.0
        )

        ground.components.set(
            PhysicsBodyComponent(
                material: groundPhysicsMat,
                mode: .static
            )
        )

        return ground
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
