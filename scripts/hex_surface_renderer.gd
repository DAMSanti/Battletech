extends Node2D
class_name HexSurfaceRenderer

@export var depth_viewport_scale: float = 0.5 # default: half-res depth texture for mobile
@export var max_depth_size: Vector2i = Vector2i(2048, 2048) # clamp the depth texture
@export var debug_show_depth: bool = false
@export var occlusion_eps: float = 0.001  # Threshold for occlusion detection
@export var occlusion_hardness: float = 2.0  # Controls occlusion falloff sharpness

var depth_viewport: SubViewport
var depth_root: Node2D
var label_root: Node2D  # Root for elevation labels
@export var culling_margin: int = 128
@export var enable_culling: bool = true
@export var max_polygons_per_frame: int = 4096
var depth_bg: ColorRect
var main_root: Node2D

var depth_pool: Array = []
var main_pool: Array = []
var border_pool: Array = []  # Pool of Line2D for hexagon borders
var overlay_depth_pool: Array = []  # Pool for overlay depth pass
var overlay_main_pool: Array = []  # Pool for overlay main pass
var overlay_border_pool: Array = []  # Pool for overlay borders
var depth_shader: Shader = null
var occlusion_shader: Shader = null
var depth_shader_color = ShaderMaterial.new() # not used; color via modulate
var _debug_depth_container: Node2D = null
var _debug_main_container: Node2D = null
var _debug_test_created: bool = false  # Track if debug test has been created
var _debug_quads: Array = []  # Store references to debug quads for cleanup

# Global map bounds for consistent depth UV mapping
var global_bounds_min: Vector2 = Vector2(1e9, 1e9)
var global_bounds_max: Vector2 = Vector2(-1e9, -1e9)
var global_bounds_valid: bool = false

# Pending overlays to merge with tiles
var pending_overlays: Array = []
var pending_overlays_hex_grid = null

@export var show_elevation_labels: bool = true
@export var debug_depth_test: bool = false # When true, draw two overlapping test polygons to validate occlusion

func _ready():
	# Load shaders once
	depth_shader = load("res://shaders/depth_write.gdshader")
	occlusion_shader = load("res://shaders/surface_occlusion.gdshader")
	
	# Simple debug to verify shader loaded
	if occlusion_shader == null:
		print("[ERROR] occlusion_shader failed to load!")
	else:
		print("[OK] occlusion_shader loaded successfully")
	
	# Create depth viewport and roots
	depth_viewport = SubViewport.new()
	depth_viewport.name = "DepthViewport"
	depth_viewport.disable_3d = true
	# IMPORTANT: Set the rendering mode
	depth_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	# Set to UPDATE_ALWAYS so it continuously renders the depth pass
	depth_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var main_vp = get_viewport()
	var main_size = main_vp.get_size()
	var vp_size = main_size * depth_viewport_scale
	# Clamp
	vp_size.x = min(vp_size.x, max_depth_size.x)
	vp_size.y = min(vp_size.y, max_depth_size.y)
	# Convert to integer size for the SubViewport (size property is Vector2i)
	depth_viewport.size = Vector2i(int(vp_size.x), int(vp_size.y))
	
	print_debug("SubViewport size: %s" % depth_viewport.size)
	# Input is not used by the offscreen SubViewport in this renderer; avoid
	# assigning `disable_input` which does not exist on SubViewport in this
	# engine/exposure. We'll keep the SubViewport non-interactive by design.

	depth_root = Node2D.new()
	depth_root.name = "DepthRoot"
	depth_viewport.add_child(depth_root)

	# Quick debug test: add a test polygon inside the depth viewport so we can
	# confirm the SubViewport is actually drawing CanvasItems. Only create this
	# when the debug view is enabled so it doesn't affect normal runs.
	if debug_show_depth and depth_shader != null:
		var debug_test = Polygon2D.new()
		debug_test.polygon = PackedVector2Array([Vector2(8,8), Vector2(96,8), Vector2(96,96)])
		# Give it a mid-elevation so depth shader writes red ~0.5
		debug_test.uv = PackedVector2Array([Vector2(0.5,0), Vector2(0.5,0), Vector2(0.5,0)])
		var dmat_dbg = ShaderMaterial.new()
		dmat_dbg.shader = depth_shader
		debug_test.material = dmat_dbg
		debug_test.z_index = 1000
		depth_root.add_child(debug_test)

	# Add a background fill so the depth texture starts at zero (black) and
	# doesn't contain accidental white values that would make occlusion discard everything.
	depth_bg = ColorRect.new()
	depth_bg.color = Color(0, 0, 0, 1)
	# depth_viewport.size is Vector2i; ColorRect.rect_size expects Vector2
	# Control/ColorRect prefers `size` as Vector2 (floats) — set size instead
	depth_bg.size = Vector2(float(depth_viewport.size.x), float(depth_viewport.size.y))
	depth_bg.z_index = -100
	depth_root.add_child(depth_bg)

	main_root = Node2D.new()
	main_root.name = "SurfaceRoot"
	main_root.z_index = 0
	add_child(main_root)

	label_root = Node2D.new()
	label_root.name = "LabelRoot"
	label_root.z_index = 4096  # Por encima de todas las superficies (max es 4096)
	add_child(label_root)

	add_child(depth_viewport)

	# Optional debug view to visualize depth buffer
	if debug_show_depth:
		var tex_rect = TextureRect.new()
		tex_rect.name = "DepthDebug"
		tex_rect.texture = depth_viewport.get_texture()
		# depth_viewport.size is Vector2i so convert to Vector2
		var debug_size = Vector2(float(depth_viewport.size.x) / 4.0, float(depth_viewport.size.y) / 4.0)
		tex_rect.size = debug_size
		tex_rect.anchor_left = 1.0
		tex_rect.anchor_top = 0.0
		tex_rect.anchor_right = 1.0
		tex_rect.anchor_bottom = 0.0
		tex_rect.offset_right = -10
		tex_rect.offset_top = 10
		tex_rect.offset_left = tex_rect.offset_right - int(debug_size.x)
		tex_rect.offset_bottom = tex_rect.offset_top + int(debug_size.y)
		add_child(tex_rect)

	# prepare debug containers (created but empty) so test doesn't delete real nodes
	_debug_depth_container = Node2D.new()
	_debug_depth_container.name = "DebugDepthContainer"
	depth_root.add_child(_debug_depth_container)

	_debug_main_container = Node2D.new()
	_debug_main_container.name = "DebugMainContainer"
	# Parent debug main container to the main_root (local space, not screen-space)
	main_root.add_child(_debug_main_container)

	# Accept input so F12 can toggle the debug test at runtime
	set_process_input(true)
	# Also enable _process() for the debug test rendering
	set_process(true)


