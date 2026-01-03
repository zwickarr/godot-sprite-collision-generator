@tool
extends Node
class_name CollisionGenerator

const MAX_POINTS = 500
const MAX_POLYGONS = 10

signal generation_complete(polygon_count: int, point_count: int)
signal generation_failed(error: String)

# Traces the outline of alpha regions in a texture
func generate_collision_polygon(sprite: Sprite2D, tolerance: float = 128.0, max_points: int = MAX_POINTS, min_area: float = 0.0, x_offset: float = 0.0, y_offset: float = 0.0, expansion: float = 0.0, make_convex: bool = false) -> Array[PackedVector2Array]:
	print("CollisionGenerator: generate_collision_polygon called")
	print("  Sprite: ", sprite.name if sprite else "null")
	print("  Tolerance: ", tolerance)
	print("  Max points: ", max_points)
	print("  X offset: ", x_offset)
	print("  Y offset: ", y_offset)
	print("  Expansion: ", expansion)
	print("  Make convex: ", make_convex)

	if not sprite:
		push_error("No sprite provided")
		generation_failed.emit("No sprite provided")
		return []

	var texture = sprite.texture
	if not texture:
		push_error("Sprite has no texture")
		generation_failed.emit("Sprite has no texture")
		return []

	print("  Texture: ", texture)
	print("  HFrames: ", sprite.hframes)
	print("  VFrames: ", sprite.vframes)
	print("  Frame: ", sprite.frame)

	var full_image = texture.get_image()
	if not full_image:
		push_error("Could not get image from texture")
		generation_failed.emit("Could not get image from texture")
		return []

	# Extract the current frame if using sprite sheets
	var image: Image
	if sprite.hframes > 1 or sprite.vframes > 1:
		image = _extract_frame_from_spritesheet(full_image, sprite.frame, sprite.hframes, sprite.vframes, sprite.region_enabled, sprite.region_rect)
		print("  Extracted frame from spritesheet")
	else:
		image = full_image

	var width = image.get_width()
	var height = image.get_height()
	print("  Frame size: ", width, "x", height)

	# Create a binary mask - use a low alpha threshold to detect all visible pixels
	var mask = _create_alpha_mask(image, 1.0)

	# Count solid pixels for debugging
	var solid_pixels = 0
	for i in range(mask.size()):
		if mask[i] == 1:
			solid_pixels += 1
	print("  Solid pixels found: ", solid_pixels, " / ", mask.size())

	if solid_pixels == 0:
		push_warning("No solid pixels found - sprite may be fully transparent or tolerance too high")
		generation_failed.emit("No solid pixels found")
		return []

	# Find all separate polygon regions
	var polygons: Array

	# At tolerance 1, create a simple bounding box around visible pixels
	if tolerance <= 1.0:
		# Find bounding box of all solid pixels
		var min_x = width
		var min_y = height
		var max_x = 0
		var max_y = 0

		for y in range(height):
			for x in range(width):
				if mask[y * width + x] == 1:
					min_x = min(min_x, x)
					min_y = min(min_y, y)
					max_x = max(max_x, x)
					max_y = max(max_y, y)

		# Create box around visible pixels (add 1 to max to include the full pixel)
		var box = PackedVector2Array([
			Vector2(min_x, min_y),
			Vector2(max_x + 1, min_y),
			Vector2(max_x + 1, max_y + 1),
			Vector2(min_x, max_y + 1)
		])
		polygons = [box]
		print("  Using simple bounding box for tolerance <= 1: ", min_x, ",", min_y, " to ", max_x + 1, ",", max_y + 1)
	else:
		polygons = _trace_polygons(mask, width, height)

	print("  Traced ", polygons.size(), " polygon regions")

	if polygons.size() == 0:
		push_warning("No collision polygons generated - tracing failed")
		generation_failed.emit("Polygon tracing failed")
		return []

	if polygons.size() > MAX_POLYGONS:
		push_warning("Too many polygons detected (%d), limiting to %d" % [polygons.size(), MAX_POLYGONS])
		polygons = polygons.slice(0, MAX_POLYGONS)

	# Simplify polygons and convert to local sprite coordinates
	var simplified_polygons: Array[PackedVector2Array] = []
	var total_points = 0

	# Calculate sprite offset from texture properties
	var offset_x = sprite.offset.x + (0.0 if sprite.centered else width / 2.0)
	var offset_y = sprite.offset.y + (0.0 if sprite.centered else height / 2.0)

	print("  Sprite centered: ", sprite.centered)
	print("  Sprite offset: ", sprite.offset)
	print("  Calculated offset: ", offset_x, ", ", offset_y)

	for poly in polygons:
		# Convert tolerance (1-255) to epsilon for simplification
		# Lower tolerance = more simplification (fewer points, looser fit)
		# Higher tolerance = less simplification (more points, tighter fit)
		# Tolerance 1 = bounding box (already handled above)
		# Tolerance 255 = skip simplification entirely
		var simplified: PackedVector2Array

		if tolerance <= 1.0:
			# Already a simple box, no simplification needed
			simplified = poly
		elif tolerance >= 250:
			# At very high tolerance, skip simplification
			simplified = poly
			print("  Skipping simplification (tolerance >= 250), keeping all ", poly.size(), " points")
		else:
			# Apply simplification
			# Regular tracing uses epsilon range: 10.0 (low detail) to 0.01 (high detail)
			var epsilon = 10.0 - (tolerance / 255.0) * 9.99  # Range: 10.0 to 0.01
			print("  Using epsilon: ", epsilon, " for tolerance: ", tolerance)
			simplified = _simplify_polygon(poly, epsilon)

		if simplified.size() < 3:
			continue

		# Apply convex hull if requested
		if make_convex:
			var convex = Geometry2D.convex_hull(simplified)
			if convex.size() >= 3:
				print("  Created convex hull with ", convex.size(), " points (from ", simplified.size(), " points)")
				simplified = convex
			else:
				print("  Convex hull failed, using original polygon")

		# Check minimum area filter
		if min_area > 0.0:
			var area = _calculate_polygon_area(simplified)
			if area < min_area:
				print("    Skipping small polygon with area: ", area)
				continue

		if total_points + simplified.size() > max_points:
			push_warning("Point limit reached (%d), stopping generation" % max_points)
			break

		# Convert to sprite local coordinates
		var local_poly = PackedVector2Array()

		# Apply Photoshop-style expansion (edge-normal-based) if needed
		var expanded_points = simplified
		if expansion != 0.0:
			expanded_points = _expand_polygon_photoshop_style(simplified, expansion)

		for point in expanded_points:
			# Convert from image pixel coordinates to sprite local coordinates
			var local_point: Vector2
			if sprite.centered:
				# If sprite is centered, subtract half dimensions
				local_point = Vector2(point.x - width / 2.0, point.y - height / 2.0)
			else:
				# If not centered, coordinates start at top-left
				local_point = Vector2(point.x, point.y)

			# Apply sprite offset
			local_point += sprite.offset

			# Apply user-defined X/Y offset (simple translation)
			local_point.x += x_offset
			local_point.y += y_offset

			local_poly.append(local_point)

		simplified_polygons.append(local_poly)
		total_points += simplified.size()

	generation_complete.emit(simplified_polygons.size(), total_points)
	return simplified_polygons

