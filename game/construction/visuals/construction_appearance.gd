extends RefCounted
## One material recipe shared by actual sites and renderer-only startup warming.
const Reveal = preload("res://game/construction/visuals/build_reveal.gdshader")
const Hologram = preload("res://game/construction/visuals/build_hologram.gdshader")
const Outline = preload("res://game/construction/visuals/build_outline.gdshader")

static func prepare(owner: Node3D, shell: Node3D, bounds: AABB) -> Dictionary:
	var materials: Array[ShaderMaterial] = []
	var originals: Array[Dictionary] = []
	var ghosts: Array[MeshInstance3D] = []
	for child: Node in shell.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null: continue
		var outline := _shader(Outline,owner,bounds,materials)
		for surface in mesh.mesh.get_surface_count():
			var original: Material = mesh.get_active_material(surface)
			originals.append({"mesh":mesh,"surface":surface,"override":mesh.get_surface_override_material(surface)})
			var reveal := _shader(Reveal,owner,bounds,materials)
			if original is BaseMaterial3D:
				var standard := original as BaseMaterial3D
				reveal.set_shader_parameter("tint",standard.albedo_color)
				reveal.set_shader_parameter("vertex_colored",standard.vertex_color_use_as_albedo)
				reveal.set_shader_parameter("material_roughness",standard.roughness)
				reveal.set_shader_parameter("material_metallic",standard.metallic)
				if standard.albedo_texture != null:
					reveal.set_shader_parameter("albedo_map",standard.albedo_texture)
					reveal.set_shader_parameter("textured",true)
			reveal.next_pass = outline
			mesh.set_surface_override_material(surface,reveal)
		originals.append({"mesh":mesh,"whole":mesh.material_override})
		mesh.material_override = null
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh.mesh
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.material_override = _shader(Hologram,owner,bounds,materials)
		owner.add_child(ghost)
		ghost.global_transform = mesh.global_transform
		ghosts.append(ghost)
	return {"materials":materials,"originals":originals,"ghosts":ghosts}

static func _shader(shader: Shader, owner: Node3D, bounds: AABB, materials: Array[ShaderMaterial]) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_y",owner.global_position.y+bounds.position.y)
	material.set_shader_parameter("height",bounds.size.y)
	materials.append(material)
	return material

static func fade_materials(node: Node3D) -> Array:
	var materials: Array = []
	var meshes: Array[Node] = node.find_children("*","MeshInstance3D",true,false)
	if node is MeshInstance3D: meshes.push_front(node)
	for child: Node in meshes:
		var mesh := child as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null: continue
			var material := original.duplicate() as BaseMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = false
			var colour := material.albedo_color
			colour.a = 0.0
			material.albedo_color = colour
			mesh.set_surface_override_material(surface,material)
			materials.append(material)
	return materials