func _ensure_pool_count(pool: Array, count: int, parent: Node, node_z_index: int = 0):
	while pool.size() < count:
		var p = Polygon2D.new()
		p.z_index = node_z_index
		parent.add_child(p)
		pool.append(p)
	# Hide extras
	for i in range(pool.size() - 1, count - 1, -1):
		var node = pool[i]
		node.visible = false

func _ensure_border_pool_count(count: int):
	while border_pool.size() < count:
		var line = Line2D.new()
		line.z_index = 100  # High z-index to draw on top
		main_root.add_child(line)
		border_pool.append(line)
	# Hide extras
	for i in range(border_pool.size() - 1, count - 1, -1):
		border_pool[i].visible = false

func _ensure_border_pool_count_overlay(count: int):
	while overlay_border_pool.size() < count:
		var line = Line2D.new()
		line.width = 3.0
		line.default_color = Color.WHITE
		line.z_index = 1001  # Por encima de overlays
		main_root.add_child(line)
		overlay_border_pool.append(line)

func update_surfaces(surfaces: Array, base_elevation: int = -2):
	# Guard
	if not is_inside_tree():
		return

	var main_vp = get_viewport()
	var _main_size = main_vp.get_size()
	# CULLING: determine visible rect in global/viewport coordinates
	var _view_rect = main_vp.get_visible_rect()

	# compute max elevation seen
	var max_elev = base_elevation
	for s in surfaces:
		if typeof(s) == TYPE_DICTIONARY and s.has("elevation"):
			max_elev = max(max_elev, int(s["elevation"]))

	print_debug("[ELEV] base_elevation=%d, max_elev=%d, range=%d" % [base_elevation, max_elev, max_elev - base_elevation])

	# Cull surfaces and collect visible list
	var visible_surfaces: Array = []
	# Debug counters
	var debug_total_candidates = 0
	for s in surfaces:
		# Extract polygon points
		var poly_points = null
		if s.has("top_vertices"):
			poly_points = s["top_vertices"]
		elif s.has("points"):
			poly_points = s["points"]
		else:
			continue

		# Compute global AABB by transforming local points to global coordinates
		var min_x = 1e9; var min_y = 1e9; var max_x = -1e9; var max_y = -1e9
		for p in poly_points:
			var gp = to_global(p)
			min_x = min(min_x, gp.x)
			min_y = min(min_y, gp.y)
			max_x = max(max_x, gp.x)
			max_y = max(max_y, gp.y)
		var _bounds = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

		debug_total_candidates += 1
		# TEMPORARY: Disable culling to see all tiles
		visible_surfaces.append(s)
		# if enable_culling:
		#	if bounds.grow(culling_margin).intersects(view_rect):
		#		visible_surfaces.append(s)
		# else:
		#	visible_surfaces.append(s)

	var total = visible_surfaces.size()

	_ensure_pool_count(depth_pool, total, depth_root)
	_ensure_pool_count(main_pool, total, main_root)
	_ensure_border_pool_count(total)
	
	print_debug("HexSurfaceRenderer: total=%d depth_pool_size=%d" % [total, depth_pool.size()])

	var idx = 0
	var stats_processed = 0
	
	# Calculate bounding box of all visible surfaces for proper viewport mapping
	var bounds_min = Vector2(1e9, 1e9)
	var bounds_max = Vector2(-1e9, -1e9)
	# Sort visible surfaces by painter z-order so depth pass draws in the same
	# order as main polygons and higher elevations get drawn last (so they
	# overwrite lower elevations in the depth texture).
	var surf_entries = []
	for s in visible_surfaces:
		var pp = null
		if s.has("top_vertices"):
			pp = s["top_vertices"]
		else:
			pp = s["points"]
		var avg_y = 0.0
		for p in pp:
			avg_y += p.y
		avg_y /= max(1, pp.size())

		var elev_val = float(s.get("elevation", base_elevation))
		
		# ✅ Calcular altura real del tile (height)
		var height = 0.0
		if s.has("type"):
			var surf_type = s["type"]
			if surf_type == "top":
				# Superficie superior: altura = diferencia de elevación respecto a base
				height = (elev_val - base_elevation) * 10.0
			elif surf_type == "side":
				# Cara lateral: altura desde vecino hasta top del tile
				var neighbor_elev = float(s.get("neighbor_elev", base_elevation))
				height = (elev_val - neighbor_elev) * 10.0
			elif surf_type == "shadow":
				# Sombra: altura = 0 (está en el suelo)
				height = 0.0
		
		# ✅ Z-Order: depth = y + height (objetos altos más adelante)
		var depth = avg_y + height
		var zkey = depth
		surf_entries.append({"surf": s, "zkey": zkey, "avg_y": avg_y, "poly_points": pp, "height": height, "depth": depth})

	# Use a helper comparator method (avoids inline ternary and keeps code readable)
	surf_entries.sort_custom(Callable(self, "_surf_cmp"))
	
	# FUSIONAR OVERLAYS con tiles para renderizar intercalados
	var overlay_count = 0
	if pending_overlays.size() > 0 and pending_overlays_hex_grid:
		overlay_count = pending_overlays.size()
		for overlay_data in pending_overlays:
			var hex = overlay_data.get("hex", Vector2i(0, 0))
			var color = overlay_data.get("color", Color(1.0, 0.0, 0.0, 0.5))

			# Buscar el tile correspondiente para usar su elevación
			var tile_elevation = base_elevation
			var tile_depth = null
			for entry in surf_entries:
				if !entry.has("is_overlay") and entry.has("surf") and entry["surf"].has("hex") and entry["surf"].hex == hex:
					if entry["surf"].has("elevation"):
						tile_elevation = entry["surf"]["elevation"]
					tile_depth = entry["depth"]
					break

			# Get base pixel position WITHOUT elevation
			var pixel_pos = pending_overlays_hex_grid.hex_to_pixel(hex, false)

			# Calculate vertices at TILE elevation (same as the tile)
			var elevation_offset = Vector2(0, -tile_elevation * 10.0)
			var top_center = pixel_pos + elevation_offset

			var points = PackedVector2Array()
			for i in range(6):
				var angle = deg_to_rad(60 * i)
				var v = Vector2(
					top_center.x + pending_overlays_hex_grid.hex_size * cos(angle),
					top_center.y + pending_overlays_hex_grid.hex_size * sin(angle)
				)
				points.append(v)

			var avg_y = top_center.y
			var height = tile_elevation * 10.0
			var depth = avg_y + height + 0.1 # valor por defecto
			if tile_depth != null:
				depth = tile_depth + 0.1 # overlay se pinta después del tile

			surf_entries.append({
				"is_overlay": true,
				"hex": hex,
				"color": color,
				"elevation": tile_elevation,
				"poly_points": points,
				"height": height,
				"depth": depth,
				"zkey": depth,
				"avg_y": avg_y
			})
		
		# Re-sort to intercalar overlays with tiles
		surf_entries.sort_custom(Callable(self, "_surf_cmp"))
		
		# Clear pending overlays
		pending_overlays.clear()
	
	# Ensure overlay pools have enough items
	if overlay_count > 0:
		_ensure_pool_count(overlay_depth_pool, overlay_count, depth_root)
		_ensure_pool_count(overlay_main_pool, overlay_count, main_root)
		_ensure_border_pool_count_overlay(overlay_count)

	# Calculate bounds including both tiles and overlays
	for s_entry in surf_entries:
		var poly_points = null
		
		# Check if this is an overlay
		if s_entry.get("is_overlay", false):
			poly_points = s_entry.get("poly_points", null)
		else:
			# Regular tile
			var s = s_entry.get("surf", null)
			if s == null:
				continue
			if s.has("top_vertices"):
				poly_points = s["top_vertices"]
			elif s.has("points"):
				poly_points = s["points"]
		
		if poly_points == null:
			continue
			
		for p in poly_points:
			bounds_min.x = min(bounds_min.x, p.x)
			bounds_min.y = min(bounds_min.y, p.y)
			bounds_max.x = max(bounds_max.x, p.x)
			bounds_max.y = max(bounds_max.y, p.y)
	
	# Calculate scale to fit bounds into depth viewport
	var bounds_size = bounds_max - bounds_min
	var viewport_size = Vector2(float(depth_viewport.size.x), float(depth_viewport.size.y))
	var map_scale_x = viewport_size.x / bounds_size.x if bounds_size.x > 0 else 1.0
	var map_scale_y = viewport_size.y / bounds_size.y if bounds_size.y > 0 else 1.0
	var fit_scale = min(map_scale_x, map_scale_y) * 0.95  # 0.95 to add some margin
	
	# Calculate depth UV transform parameters
	var depth_uv_scale = Vector2(fit_scale / viewport_size.x, fit_scale / viewport_size.y)
	var depth_uv_offset = Vector2(-bounds_min.x * depth_uv_scale.x, -bounds_min.y * depth_uv_scale.y)
	
	print_debug("Bounds: %s to %s, scale: %f" % [bounds_min, bounds_max, fit_scale])
	print_debug("Depth viewport: %s, depth_root children: %d, pools: depth=%d main=%d" % [depth_viewport.size, depth_root.get_child_count(), depth_pool.size(), main_pool.size()])
	print_debug("[RENDER ORDER] Total entries: %d" % surf_entries.size())
	
	var overlay_idx = 0  # Separate counter for overlay pools
	var render_order = 0  # Debug counter
	for s_entry in surf_entries:
		# Check if this is an overlay (not a tile)
		if s_entry.get("is_overlay", false):
			# Render overlay
			var o_depth = s_entry.get("depth", 0.0)
			var o_hex = s_entry.get("hex", Vector2i(0, 0))
			print_debug("  [%d] OVERLAY hex=%s depth=%.2f z_index=%d" % [render_order, o_hex, o_depth, int(o_depth)])
			_render_single_overlay(s_entry, overlay_idx, bounds_min, bounds_max, bounds_size, fit_scale, depth_uv_scale, depth_uv_offset)
			overlay_idx += 1
			render_order += 1
			continue
		
		var s = s_entry["surf"]
		# limit worst-case per-frame work
		if idx >= max_polygons_per_frame:
			break

		var poly_points: PackedVector2Array = s_entry["poly_points"]

		# Normalize elevation to 0..1
		var elev = base_elevation
		if s.has("elevation"):
			elev = float(s["elevation"])
		var _elev_norm = 0.0
		if max_elev > base_elevation:
			_elev_norm = clamp((elev - base_elevation) / float(max_elev - base_elevation), 0.0, 1.0)
		
		# ✅ Obtener altura real de la superficie
		var _height = s_entry.get("height", 0.0)
		var depth = s_entry.get("depth", poly_points[0].y if poly_points.size() > 0 else 0.0)
		
		# ✅ Calcular depth normalizado para ambos passes (depth y main)
		var max_depth = float(max_elev - base_elevation) * 10.0 + bounds_size.y
		var depth_norm = clamp(depth / max(1.0, max_depth), 0.0, 1.0)

		# Depth polygon (draw into depth_viewport) - support per-vertex elevation via UV.x
		var depth_poly: Polygon2D = depth_pool[idx]
		
		# Transform poly_points to viewport coordinates
		# Map from world space to depth viewport space
		var viewport_poly_points = PackedVector2Array()
		for p in poly_points:
			# Translate to origin and scale to fit viewport
			var scaled_p = (p - bounds_min) * fit_scale
			viewport_poly_points.append(scaled_p)
		
		depth_poly.polygon = viewport_poly_points
		depth_poly.position = Vector2.ZERO
		depth_poly.visible = true
		depth_poly.z_index = 0
		depth_poly.texture = null

		# No need for UVs anymore - pass depth as shader parameter
		
		# Assign depth shader material so each fragment writes depth into R channel
		var dmat = ShaderMaterial.new()
		dmat.shader = depth_shader
		depth_poly.material = dmat
		# ✅ Pass DEPTH (not elevation) via modulate color (guaranteed to reach shader)
		depth_poly.modulate = Color(depth_norm, depth_norm, depth_norm, 1.0)

		# Main polygon (draw on main_root) with shader that samples the depth texture
		var main_poly: Polygon2D = main_pool[idx]
		main_poly.polygon = poly_points
		main_poly.position = Vector2.ZERO
		main_poly.visible = true
		main_poly.modulate = Color.WHITE  # Ensure no color tint is hiding the shader color

		# ✅ Calculate Z-index using real depth (y + height)
		# This ensures proper occlusion: tall objects at the same Y position
		# are drawn later and occlude shorter objects correctly
		var zidx = int(depth)
		main_poly.z_index = zidx
		# Make the depth-pass follow the same painter order so the depth texture
		# contains the top-most depth per pixel (last drawn wins).
		depth_poly.z_index = zidx
		
		# DEBUG: Print tile info
		var tile_type = s.get("type", "unknown")
		var tile_hex = s.get("hex", Vector2i(-1, -1))
		if tile_type == "top":
			print_debug("  [%d] TILE hex=%s type=%s depth=%.2f z_index=%d" % [render_order, tile_hex, tile_type, depth, zidx])
		render_order += 1

		# Extract color directly from surface
		var surface_color = Color(0.2, 1.0, 0.2, 1.0)  # Bright green default
		if s.has("color"):
			surface_color = s["color"]
		elif s.has("colors") and typeof(s["colors"]) == TYPE_DICTIONARY and s["colors"].has("light"):
			surface_color = s["colors"]["light"]
		
		# NOTE: Directional lighting for vertical faces is now handled entirely by the shader
		# The shader will apply proper diffuse lighting based on the surface normal direction
		
		# Check if this surface will have a texture
		var will_use_texture = s.has("albedo_texture") and s["albedo_texture"] != ""
		
		# If using texture, set it directly on the Polygon2D
		if will_use_texture:
			var texture_path = s["albedo_texture"]
			var tex = load(texture_path)
			if tex:
				main_poly.texture = tex
				main_poly.color = Color.WHITE  # White = no tint, show texture as-is
				
				# ✅ Generate UVs: Each tile gets full texture (0-1), scaled by texture_scale
				# Calculate bounding box of this specific hexagon
				var min_point = poly_points[0]
				var max_point = poly_points[0]
				for p in poly_points:
					min_point.x = min(min_point.x, p.x)
					min_point.y = min(min_point.y, p.y)
					max_point.x = max(max_point.x, p.x)
					max_point.y = max(max_point.y, p.y)
				
				var bbox_size = max_point - min_point
				
				# texture_scale: how many times the texture repeats across the hexagon
				# 1.0 = texture shown once, 2.0 = texture repeats 2 times, 0.5 = only half texture visible
				var texture_scale = 200.0
				
				var uv_array = PackedVector2Array()
				for p in poly_points:
					# Normalize to 0-1 across the bounding box
					var norm_x = (p.x - min_point.x) / bbox_size.x if bbox_size.x > 0 else 0.5
					var norm_y = (p.y - min_point.y) / bbox_size.y if bbox_size.y > 0 else 0.5
					
					# Scale by texture_scale (higher = more repeats)
					var uv_x = norm_x * texture_scale
					var uv_y = norm_y * texture_scale
					uv_array.append(Vector2(uv_x, uv_y))
				
				main_poly.uv = uv_array
				
				if idx < 3:
					print_debug("[TEXTURE] Loaded: %s (tex_size: %s, scale: %.2f)" % [texture_path, tex.get_size(), texture_scale])
					print_debug("  BBox: %s to %s (size: %s)" % [min_point, max_point, bbox_size])
					print_debug("  UV[0]: %s (normalized from %s)" % [uv_array[0], poly_points[0]])
			else:
				main_poly.texture = null
				main_poly.color = surface_color
				if idx < 3:
					print_debug("[TEXTURE] FAILED to load: %s" % texture_path)
		else:
			# No texture - use solid color
			main_poly.texture = null
			main_poly.color = surface_color
			main_poly.uv = PackedVector2Array()  # Clear UVs
		
		# ✅ ENABLE shader with normal mapping support
		var mat = ShaderMaterial.new()
		mat.shader = occlusion_shader
		mat.set_shader_parameter("depth_tex", depth_viewport.get_texture())
		mat.set_shader_parameter("albedo_color", surface_color)
		mat.set_shader_parameter("surface_depth", depth_norm)
		# DISABLE occlusion for main map tiles - they use z-index sorting
		# Occlusion should only apply to overlays
		mat.set_shader_parameter("occlusion_eps", 999.0)
		mat.set_shader_parameter("occlusion_hardness", occlusion_hardness)
		mat.set_shader_parameter("depth_uv_scale", Vector2(1.0, 1.0))
		mat.set_shader_parameter("depth_uv_offset", Vector2(0.0, 0.0))
		
		# Light from west: negative X, positive Z (pointing right-up in isometric)
		mat.set_shader_parameter("light_direction", Vector3(-0.707, 0.0, 0.707))
		mat.set_shader_parameter("ambient_intensity", 0.4)
		mat.set_shader_parameter("diffuse_intensity", 0.6)
		
		# Set surface normal based on face direction (for vertical faces)
		var surface_normal = Vector3(0.0, 0.0, 1.0)  # Default: horizontal surface (top face)
		if s.has("face_direction"):
			var face_dir = s["face_direction"]
			# Convert hex direction to 3D normal vector
			# HEX_DIRECTIONS: 0=N, 1=NE, 2=NW, 3=S, 4=SW, 5=SE
			match face_dir:
				0:  # N - north face
					surface_normal = Vector3(0.0, -1.0, 0.0)
				1:  # NE - northeast face
					surface_normal = Vector3(0.866, -0.5, 0.0)  # sqrt(3)/2 ≈ 0.866
				2:  # NW - northwest face
					surface_normal = Vector3(-0.866, -0.5, 0.0)
				3:  # S - south face
					surface_normal = Vector3(0.0, 1.0, 0.0)
				4:  # SW - southwest face
					surface_normal = Vector3(-0.866, 0.5, 0.0)
				5:  # SE - southeast face
					surface_normal = Vector3(0.866, 0.5, 0.0)
		mat.set_shader_parameter("surface_normal", surface_normal)
		
		# Check if surface has a normal map
		if s.has("normal_map") and s["normal_map"] != "":
			var normal_map_path = s["normal_map"]
			var normal_tex = load(normal_map_path)
			if normal_tex:
				mat.set_shader_parameter("normal_map", normal_tex)
				mat.set_shader_parameter("use_normal_map", true)
				if idx < 3:
					print_debug("[NORMAL MAP] Loaded: %s" % normal_map_path)
			else:
				mat.set_shader_parameter("use_normal_map", false)
				if idx < 3:
					print_debug("[NORMAL MAP] FAILED to load: %s" % normal_map_path)
		else:
			mat.set_shader_parameter("use_normal_map", false)
		
		main_poly.material = mat
		
		# ✅ Draw hexagon border for "top" surfaces only
		if s.has("type") and s["type"] == "top":
			var border_line: Line2D = border_pool[idx]
			border_line.visible = true
			border_line.z_index = zidx + 1  # Draw border above the tile
			
			# Create closed polygon path (add first point at end to close)
			var border_points = PackedVector2Array()
			for p in poly_points:
				border_points.append(p)
			border_points.append(poly_points[0])  # Close the hexagon
			
			border_line.points = border_points
			border_line.width = 2.0
			border_line.default_color = Color(0.2, 0.2, 0.2, 0.5)  # Dark semi-transparent
			border_line.antialiased = true
		else:
			# Hide border for non-top surfaces (sides, shadows)
			if idx < border_pool.size():
				border_pool[idx].visible = false

		idx += 1
		stats_processed += 1
	
	# Hide any unused pool nodes
	for i in range(idx, depth_pool.size()):
		depth_pool[i].visible = false
	for i in range(idx, main_pool.size()):
		main_pool[i].visible = false
	
	# Hide any unused overlay pool nodes
	for i in range(overlay_idx, overlay_depth_pool.size()):
		overlay_depth_pool[i].visible = false
	for i in range(overlay_idx, overlay_main_pool.size()):
		overlay_main_pool[i].visible = false
	for i in range(overlay_idx, overlay_border_pool.size()):
		overlay_border_pool[i].visible = false
	
	# NUEVA LÓGICA DE LABELS: Crear labels SOLO para tiles "top" después de procesar todo
	if show_elevation_labels:
		# Limpiar todas las labels anteriores
		for child in label_root.get_children():
			child.queue_free()
		
		# Crear nuevas labels solo para superficies "top" QUE FUERON PROCESADAS
		# Solo procesar hasta idx (las que realmente se renderizaron)
		for i in range(min(idx, surf_entries.size())):
			var s_entry = surf_entries[i]
			
			# Skip overlays - they don't have labels
			if s_entry.get("is_overlay", false):
				continue
			
			var s = s_entry.get("surf", null)
			if s == null:
				continue
			
			# Solo procesar superficies tipo "top"
			if not (s.has("type") and s["type"] == "top"):
				continue
			
			var poly_points: PackedVector2Array = s_entry["poly_points"]
			
			# Calcular centro del polígono
			var center = Vector2.ZERO
			for p in poly_points:
				center += p
			center /= poly_points.size()
			
			# Obtener elevación
			var elev = base_elevation
			if s.has("elevation"):
				elev = float(s["elevation"])
			var elev_offset = int(elev) - base_elevation
			
			# Crear label
			var lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_constant_override("outline_size", 4)
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.size = Vector2(40, 30)
			lbl.position = center - Vector2(20, 15)
			lbl.z_index = 0  # El z_index del label_root ya es suficiente
			
			# Formatear texto
			var elev_str = ""
			if elev_offset > 0:
				elev_str = "+%d" % elev_offset
				lbl.add_theme_color_override("font_color", Color.YELLOW)
			elif elev_offset < 0:
				elev_str = "%d" % elev_offset
				lbl.add_theme_color_override("font_color", Color.CYAN)
			else:
				elev_str = "0"
				lbl.add_theme_color_override("font_color", Color.WHITE)
			
			lbl.text = elev_str
			label_root.add_child(lbl)

	# Debug: print small stats so we can tune
	if Engine.is_editor_hint() or debug_show_depth:
		print_debug("HexSurfaceRenderer: candidates=%d visible=%d processed=%d" % [debug_total_candidates, visible_surfaces.size(), stats_processed])