# Extracts a single frame from a spritesheet
func _extract_frame_from_spritesheet(full_image: Image, frame: int, hframes: int, vframes: int, region_enabled: bool, region_rect: Rect2) -> Image:
	var full_width = full_image.get_width()
	var full_height = full_image.get_height()

	# Calculate frame dimensions
	var frame_width = full_width / hframes
	var frame_height = full_height / vframes

	# Calculate frame position in spritesheet
	var frame_x = (frame % hframes) * frame_width
	var frame_y = (frame / hframes) * frame_height

	print("    Frame position: ", frame_x, ", ", frame_y)
	print("    Frame dimensions: ", frame_width, "x", frame_height)

	# Create new image for this frame
	var frame_image = Image.create(frame_width, frame_height, false, full_image.get_format())

	# Copy pixels from the frame region
	frame_image.blit_rect(full_image, Rect2(frame_x, frame_y, frame_width, frame_height), Vector2.ZERO)

	return frame_image

# Creates a binary mask from image alpha channel
func _create_alpha_mask(image: Image, tolerance: float) -> PackedByteArray:
	var width = image.get_width()
	var height = image.get_height()
	var mask = PackedByteArray()
	mask.resize(width * height)

	for y in range(height):
		for x in range(width):
			var color = image.get_pixel(x, y)
			var index = y * width + x
			mask[index] = 1 if color.a * 255.0 >= tolerance else 0

	return mask

