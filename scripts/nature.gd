class_name Nature
## Matières du décor extérieur : sol, chemins, boue, feuillage, herbe (avec le vent), eau, écorce.
## Textures dans assets/textures (ambientCG, CC0 – voir CREDITS.txt).

const TEX := "res://assets/textures/"

## Sol, chemin ou boue : texture plaquée selon la position dans le monde (aucune couture entre les morceaux).
## "metres" : taille d'un motif de texture au sol.
static func ground(name: String, metres: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = load(TEX + name + "_couleur.jpg")
	m.normal_enabled = true
	m.normal_texture = load(TEX + name + "_normal.jpg")
	m.roughness_texture = load(TEX + name + "_rugosite.jpg")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / metres
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.metallic_specular = 0.25   # un sol mat : pas de reflet bleuté du ciel
	return m

## Feuillage des arbres et des buissons (feuilles détourées, visibles des deux côtés).
static func foliage() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + "feuillage.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	m.backlight_enabled = true                  # la lumière traverse un peu les feuilles
	m.backlight = Color(0.25, 0.35, 0.1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

## Écorce (troncs couchés) : réutilise la texture des arbres.
static func bark(length: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/models/Bark_NormalTree.png")
	m.albedo_color = Color(0.66, 0.56, 0.5)
	m.uv1_scale = Vector3(3.0, maxf(1.0, length / 1.5), 1.0)
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## Eau du ruisseau : relief de vaguelettes qui défile (voir main.gd, _process).
static func water() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	nt.noise = noise
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.45, 0.62, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.9
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.25
	return m

# ---------- Herbe ----------
const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base_col : source_color = vec3(0.13, 0.28, 0.08);
uniform vec3 tip_col : source_color = vec3(0.5, 0.72, 0.28);
uniform float wind = 1.0;

void vertex() {
	float h = UV.y;   // 0 au pied du brin, 1 à la pointe
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.22) * 0.07 + sin(TIME * 3.3 + wp.x * 1.7 - wp.z) * 0.025;
	VERTEX.x += sway * h * h * wind;
	VERTEX.z += sway * 0.6 * h * h * wind;
	NORMAL = vec3(0.0, 1.0, 0.0);   // éclairé comme le sol : pas de face sombre
}

void fragment() {
	ALBEDO = mix(base_col, tip_col, UV.y);
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.15, 0.25, 0.05);
}
"""

static func grass_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

## Touffe de 4 brins fins et courbés (1 m de haut, mise à l'échelle par l'instance).
static func grass_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for k in 4:
		var yaw := k * TAU / 4.0 + r.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var lean := r.randf_range(0.15, 0.35)
		var base := dir * r.randf_range(0.0, 0.06)
		var w := r.randf_range(0.035, 0.05)
		var h := r.randf_range(0.75, 1.0)
		# 3 hauteurs : pied, milieu, pointe (le brin s'incline de plus en plus)
		var pts := [
			[base - side * w, 0.0], [base + side * w, 0.0],
			[base + dir * lean * 0.35 + Vector3(0, h * 0.5, 0) - side * w * 0.7, 0.5],
			[base + dir * lean * 0.35 + Vector3(0, h * 0.5, 0) + side * w * 0.7, 0.5],
			[base + dir * lean + Vector3(0, h, 0), 1.0],
		]
		var tris := [[0, 1, 2], [1, 3, 2], [2, 3, 4]]
		for t in tris:
			for i in t:
				st.set_uv(Vector2(0.5, pts[i][1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[i][0])
	return st.commit()

# ---------- Buissons ----------
## Buisson : des boules sombres pour le volume, couvertes de cartes de feuillage.
static func bush(rng: RandomNumberGenerator, leaf_mat: Material) -> Node3D:
	var holder := Node3D.new()
	var inner := StandardMaterial3D.new()
	inner.albedo_color = Color(0.16, 0.27, 0.11)
	inner.roughness = 1.0
	var blobs: Array = []
	for k in 5:
		var br: float = rng.randf_range(0.5, 0.85)
		var c := Vector3(rng.randf_range(-0.9, 0.9), br * 0.75, rng.randf_range(-0.9, 0.9))
		blobs.append([c, br])
		var sm := SphereMesh.new()
		sm.radius = br * 0.68
		sm.height = br * 1.3
		sm.radial_segments = 12
		sm.rings = 6
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = inner
		mi.position = c
		holder.add_child(mi)
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = 130
	for i in mm.instance_count:
		var b: Array = blobs[i % blobs.size()]
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.35, 1), rng.randf_range(-1, 1)).normalized()
		var pos: Vector3 = b[0] + n * float(b[1]) * rng.randf_range(0.75, 1.0)
		var basis := Basis.looking_at(n, Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD)
		basis = basis.rotated(n, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25))
		mm.set_instance_transform(i, Transform3D(basis, pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = leaf_mat
	holder.add_child(mmi)
	return holder

# ---------- Pelage et plumage des animaux ----------
static var _fur_cache := {}

## Pelage : bruit fin (poils) dans les teintes de la couleur de base, avec un léger relief.
static func fur(base: Color, fine := 9.0) -> StandardMaterial3D:
	var id := "%s|%.1f" % [base.to_html(), fine]
	if _fur_cache.has(id):
		return _fur_cache[id]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var grad := Gradient.new()
	grad.set_color(0, base.darkened(0.4))
	grad.set_color(1, base.lightened(0.18))
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var nrm := NoiseTexture2D.new()
	nrm.width = 128
	nrm.height = 128
	nrm.seamless = true
	nrm.noise = noise
	nrm.as_normal_map = true
	nrm.bump_strength = 4.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = nrm
	m.normal_scale = 0.7
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * fine
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_fur_cache[id] = m
	return m