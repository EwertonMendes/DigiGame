extends RefCounted
class_name IsometricSpriteBatch

const SUBDIVISIONS := 4


static func build(specs: Array[Dictionary], catalog: Dictionary, node_name: String, z: int) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = z
	var groups := {}
	for spec: Dictionary in specs:
		var asset_id := String(spec.get("asset", ""))
		if not catalog.has(asset_id):
			continue
		if not groups.has(asset_id):
			groups[asset_id] = []
		(groups[asset_id] as Array).append(spec)
	for asset_id: String in groups:
		var asset := catalog[asset_id] as Dictionary
		var texture := load(String(asset.get("path", ""))) as Texture2D
		if texture == null:
			continue
		var mesh := MeshInstance2D.new()
		mesh.name = asset_id
		mesh.texture = texture
		mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mesh.mesh = _build_mesh(groups[asset_id] as Array, asset)
		root.add_child(mesh)
	return root


static func _build_mesh(specs: Array, asset: Dictionary) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var image_size := _vec2(asset.get("image_size", [1, 1]))
	var bounds_value: Array = asset.get("bounds", [0, 0, image_size.x, image_size.y])
	var bounds := Rect2(float(bounds_value[0]), float(bounds_value[1]), float(bounds_value[2]), float(bounds_value[3]))
	var source_points := _points(asset.get("anchors", []))
	if source_points.size() != 4:
		return ArrayMesh.new()
	var source_frame := Transform2D(source_points[1] - source_points[0], source_points[3] - source_points[0], source_points[0])
	if absf(source_frame.determinant()) < 0.001:
		return ArrayMesh.new()
	var inverse := source_frame.affine_inverse()
	for raw_spec in specs:
		var spec := raw_spec as Dictionary
		var target := spec.get("points") as PackedVector2Array
		if target.size() != 4:
			continue
		var base := vertices.size()
		# The artist's footprint anchors follow the authored quad. A small mesh
		# also supports a trapezoidal resize without adding a node per pixel/tile.
		for row in range(SUBDIVISIONS + 1):
			for column in range(SUBDIVISIONS + 1):
				var pixel := bounds.position + bounds.size * Vector2(float(column), float(row)) / float(SUBDIVISIONS)
				var local := inverse * pixel
				var back := target[0].lerp(target[1], local.x)
				var front := target[3].lerp(target[2], local.x)
				vertices.append(back.lerp(front, local.y))
				uvs.append(pixel / image_size)
		for row in range(SUBDIVISIONS):
			for column in range(SUBDIVISIONS):
				var a := base + row * (SUBDIVISIONS + 1) + column
				var b := a + 1
				var c := a + SUBDIVISIONS + 2
				var d := a + SUBDIVISIONS + 1
				indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	if not vertices.is_empty():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


static func _points(value: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in value:
		result.append(_vec2(point))
	return result


static func _vec2(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