func set_depth_viewport_scale(vp_scale: float):
	depth_viewport_scale = clamp(vp_scale, 0.1, 2.0)
	var main_vp = get_viewport()
	var vp_size = main_vp.get_size() * depth_viewport_scale
	vp_size.x = min(vp_size.x, max_depth_size.x)
	vp_size.y = min(vp_size.y, max_depth_size.y)
	depth_viewport.size = Vector2i(int(vp_size.x), int(vp_size.y))
	if depth_bg:
		# depth_bg.rect_size expects Vector2
		depth_bg.size = Vector2(float(depth_viewport.size.x), float(depth_viewport.size.y))


# Comparator used by sort_custom to sort surfaces by zkey
func _surf_cmp(a, b):
	return a["zkey"] < b["zkey"]

func _input(event):
	# Toggle debug test with F12 at runtime
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			debug_depth_test = not debug_depth_test
			print_debug("HexSurfaceRenderer: debug_depth_test toggled -> %s" % str(debug_depth_test))
			get_tree().root.set_input_as_handled()  # Consume the input
			
			if not debug_depth_test:
				# Clear debug nodes when disabled
				for c in _debug_depth_container.get_children():
					c.queue_free()
				for c in _debug_main_container.get_children():
					c.queue_free()
				print_debug("[TEST] Debug test disabled and cleared")

