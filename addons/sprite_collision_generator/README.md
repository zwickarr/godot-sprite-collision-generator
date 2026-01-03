# Sprite Collision Generator

A Godot 4.x addon that automatically generates CollisionPolygon2D shapes based on sprite alpha channels.

## Features

- **Alpha-based Detection**: Traces collision polygons around opaque areas of sprites
- **Interactive Precision Control**: Adjust detail level (1-255) to control how closely collision follows pixel edges
- **Safety Limits**:
  - Maximum 500 points per generation (configurable up to 1000)
  - Maximum 10 separate polygon regions
  - Prevents performance issues from overly complex collisions
- **Live Preview**: See collision shapes update in real-time as you adjust precision
- **Smart Polygon Simplification**: Uses Douglas-Peucker algorithm to reduce point count
- **Easy Integration**: Adds CollisionPolygon2D nodes directly to your Sprite2D

## Installation

1. The addon is already in `addons/sprite_collision_generator/`
2. Open your project in Godot
3. Go to **Project → Project Settings → Plugins**
4. Find "Sprite Collision Generator" and enable it

## Usage

1. **Select a Sprite2D node** in your scene tree
2. Look for the **"Collision Generator"** dock (usually appears in top-left)
3. **Adjust Precision** (1-255, default: 128):
   - Lower values (1-50): Simpler, looser collision with fewer points
   - Medium values (50-150): Balanced detail and performance
   - Higher values (150-255): Precise collision that follows every pixel edge
   - **Optional**: Enable **Make Convex** to create a convex hull (wraps around shape with no indentations)
4. **Set Max Points** to limit complexity (default: 500, max: 1000)
5. **Set Minimum Part Size** to filter out small fragments (default: 100 pixels):
   - Set to 0 to include all polygon parts
   - Higher values remove tiny disconnected pieces
6. **Optional**: Adjust **X Offset** and **Y Offset** to shift collision position (range: -10 to 10 pixels)
   - Use sliders to fine-tune collision alignment
   - Positive values shift right/down, negative values shift left/up
7. **Optional**: Adjust **Expansion** slider to grow or shrink the collision shape (range: -10 to 10 pixels)
   - Works like Photoshop's "expand selection" tool
   - Positive values expand outward, negative values contract inward
   - Each point moves along the edge normal for uniform growth
   - Use the **Reset** button to return expansion to 0
8. **Optional**: Specify a **Target Node** by selecting it in the scene tree and clicking "Set Target"
   - Leave as "None" to add collision as children of the sprite
   - Set a target to add collision nodes elsewhere in the scene
9. **Optional**: Enable **Live Preview** to see changes in real-time as you adjust parameters
10. Click **"Generate Collision"** button

The addon will create `CollisionPolygon2D` nodes either as children of your Sprite2D or in the target node you specified.

## Safety Features

- **Point Limit**: Stops generation if point count exceeds maximum (configurable)
- **Polygon Limit**: Only processes first 10 separate regions
- **Minimum Size Filter**: Removes small polygon fragments to prevent clutter
- **Validation**: Checks for valid textures and sprite data
- **Status Messages**: Clear feedback on what's happening

## Tips

- Start with default precision (128) and adjust from there
- Lower precision = simpler, looser collision shapes with fewer points
- Higher precision = more detailed collision that closely follows pixel edges
- Use "Live Preview" to find the right precision value
- Use **Minimum Part Size** to remove small disconnected pieces (eyes, details, etc.)
- If you get "too many points" warning, try:
  - Lowering the precision value
  - Increasing max points limit
  - Increasing minimum part size to remove small details
- **Works with sprite sheets!** Just set the frame you want before generating

## Technical Details

- Uses marching squares for contour tracing
- Douglas-Peucker algorithm for polygon simplification
- Flood fill for region detection
- Coordinates automatically centered to sprite origin

## Requirements

- Godot 4.x
- Sprite2D nodes with valid textures
