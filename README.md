GiftShift (visionOS App)

GiftShift is an immersive visionOS game built with SwiftUI, RealityKit, and Reality Composer Pro.
Players interact with floating colored cubes and score points by placing each cube into its corresponding colored bowl.

Features
  - Dynamic Cubes: Cubes spawn automatically and are fully grabbable and throwable.
  - Bowls: Players place cubes into bowls matching the cube’s color.
  - Immersive Environment: A visually appealing 3D scene surrounds the player.
  - Point System: 1 point is awarded for each cube placed in the correct bowl.
  - Pause Button: Allows the player to pause the game.

Game Logic Overview
Cubes spawn at a fixed interval with physics and collision properties.
Bowls contain collision triggers that detect cube placement.
When a cube collides with a bowl, its color is checked:
If the color matches the bowl, a point is awarded and the cube is removed from the scene.
After five cubes despawn without being placed correctly, the game ends.