func _process(_delta):
	# Debug test: simple polygons without containers
	if debug_depth_test:
		if not _debug_test_created:
			print_debug("[TEST] Creating debug quads WITH OCCLUSION SHADER...")
			_debug_quads.clear()
			
			# First, create LOW quad in DEPTH PASS
			var low_depth = Polygon2D.new()
			low_depth.polygon = PackedVector2Array([Vector2(100,100), Vector2(200,100), Vector2(200,200), Vector2(100,200)])
			var dmat_l = ShaderMaterial.new()
			dmat_l.shader = depth_shader
			low_depth.material = dmat_l
			low_depth.modulate = Color(0.2, 0.2, 0.2, 1.0)  # LOW elevation via modulate
			low_depth.z_index = 100
			depth_root.add_child(low_depth)
			_debug_quads.append(low_depth)
			print_debug("[TEST] Added LOW depth quad (elev=0.2)")
			
			# Draw LOW quad in MAIN PASS with occlusion shader
			var low = Polygon2D.new()
			low.polygon = PackedVector2Array([Vector2(100,100), Vector2(200,100), Vector2(200,200), Vector2(100,200)])
			low.color = Color.BLUE
			low.uv = PackedVector2Array([Vector2(0,0.2), Vector2(0,0.2), Vector2(0,0.2), Vector2(0,0.2)])
			low.z_index = 2147483647
			
			var mat_low = ShaderMaterial.new()
			mat_low.shader = occlusion_shader
			mat_low.set_shader_parameter("depth_tex", depth_viewport.get_texture())
			mat_low.set_shader_parameter("albedo", Color.BLUE)
			mat_low.set_shader_parameter("debug_visualize", false)
			mat_low.set_shader_parameter("depth_uv_scale", Vector2(1.0, 1.0))
			mat_low.set_shader_parameter("depth_uv_offset", Vector2(0.0, 0.0))
			low.material = mat_low
			
			main_root.add_child(low)
			_debug_quads.append(low)
			print_debug("[TEST] Added LOW main quad (blue) with occlusion shader")
			
			# Create HIGH quad in DEPTH PASS
			var high_depth = Polygon2D.new()
			high_depth.polygon = PackedVector2Array([Vector2(150,150), Vector2(250,150), Vector2(250,250), Vector2(150,250)])
			var dmat_h = ShaderMaterial.new()
			dmat_h.shader = depth_shader
			high_depth.material = dmat_h
			high_depth.modulate = Color(0.8, 0.8, 0.8, 1.0)  # HIGH elevation via modulate
			high_depth.z_index = 200  # Drawn after LOW in depth pass
			depth_root.add_child(high_depth)
			_debug_quads.append(high_depth)
			print_debug("[TEST] Added HIGH depth quad (elev=0.8)")
			
			# Draw HIGH quad in MAIN PASS with occlusion shader
			var high = Polygon2D.new()
			high.polygon = PackedVector2Array([Vector2(150,150), Vector2(250,150), Vector2(250,250), Vector2(150,250)])
			high.color = Color.RED
			high.uv = PackedVector2Array([Vector2(0,0.8), Vector2(0,0.8), Vector2(0,0.8), Vector2(0,0.8)])
			high.z_index = 2147483646
			
			var mat_high = ShaderMaterial.new()
			mat_high.shader = occlusion_shader
			mat_high.set_shader_parameter("depth_tex", depth_viewport.get_texture())
			mat_high.set_shader_parameter("albedo", Color.RED)
			mat_high.set_shader_parameter("debug_visualize", false)
			mat_high.set_shader_parameter("depth_uv_scale", Vector2(1.0, 1.0))
			mat_high.set_shader_parameter("depth_uv_offset", Vector2(0.0, 0.0))
			high.material = mat_high
			
			main_root.add_child(high)
			_debug_quads.append(high)
			print_debug("[TEST] Added HIGH main quad (red) with occlusion shader")
			
			_debug_test_created = true
			print_debug("[TEST] Debug test with occlusion shader created!")
	else:
		if _debug_test_created:
			print_debug("[TEST] Cleaning up debug quads...")
			_debug_test_created = false
			for quad in _debug_quads:
				if is_instance_valid(quad):
					quad.queue_free()
			_debug_quads.clear()
			print_debug("[TEST] Debug quads cleaned up")