# Traces polygon outlines using edge detection
func _trace_polygons(mask: PackedByteArray, width: int, height: int) -> Array:
	var visited = PackedByteArray()
	visited.resize(width * height)
	visited.fill(0)

	var polygons = []

	# Find boundary pixels (pixels with at least one transparent neighbor)
	for y in range(height):
		for x in range(width):
			var index = y * width + x
			if mask[index] == 1 and visited[index] == 0:
				# Check if this is a boundary pixel
				if _is_boundary_pixel(mask, x, y, width, height):
					var polygon = _trace_boundary(mask, visited, x, y, width, height)
					if polygon.size() >= 3:
						polygons.append(polygon)
						print("    Found polygon with ", polygon.size(), " points")

	return polygons

# Check if a pixel is on the boundary
func _is_boundary_pixel(mask: PackedByteArray, x: int, y: int, width: int, height: int) -> bool:
	# Check 4-connected neighbors
	var neighbors = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]

	for n in neighbors:
		var nx = x + n.x
		var ny = y + n.y

		# If neighbor is outside bounds or transparent, this is a boundary
		if nx < 0 or nx >= width or ny < 0 or ny >= height:
			return true

		var neighbor_index = ny * width + nx
		if mask[neighbor_index] == 0:
			return true

	return false

# Traces a boundary using Moore neighborhood tracing on pixel edges (not centers)
func _trace_boundary(mask: PackedByteArray, visited: PackedByteArray, start_x: int, start_y: int, width: int, height: int) -> PackedVector2Array:
	var contour = PackedVector2Array()

	# 8-direction clockwise starting from left
	var directions = [
		Vector2i(-1, 0),  # 0: Left
		Vector2i(-1, -1), # 1: Top-Left
		Vector2i(0, -1),  # 2: Top
		Vector2i(1, -1),  # 3: Top-Right
		Vector2i(1, 0),   # 4: Right
		Vector2i(1, 1),   # 5: Bottom-Right
		Vector2i(0, 1),   # 6: Bottom
		Vector2i(-1, 1)   # 7: Bottom-Left
	]

	var x = start_x
	var y = start_y
	var check_dir = 0  # Start checking from left

	var first_pixel = true
	var max_iterations = width * height * 2
	var iterations = 0

	while iterations < max_iterations:
		iterations += 1

		# Mark current pixel as visited
		var current_index = y * width + x
		visited[current_index] = 1

		# Add pixel corner positions (edges of the pixel) to create a tight-fitting outline
		# We add points at pixel boundaries, not pixel centers
		# Top-left corner of the pixel
		contour.append(Vector2(x, y))

		# Look for next boundary pixel
		var found_next = false

		for i in range(8):
			var dir = (check_dir + i) % 8
			var next_x = x + directions[dir].x
			var next_y = y + directions[dir].y

			# Check bounds
			if next_x < 0 or next_x >= width or next_y < 0 or next_y >= height:
				continue

			var next_index = next_y * width + next_x

			# Check if this is a solid pixel
			if mask[next_index] == 1:
				# Move to this pixel
				x = next_x
				y = next_y

				# Next time, start checking 2 directions counter-clockwise
				check_dir = (dir + 6) % 8
				found_next = true
				break

		if not found_next:
			break

		# Stop if we've returned to start
		if not first_pixel and x == start_x and y == start_y:
			break

		first_pixel = false

	print("    Traced boundary with ", contour.size(), " points in ", iterations, " iterations")

	return contour

