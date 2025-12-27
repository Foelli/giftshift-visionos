//
//  ImmersiveView.swift
//  GiftShift
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    @State private var root = Entity()
    @State private var immersiveRoot: Entity? = nil

    @State private var ground: ModelEntity? = nil
    @State private var table: Entity? = nil
    @State private var stopButton: ModelEntity? = nil

    @State private var game = CubeGameController()
    private let factory = EntityFactory()

    // MARK: - Gesture state (prevents snapping)
    @State private var dragStartPosition: SIMD3<Float>? = nil
    @State private var dragStartTouchWorld: SIMD3<Float>? = nil
    @State private var rotateStartOrientation: simd_quatf? = nil

    var body: some View {
        TimelineView(.animation) { _ in
            RealityView { content in

                content.add(root)

                if immersiveRoot == nil,
                   let immersiveContentEntity = try? await Entity(
                        named: "Immersive",
                        in: realityKitContentBundle
                   ) {

                    immersiveRoot = immersiveContentEntity
                    content.add(immersiveContentEntity)

                    table = immersiveContentEntity.findEntity(named: "Table")
                }

                // Attach refs only when needed (prevents re-attaching every frame)
                if game.root == nil {
                    game.attach(root: root, table: table, appModel: appModel)
                } else if game.table !== table {
                    game.attach(root: root, table: table, appModel: appModel)
                }

                if ground == nil {
                    let g = factory.makeGround()
                    root.addChild(g)
                    ground = g
                }

                if stopButton == nil {
                    let button = factory.makeStopButton()
                    root.addChild(button)
                    stopButton = button
                }

                game.ensureScoreEntityExists()

            } update: { _ in
                // Physics runs automatically
            }
            .gesture(dragGesture.simultaneously(with: rotateGesture))
            .gesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        if value.entity.name == "StopButton" {
                            game.toggleSpawner()
                        }
                    }
            )
        }
        .task {
            game.startIfNeeded()
        }
        .onDisappear {
            game.stopAll()
        }
        // ✅ merged from main: restart game when token changes
        .onChange(of: appModel.startNewGameToken) { _, _ in
            game.restartGame()
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

                game.onManipulationBegan(entity)

                if var body = entity.components[PhysicsBodyComponent.self], body.mode != .kinematic {
                    body.mode = .kinematic
                    entity.components.set(body)
                }

                let touchWorld = value.convert(value.location3D, from: .local, to: parent)

                if dragStartPosition == nil {
                    dragStartPosition = entity.position(relativeTo: parent)
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

                if var body = entity.components[PhysicsBodyComponent.self] {
                    body.mode = .dynamic
                    entity.components.set(body)
                }

                game.onManipulationEnded(entity)
            }
    }

    var rotateGesture: some Gesture {
        RotateGesture3D()
            .targetedToAnyEntity()
            .onChanged { value in
                let entity = value.entity
                guard entity.name == "SpawnedCube" else { return }

                game.onManipulationBegan(entity)

                if var body = entity.components[PhysicsBodyComponent.self], body.mode != .kinematic {
                    body.mode = .kinematic
                    entity.components.set(body)
                }

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

                if var body = entity.components[PhysicsBodyComponent.self] {
                    body.mode = .dynamic
                    entity.components.set(body)
                }

                game.onManipulationEnded(entity)
            }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