# Renderizar overlays con oclusión correcta
# overlays: Array de {hex: Vector2i, color: Color, elevation: float}
func render_overlays(overlays: Array, hex_grid):
	if not hex_grid:
		return
	
	# Almacenar overlays para fusionarlos con tiles en update_surfaces
	pending_overlays = overlays
	pending_overlays_hex_grid = hex_grid
	
	# Forzar actualización del terreno para que se procesen juntos
	if hex_grid:
		hex_grid.queue_redraw()

# Render a single overlay intercalado con tiles
func _render_single_overlay(s_entry: Dictionary, idx: int, _bounds_min: Vector2, _bounds_max: Vector2, bounds_size: Vector2, _fit_scale: float, _depth_uv_scale: Vector2, _depth_uv_offset: Vector2):
	var points = s_entry.get("poly_points", PackedVector2Array())
	if points.size() == 0:
		# No points to render, hide the overlay
		if idx < overlay_depth_pool.size():
			overlay_depth_pool[idx].visible = false
		if idx < overlay_main_pool.size():
			overlay_main_pool[idx].visible = false
		if idx < overlay_border_pool.size():
			overlay_border_pool[idx].visible = false
		return
	
	var color = s_entry.get("color", Color(1.0, 0.0, 0.0, 0.5))
	var depth = s_entry.get("depth", 0.0)
	var max_depth = bounds_size.y + 100.0 * 10.0
	var depth_norm = clamp(depth / max(1.0, max_depth), 0.0, 1.0)
	
	# IMPORTANTE: Añadir un pequeño offset positivo al depth_norm del overlay
	# para que siempre esté "ligeramente por delante" y no se auto-oculte
	var overlay_depth_offset = 0.002  # Pequeño offset para evitar auto-oclusión
	depth_norm = clamp(depth_norm + overlay_depth_offset, 0.0, 1.0)
	
	# DEPTH PASS: Los overlays NO escriben en depth buffer, solo leen
	# Si escriben, ocultarían los tiles que vienen después
	var depth_poly: Polygon2D = overlay_depth_pool[idx]
	depth_poly.visible = false  # NO escribir en depth buffer
	
	# MAIN PASS: Render with occlusion
	var main_poly: Polygon2D = overlay_main_pool[idx]
	main_poly.polygon = points
	main_poly.position = Vector2.ZERO
	main_poly.visible = true
	main_poly.color = color
	# Z-index basado en depth (que ya tiene +0.1 offset del sorting)
	main_poly.z_index = int(depth)
	main_poly.texture = null
	
	# SIN SHADER - usar solo el color directo para ver el overlay
	main_poly.material = null
	
	# Dibujar borde del overlay
	var border_line: Line2D = overlay_border_pool[idx]
	border_line.visible = true
	border_line.z_index = int(depth) + 1  # Por encima del overlay
	border_line.width = 3.0
	var border_color = Color(color.r, color.g, color.b, min(1.0, color.a * 2.0))
	border_line.default_color = border_color
	
	if points.size() > 0:
		var border_points = PackedVector2Array()
		for p in points:
			border_points.append(p)
		border_points.append(points[0])  # Cerrar hexágono
		border_line.points = border_points
	else:
		border_line.visible = false

