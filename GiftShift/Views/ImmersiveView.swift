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
    @State private var pauseButton: ModelEntity? = nil

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
                   let rcRoot = try? await Entity(
                        named: "Immersive",
                        in: realityKitContentBundle
                   ) {

                    immersiveRoot = rcRoot
                    content.add(rcRoot)

                    // DEBUG (keep this for one run)
                    print("Loaded RC root:", rcRoot.name.isEmpty ? "(no name)" : rcRoot.name)
                    printEntityTree(rcRoot)

                    table = rcRoot.findEntity(named: "Table")

                    let blue  = rcRoot.findEntity(named: "CollisionCheckBlueBowl")
                    let red   = rcRoot.findEntity(named: "CollisionCheckRedBowl")
                    let green = rcRoot.findEntity(named: "CollisionCheckGreenBowl")

                    prepareTrigger(blue)
                    prepareTrigger(red)
                    prepareTrigger(green)

                    game.setBowlTriggers(blue: blue, red: red, green: green)

                    print("Triggers found:",
                          blue?.name ?? "nil",
                          red?.name ?? "nil",
                          green?.name ?? "nil")
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
                
                if pauseButton == nil {
                    let button = factory.makePauseButton()
                    root.addChild(button)
                    pauseButton = button
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
        // Restart when main token changes
        .onChange(of: appModel.startNewGameToken) { _, _ in
            game.restartGame()
        }
        // NEW: listen to gameState changes and forward to controller
        .onChange(of: appModel.gameState) { _, newValue in
            game.handleGameStateChanged(newValue)
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

    // MARK: - Physics trigger prep
    private func prepareTrigger(_ entity: Entity?) {
        guard let e = entity else { return }

        // Ensure it participates in physics so CollisionEvents fire.
        if e.components[PhysicsBodyComponent.self] == nil {
            e.components.set(PhysicsBodyComponent(mode: .static))
        }

        // NOTE: Don't rely on CollisionComponent.mode (not available on all SDKs).
        // If your RC entity is already set to Trigger, great; otherwise static collisions still emit events.
    }

    // MARK: - Debug: print loaded entity hierarchy
    private func printEntityTree(_ entity: Entity, indent: String = "") {
        let name = entity.name.isEmpty ? "(no name)" : entity.name
        print("\(indent)- \(name)")
        for child in entity.children {
            printEntityTree(child, indent: indent + "  ")
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}

