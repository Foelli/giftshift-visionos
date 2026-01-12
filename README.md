GiftShift (visionOS App)

GiftShift is an immersive visionOS game built with SwiftUI, RealityKit, and Reality Composer Pro.
Players interact with floating colored cubes and score points by placing each cube into its corresponding colored bowl.

Features:
  - Cubes: Cubes spawn automatically and are grabbable and throwable.
  - Bowls: Players place cubes into bowls matching the cube’s color.
  - Environment: A winter-wonderland 3D scene surrounds the player, featuring 3 christmas trees, a snow-covered ground and a self-made table where the presents land on.
  - Point System: 1 point is awarded for each cube placed in the correct bowl.
  - Controlling Buttons: One acts as a pause button and the other one 

Game Logic:
Cubes spawn at a fixed interval with physics and collision properties. Bowls contain collision triggers that detect cube placement. When a cube collides with a bowl, its color is checked: If the color matches the bowl, a point is awarded and the cube is removed from the scene. If the cube does not match the color or is not grabbed fast enough, it despwans. A cube lives exactly 5 seconds before it despanws. After five despawned cubes, the game ends.

Link to the showcase video:
https://www.youtube.com/watch?v=7Cu7K5K4FnU
(The video was recorded when the game was still in the beta - we added a pause button and did a few optical changes afterwards) 