func _update_debug_test():
	# Ensure containers exist
	if not _debug_depth_container or not _debug_main_container:
		print_debug("[TEST] ERROR: Debug containers not initialized!")
		return
	
	print_debug("[TEST] Creating debug quads WITH occlusion shader...")

	# Draw a low elevation quad in DEPTH PASS first
	var low_depth = Polygon2D.new()
	low_depth.polygon = PackedVector2Array([Vector2(100,100), Vector2(200,100), Vector2(200,200), Vector2(100,200)])
	low_depth.uv = PackedVector2Array([Vector2(0.2,0), Vector2(0.2,0), Vector2(0.2,0), Vector2(0.2,0)])
	var dmat_l = ShaderMaterial.new()
	dmat_l.shader = depth_shader
	low_depth.material = dmat_l
	low_depth.z_index = 100000
	_debug_depth_container.add_child(low_depth)
	print_debug("[TEST] Added LOW depth quad (elev=0.2)")

	# Draw LOW in MAIN PASS with occlusion shader
	var low_main = Polygon2D.new()
	low_main.polygon = PackedVector2Array([Vector2(100,100), Vector2(200,100), Vector2(200,200), Vector2(100,200)])
	low_main.uv = PackedVector2Array([Vector2(0.2,0), Vector2(0.2,0), Vector2(0.2,0), Vector2(0.2,0)])
	low_main.color = Color(0.0, 0.5, 1.0)  # Blue
	low_main.z_index = 100000
	
	var mat_low = ShaderMaterial.new()
	mat_low.shader = occlusion_shader
	mat_low.set_shader_parameter("depth_tex", depth_viewport.get_texture())
	mat_low.set_shader_parameter("albedo", Color(0.0, 0.5, 1.0))
	mat_low.set_shader_parameter("debug_visualize", false)
	mat_low.set_shader_parameter("depth_uv_scale", Vector2(1.0, 1.0))
	mat_low.set_shader_parameter("depth_uv_offset", Vector2(0.0, 0.0))
	low_main.material = mat_low
	_debug_main_container.add_child(low_main)
	print_debug("[TEST] Added LOW main quad (blue)")

	# Draw a high elevation quad in DEPTH PASS
	var high_depth = Polygon2D.new()
	high_depth.polygon = PackedVector2Array([Vector2(150,150), Vector2(250,150), Vector2(250,250), Vector2(150,250)])
	high_depth.uv = PackedVector2Array([Vector2(0.8,0), Vector2(0.8,0), Vector2(0.8,0), Vector2(0.8,0)])
	var dmat_h = ShaderMaterial.new()
	dmat_h.shader = depth_shader
	high_depth.material = dmat_h
	high_depth.z_index = 100001  # Higher z_index so drawn last in depth pass
	_debug_depth_container.add_child(high_depth)
	print_debug("[TEST] Added HIGH depth quad (elev=0.8)")

	# Draw HIGH in MAIN PASS with occlusion shader
	var high_main = Polygon2D.new()
	high_main.polygon = PackedVector2Array([Vector2(150,150), Vector2(250,150), Vector2(250,250), Vector2(150,250)])
	high_main.uv = PackedVector2Array([Vector2(0.8,0), Vector2(0.8,0), Vector2(0.8,0), Vector2(0.8,0)])
	high_main.color = Color(1.0, 0.2, 0.2)  # Red
	high_main.z_index = 100001  # Higher z_index so drawn last (on top)
	
	var mat_high = ShaderMaterial.new()
	mat_high.shader = occlusion_shader
	mat_high.set_shader_parameter("depth_tex", depth_viewport.get_texture())
	mat_high.set_shader_parameter("albedo", Color(1.0, 0.2, 0.2))
	mat_high.set_shader_parameter("debug_visualize", false)
	mat_high.set_shader_parameter("depth_uv_scale", Vector2(1.0, 1.0))
	mat_high.set_shader_parameter("depth_uv_offset", Vector2(0.0, 0.0))
	high_main.material = mat_high
	_debug_main_container.add_child(high_main)
	print_debug("[TEST] Added HIGH main quad (red)")

	# Add labels for clarity
	var lbl_low = Label.new()
	lbl_low.text = "LOW (0.2)"
	lbl_low.position = Vector2(105, 105)
	lbl_low.add_theme_color_override("font_color", Color.WHITE)
	_debug_main_container.add_child(lbl_low)

	var lbl_high = Label.new()
	lbl_high.text = "HIGH (0.8)"
	lbl_high.position = Vector2(155, 155)
	lbl_high.add_theme_color_override("font_color", Color.WHITE)
	_debug_main_container.add_child(lbl_high)

	print_debug("[TEST] Debug test created - should see blue (LOW) and red (HIGH) with occlusion")