# Helper to check if a pixel is solid
func _is_solid(mask: PackedByteArray, x: int, y: int, width: int, height: int) -> bool:
	if x < 0 or x >= width or y < 0 or y >= height:
		return false
	return mask[y * width + x] == 1

# Expands polygon like Photoshop's "expand selection" - moves each point along edge normals
func _expand_polygon_photoshop_style(points: PackedVector2Array, expansion: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var expanded = PackedVector2Array()
	var n = points.size()

	for i in range(n):
		var prev_idx = (i - 1 + n) % n
		var next_idx = (i + 1) % n

		var current = points[i]
		var prev = points[prev_idx]
		var next = points[next_idx]

		# Calculate edge vectors
		var edge1 = (current - prev).normalized()
		var edge2 = (next - current).normalized()

		# Calculate normals (perpendicular to edges, pointing outward)
		# In 2D, the perpendicular of (x, y) is (-y, x) for left normal or (y, -x) for right normal
		# We want the outward normal, which for a clockwise polygon is the right normal
		var normal1 = Vector2(edge1.y, -edge1.x)
		var normal2 = Vector2(edge2.y, -edge2.x)

		# Average the two normals to get the direction for this vertex
		var avg_normal = (normal1 + normal2).normalized()

		# Move the point along the average normal
		var expanded_point = current + avg_normal * expansion
		expanded.append(expanded_point)

	return expanded

# Flood fill to mark visited pixels
func _flood_fill_mark(mask: PackedByteArray, visited: PackedByteArray, x: int, y: int, width: int, height: int):
	var stack = [Vector2i(x, y)]

	while stack.size() > 0:
		var pos = stack.pop_back()

		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			continue

		var index = pos.y * width + pos.x

		if visited[index] == 1 or mask[index] == 0:
			continue

		visited[index] = 1

		stack.append(Vector2i(pos.x + 1, pos.y))
		stack.append(Vector2i(pos.x - 1, pos.y))
		stack.append(Vector2i(pos.x, pos.y + 1))
		stack.append(Vector2i(pos.x, pos.y - 1))

# Simplifies polygon using Douglas-Peucker algorithm
func _simplify_polygon(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var result = _douglas_peucker(points, epsilon)

	# Ensure we have at least 3 points for a valid polygon
	if result.size() < 3:
		return points

	return result

# Douglas-Peucker algorithm implementation
func _douglas_peucker(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var dmax = 0.0
	var index = 0
	var end = points.size() - 1

	for i in range(1, end):
		var d = _perpendicular_distance(points[i], points[0], points[end])
		if d > dmax:
			index = i
			dmax = d

	if dmax > epsilon:
		var rec1 = _douglas_peucker(points.slice(0, index + 1), epsilon)
		var rec2 = _douglas_peucker(points.slice(index, end + 1), epsilon)

		var result = PackedVector2Array()
		for i in range(rec1.size() - 1):
			result.append(rec1[i])
		for i in range(rec2.size()):
			result.append(rec2[i])

		return result
	else:
		return PackedVector2Array([points[0], points[end]])

# Calculate perpendicular distance from point to line
func _perpendicular_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var dx = line_end.x - line_start.x
	var dy = line_end.y - line_start.y

	var mag = sqrt(dx * dx + dy * dy)
	if mag < 0.001:
		return point.distance_to(line_start)

	var u = ((point.x - line_start.x) * dx + (point.y - line_start.y) * dy) / (mag * mag)

	var closest = Vector2(
		line_start.x + u * dx,
		line_start.y + u * dy
	)

	return point.distance_to(closest)

# Calculate the area of a polygon using the Shoelace formula
func _calculate_polygon_area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0

	var area = 0.0
	var n = points.size()

	for i in range(n):
		var j = (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y

	return abs(area) / 2.0
