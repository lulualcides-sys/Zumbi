extends Node3D
## Zombie Outbreak v0.2: movimento independente da mira, camera 3/4 e objetos quebraveis.
## Modelos e decoracoes sao primitivos originais; nenhum download externo em runtime.

const Models = preload("res://scripts/ActorFactory.gd")
const Artwork = preload("res://scripts/VisualAssets.gd")
const StreetSurface = preload("res://scripts/SurfaceTextures.gd")
const WALK_SPEED := 5.2
const RUN_SPEED := 8.0
const FIRE_INTERVAL := 0.12
const RELOAD_SECONDS := 1.45
const MAG_SIZE := 32
const MAX_ENEMIES := 26
const WORLD_LIMIT := 17.0
const CAMERA_OFFSET := Vector3(0.0, 9.3, 14.2)

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var footer: Label
var reticle: Control
var player_rig: Dictionary = {}
var player_art: Dictionary = {}
var zombie_state: Dictionary = {}
var zombies: Array[CharacterBody3D] = []
var destructibles: Dictionary = {}
var pickups: Array[Node3D] = []
var aim_direction := Vector3.FORWARD
var ammo := MAG_SIZE
var reserve_ammo := 160
var hp := 100
var score := 0
var wave := 0
var pending_spawns := 0
var fire_cooldown := 0.0
var reload_timer := 0.0
var damage_cooldown := 0.0
var spawn_timer := 0.0
var wave_delay := 0.0
var walk_cycle := 0.0
var recoil := 0.0
var elapsed := 0.0
var hit_flash := 0.0
var last_move := Vector3.ZERO

func _ready() -> void:
    rng.randomize()
    _environment()
    _level()
    _create_player()
    _create_camera()
    _create_ui()
    _start_wave()
    _update_hud()

func _environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#122027")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#7c95a0")
    env.ambient_light_energy = 0.60
    world.environment = env
    add_child(world)
    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-57, -31, 0)
    moon.light_color = Color("#a6c5d6")
    moon.light_energy = 1.35
    moon.shadow_enabled = true
    add_child(moon)

func _visual_box(parent: Node3D, where: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
    return Models.box(parent, where, dimensions, color)

func _solid_box(where: Vector3, dimensions: Vector3, color: Color, health: int = 0) -> StaticBody3D:
    var object := StaticBody3D.new()
    object.position = where
    add_child(object)
    var shape := CollisionShape3D.new()
    var cube := BoxShape3D.new()
    cube.size = dimensions
    shape.shape = cube
    object.add_child(shape)
    _visual_box(object, Vector3.ZERO, dimensions, color)
    if health > 0:
        destructibles[object] = {"health": health, "size": dimensions, "tint": color}
    return object

func _fence_segment(at: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = at
    add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.88, 1.20, 0.25)
    collider.shape = shape
    body.add_child(collider)
    var planks := Color("#7f5940")
    for n in range(6):
        var x := -0.78 + float(n) * 0.31
        var plank := _visual_box(body, Vector3(x, 0, 0), Vector3(0.24, 1.15, 0.14), planks)
        plank.rotation.z = rng.randf_range(-0.035, 0.035)
    _visual_box(body, Vector3(0, 0.32, -0.13), Vector3(1.90, 0.13, 0.16), Color("#65422e"))
    _visual_box(body, Vector3(0, -0.32, -0.13), Vector3(1.90, 0.13, 0.16), Color("#65422e"))
    destructibles[body] = {"health": 4, "size": Vector3(1.88, 1.15, 0.22), "tint": planks}

func _street_lamp(at: Vector3) -> void:
    _visual_box(self, at + Vector3(0, 2.15, 0), Vector3(0.17, 4.3, 0.17), Color("#354e55"))
    _visual_box(self, at + Vector3(0.50, 4.25, 0), Vector3(1.0, 0.12, 0.20), Color("#354e55"))
    _visual_box(self, at + Vector3(0.92, 4.07, 0), Vector3(0.35, 0.08, 0.35), Color("#e7d6a1"))
    var light := OmniLight3D.new()
    light.position = at + Vector3(0.90, 3.95, 0)
    light.light_color = Color("#f4c788")
    light.light_energy = 0.85
    light.omni_range = 7.0
    add_child(light)

func _level() -> void:
    var ground := _solid_box(Vector3(0, -0.38, 0), Vector3(40, 0.76, 40), Color("#26353b"))
    var ground_visual := ground.get_child(1) as MeshInstance3D
    ground_visual.material_override = StreetSurface.asphalt_material(Color("#5b6870"), 20.0)
    var road_north := _visual_box(self, Vector3(0, 0.009, 0), Vector3(10.0, 0.024, 39.0), Color("#303d40"))
    var road_east := _visual_box(self, Vector3(0, 0.012, 0), Vector3(39.0, 0.024, 10.0), Color("#303d40"))
    road_north.material_override = StreetSurface.asphalt_material(Color("#6a6d68"), 12.0)
    road_east.material_override = StreetSurface.asphalt_material(Color("#636b69"), 12.0)
    for i in range(-3, 4):
        _visual_box(self, Vector3(0, 0.031, float(i) * 5.0), Vector3(0.13, 0.02, 2.2), Color("#a59965"))
        _visual_box(self, Vector3(float(i) * 5.0, 0.034, 0), Vector3(2.0, 0.02, 0.13), Color("#a59965"))
    for row in range(-9, 10):
        # Grade discreta igual ao piso de prototipo do video.
        var tint := Color("#32454b")
        _visual_box(self, Vector3(float(row) * 2.0, 0.018, 0), Vector3(0.018, 0.008, 39.0), tint)
        _visual_box(self, Vector3(0, 0.018, float(row) * 2.0), Vector3(39.0, 0.008, 0.018), tint)
    for i in range(5):
        _fence_segment(Vector3(-4.0 + float(i) * 1.9, 0.65, -3.1))
    for i in range(4):
        _fence_segment(Vector3(3.8 + float(i) * 1.9, 0.65, 4.6))
    _solid_box(Vector3(-11.7, 0.68, -9.0), Vector3(2.9, 1.35, 1.6), Color("#505d5e"), 7)
    _solid_box(Vector3(12.0, 0.72, 8.0), Vector3(3.2, 1.45, 1.5), Color("#516066"), 7)
    _solid_box(Vector3(-9.0, 0.6, 7.0), Vector3(1.35, 1.18, 1.4), Color("#755c46"), 4)
    _solid_box(Vector3(8.0, 0.45, -9.0), Vector3(1.15, 0.90, 1.15), Color("#7b6046"), 4)
    for i in range(7):
        var px := rng.randf_range(-14, 14)
        var pz := rng.randf_range(-14, 14)
        if Vector2(px, pz).length() < 6.0:
            continue
        _solid_box(Vector3(px, 0.42, pz), Vector3(0.9, 0.83, 0.9), Color("#5b6665"), 3)
    for x in [-19.1, 19.1]:
        _solid_box(Vector3(float(x), 1.0, 0), Vector3(0.6, 2.0, 38), Color("#46545a"))
    for z in [-19.1, 19.1]:
        _solid_box(Vector3(0, 1.0, float(z)), Vector3(38, 2.0, 0.6), Color("#46545a"))
    _street_lamp(Vector3(-15, 0, -13))
    _street_lamp(Vector3(14, 0, 13))
    _street_lamp(Vector3(14, 0, -12))
    _street_lamp(Vector3(6.0, 0, -7.6))
    # Props CC0 com geometria, UVs, materiais e silhuetas reais. Fallback
    # permanece jogavel quando o pacote visual ainda nao foi instalado.
    Artwork.add_prop(self, "container_green.gltf", Vector3(-12, 0.02, -13), 0.77, 0.22)
    Artwork.add_prop(self, "pallet.gltf", Vector3(-3.1, 0.02, 2.1), 1.0, 0.45)
    Artwork.add_prop(self, "barrel.gltf", Vector3(4.8, 0.02, -2.4), 1.0)
    Artwork.add_prop(self, "barrel.gltf", Vector3(5.6, 0.02, -2.2), 1.0)
    Artwork.add_prop(self, "traffic_barrier.gltf", Vector3(-5.6, 0.02, 1.0), 1.15, -0.32)

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Survivor"
    player.position = Vector3(0, 0.88, 0)
    add_child(player)
    player_rig = Models.survivor(player)
    player_art = Artwork.attach_character(player, player_rig, "survivor")

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.name = "ThreeQuarterCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 8.8
    camera.near = 0.1
    camera.far = 110.0
    camera.current = true
    add_child(camera)
    camera.global_position = player.global_position + CAMERA_OFFSET
    camera.look_at(player.global_position)

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color(0.035, 0.09, 0.12, 0.78)
    panel.position = Vector2(14, 14)
    panel.size = Vector2(455, 114)
    layer.add_child(panel)
    hud = Label.new()
    hud.position = Vector2(30, 23)
    hud.add_theme_color_override("font_color", Color("#e3efe9"))
    hud.add_theme_font_size_override("font_size", 21)
    layer.add_child(hud)
    footer = Label.new()
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.position = Vector2(20, -44)
    footer.add_theme_font_size_override("font_size", 16)
    footer.add_theme_color_override("font_color", Color("#c7ddd8"))
    footer.text = "WASD MOVER    SHIFT CORRER    MOUSE MIRAR / ATIRAR    R RECARREGAR"
    layer.add_child(footer)
    reticle = Control.new()
    reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(reticle)
    for direction in [Vector2(-13, 0), Vector2(9, 0), Vector2(0, -13), Vector2(0, 9)]:
        var mark := ColorRect.new()
        mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mark.color = Color("#e9f3e1")
        mark.position = direction
        mark.size = Vector2(4, 4) if direction.x != 0 else Vector2(4, 4)
        reticle.add_child(mark)

func _physics_process(delta: float) -> void:
    if hp <= 0:
        if Input.is_key_pressed(KEY_ENTER):
            get_tree().reload_current_scene()
        _update_hud()
        return
    elapsed += delta
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    damage_cooldown = maxf(0.0, damage_cooldown - delta)
    hit_flash = maxf(0.0, hit_flash - delta)
    recoil = maxf(0.0, recoil - delta * 4.0)
    if reload_timer > 0.0:
        reload_timer -= delta
        if reload_timer <= 0.0:
            _finish_reload()
    _move_player(delta)
    _update_camera(delta)
    _aim_at_mouse()
    _animate_survivor(delta)
    _move_zombies(delta)
    _update_pickups(delta)
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _fire()
    if Input.is_key_pressed(KEY_R):
        _begin_reload()
    _advance_wave(delta)
    reticle.position = get_viewport().get_mouse_position()
    _update_hud()

func _move_player(delta: float) -> void:
    var motion := Vector3.ZERO
    if Input.is_key_pressed(KEY_W):
        motion.z -= 1.0
    if Input.is_key_pressed(KEY_S):
        motion.z += 1.0
    if Input.is_key_pressed(KEY_A):
        motion.x -= 1.0
    if Input.is_key_pressed(KEY_D):
        motion.x += 1.0
    motion = motion.normalized()
    last_move = motion
    var speed := WALK_SPEED
    if Input.is_key_pressed(KEY_SHIFT):
        speed = RUN_SPEED
    var target := motion * speed
    player.velocity.x = move_toward(player.velocity.x, target.x, delta * 28.0)
    player.velocity.z = move_toward(player.velocity.z, target.z, delta * 28.0)
    player.velocity.y -= 24.0 * delta
    player.move_and_slide()

func _update_camera(delta: float) -> void:
    # Camera independente da rotacao do soldado; trava a mesma inclinacao do video.
    var location := player.global_position + CAMERA_OFFSET
    camera.global_position = camera.global_position.lerp(location, minf(1.0, delta * 7.0))
    camera.look_at(player.global_position)

func _aim_at_mouse() -> void:
    var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
    var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
    if absf(direction.y) < 0.00001:
        return
    var distance := (player.global_position.y - origin.y) / direction.y
    if distance <= 0.0:
        return
    var point := origin + direction * distance
    var heading := point - player.global_position
    heading.y = 0
    if heading.length_squared() > 0.02:
        aim_direction = heading.normalized()
        # Rotacao do corpo nao altera WASD.
        player.rotation.y = atan2(aim_direction.x, aim_direction.z)

func _animate_survivor(delta: float) -> void:
    var moving := last_move.length_squared() > 0.01
    if moving:
        walk_cycle += delta * (13.0 if Input.is_key_pressed(KEY_SHIFT) else 9.0)
    var sway := sin(walk_cycle) * (0.45 if moving else 0.0)
    var visual: Node3D = player_rig["visual"]
    var left_leg: Node3D = player_rig["left_leg"]
    var right_leg: Node3D = player_rig["right_leg"]
    var left_arm: Node3D = player_rig["left_arm"]
    var right_arm: Node3D = player_rig["right_arm"]
    visual.position.y = sin(walk_cycle * 2.0) * (0.045 if moving else 0.0)
    left_leg.rotation.x = lerpf(left_leg.rotation.x, sway, minf(1, delta * 11))
    right_leg.rotation.x = lerpf(right_leg.rotation.x, -sway, minf(1, delta * 11))
    left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.23 - recoil, minf(1, delta * 12))
    right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.23 - recoil, minf(1, delta * 12))
    Artwork.animate(player_art, "walk" if moving else "idle", moving and Input.is_key_pressed(KEY_SHIFT))

func _fire() -> void:
    if fire_cooldown > 0 or reload_timer > 0:
        return
    if ammo <= 0:
        _begin_reload()
        return
    fire_cooldown = FIRE_INTERVAL
    ammo -= 1
    recoil = 0.21
    var muzzle: Marker3D = player_rig["muzzle"]
    var start: Vector3 = muzzle.global_position
    var destination := start + aim_direction * 31.0
    var query := PhysicsRayQueryParameters3D.create(start, destination)
    query.exclude = [player.get_rid()]
    var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not result.is_empty():
        destination = result["position"]
        var victim: Object = result["collider"]
        if zombie_state.has(victim):
            _hurt_zombie(victim as CharacterBody3D, 1)
            _impact(destination, Color("#8b3432"), 5)
        elif destructibles.has(victim):
            _hurt_prop(victim as StaticBody3D)
            _impact(destination, Color("#e6b46c"), 4)
        else:
            _impact(destination, Color("#a1ac9c"), 3)
    _tracer(start, destination)
    _muzzle_flash(start)

func _tracer(start: Vector3, destination: Vector3) -> void:
    var distance := start.distance_to(destination)
    if distance < 0.04:
        return
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.018
    cylinder.bottom_radius = 0.018
    cylinder.height = distance
    mesh.mesh = cylinder
    mesh.material_override = Models.material(Color("#eec47a"), 0.0, true)
    mesh.position = (start + destination) * 0.5
    mesh.quaternion = Quaternion(Vector3.UP, (destination - start).normalized())
    add_child(mesh)
    get_tree().create_timer(0.052).timeout.connect(mesh.queue_free)

func _muzzle_flash(where: Vector3) -> void:
    _impact(where, Color("#f8c77d"), 3, 0.13)

func _impact(where: Vector3, tint: Color, amount: int, radius: float = 0.33) -> void:
    for n in range(amount):
        var particle := Models.sphere(self, where, rng.randf_range(0.025, 0.075), tint, true)
        var offset := Vector3(rng.randf_range(-radius, radius), rng.randf_range(0.04, radius), rng.randf_range(-radius, radius))
        var anim := create_tween().set_parallel(true)
        anim.tween_property(particle, "position", particle.position + offset, 0.20)
        anim.tween_property(particle, "scale", Vector3.ZERO, 0.20)
        anim.finished.connect(particle.queue_free)

func _hurt_zombie(zombie: CharacterBody3D, amount: int) -> void:
    if not zombie_state.has(zombie):
        return
    var state: Dictionary = zombie_state[zombie]
    state["health"] = int(state["health"]) - amount
    state["stagger"] = 0.20
    if int(state["health"]) > 0:
        return
    var spot := zombie.global_position
    zombie_state.erase(zombie)
    zombies.erase(zombie)
    zombie.queue_free()
    score += 1
    _impact(spot, Color("#6f302e"), 9, 0.85)
    if score % 5 == 0:
        _drop_pickup(spot, "ammo" if score % 10 != 0 else "medkit")

func _hurt_prop(body: StaticBody3D) -> void:
    if not destructibles.has(body):
        return
    var data: Dictionary = destructibles[body]
    data["health"] = int(data["health"]) - 1
    if int(data["health"]) > 0:
        return
    destructibles.erase(body)
    var pos := body.global_position
    var dims: Vector3 = data["size"]
    var tint: Color = data["tint"]
    body.queue_free()
    for n in range(9):
        var piece := _visual_box(self, pos + Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.2, 0.4), rng.randf_range(-0.15, 0.15)), dims * 0.17, tint.darkened(rng.randf_range(0, 0.2)))
        piece.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
        var drift := Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(0, 0.6), rng.randf_range(-1.3, 1.3))
        var anim := create_tween().set_parallel(true)
        anim.tween_property(piece, "position", piece.position + drift + Vector3(0, -0.5, 0), 0.50)
        anim.tween_property(piece, "scale", Vector3(0.05, 0.05, 0.05), 0.50)
        anim.finished.connect(piece.queue_free)

func _begin_reload() -> void:
    if reload_timer > 0 or ammo >= MAG_SIZE or reserve_ammo <= 0:
        return
    reload_timer = RELOAD_SECONDS

func _finish_reload() -> void:
    var loaded := mini(MAG_SIZE - ammo, reserve_ammo)
    ammo += loaded
    reserve_ammo -= loaded
    reload_timer = 0

func _start_wave() -> void:
    wave += 1
    pending_spawns = mini(5 + wave * 3, MAX_ENEMIES)
    spawn_timer = 0.6
    wave_delay = 0
    # Mostrar o combate ja no primeiro quadro, em vez de iniciar com arena vazia.
    if wave == 1:
        for angle in [0.55, 2.35, 4.65]:
            _spawn_zombie(5.0, float(angle))
            pending_spawns -= 1

func _advance_wave(delta: float) -> void:
    if pending_spawns > 0:
        spawn_timer -= delta
        if spawn_timer <= 0 and zombies.size() < MAX_ENEMIES:
            _spawn_zombie()
            pending_spawns -= 1
            spawn_timer = maxf(0.27, 1.15 - float(wave) * 0.07)
        return
    if zombies.is_empty():
        wave_delay += delta
        if wave_delay >= 3.0:
            _start_wave()
    else:
        wave_delay = 0.0

func _spawn_zombie(distance: float = 15.0, fixed_angle: float = -1.0) -> void:
    if zombies.size() >= MAX_ENEMIES:
        return
    var angle := fixed_angle if fixed_angle >= 0.0 else rng.randf_range(0, TAU)
    var location := player.global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
    location.x = clampf(location.x, -WORLD_LIMIT, WORLD_LIMIT)
    location.z = clampf(location.z, -WORLD_LIMIT, WORLD_LIMIT)
    location.y = 0.88
    var zombie := CharacterBody3D.new()
    zombie.name = "Zombie_%02d" % zombies.size()
    zombie.position = location
    add_child(zombie)
    var variant := rng.randi_range(0, 2)
    var rig: Dictionary = Models.zombie(zombie, variant)
    var art := Artwork.attach_character(zombie, rig, "zombie", variant)
    zombies.append(zombie)
    zombie_state[zombie] = {"health": 2 + mini(wave / 3, 3), "speed": rng.randf_range(1.8, 2.55) + float(wave) * 0.08, "rig": rig, "phase": rng.randf_range(0, TAU), "stagger": 0.0, "art": art}

func _move_zombies(delta: float) -> void:
    for zombie in zombies:
        if not is_instance_valid(zombie) or not zombie_state.has(zombie):
            continue
        var state: Dictionary = zombie_state[zombie]
        var to_player := player.global_position - zombie.global_position
        to_player.y = 0
        var heading := to_player.normalized()
        var stagger := maxf(0.0, float(state["stagger"]) - delta)
        state["stagger"] = stagger
        # Pequeno desvio de colisao para nao acumular todos os zumbis nas cercas.
        if to_player.length() > 1.2:
            var obstacle_ray := PhysicsRayQueryParameters3D.create(zombie.global_position + Vector3(0, 0.12, 0), zombie.global_position + Vector3(0, 0.12, 0) + heading * 1.20)
            obstacle_ray.exclude = [zombie.get_rid(), player.get_rid()]
            var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(obstacle_ray)
            if not collision.is_empty():
                heading = heading.rotated(Vector3.UP, 0.70 if zombie.get_instance_id() % 2 == 0 else -0.70)
        var move_speed := float(state["speed"]) * (0.28 if stagger > 0 else 1.0)
        zombie.velocity.x = heading.x * move_speed
        zombie.velocity.z = heading.z * move_speed
        zombie.velocity.y -= 24.0 * delta
        zombie.move_and_slide()
        if to_player.length_squared() > 0.2:
            zombie.rotation.y = atan2(heading.x, heading.z)
        var rig: Dictionary = state["rig"]
        state["phase"] = float(state["phase"]) + delta * 7.3
        var stride := sin(float(state["phase"])) * 0.32
        var left_leg: Node3D = rig["left_leg"]
        var right_leg: Node3D = rig["right_leg"]
        left_leg.rotation.x = stride
        right_leg.rotation.x = -stride
        Artwork.animate(state.get("art", {}), "walk")
        if zombie.global_position.distance_to(player.global_position) < 1.1 and damage_cooldown <= 0:
            hp = maxi(0, hp - 12)
            damage_cooldown = 0.85
            hit_flash = 0.35

func _drop_pickup(where: Vector3, kind: String) -> void:
    var root := Node3D.new()
    root.position = Vector3(where.x, 0.55, where.z)
    root.set_meta("kind", kind)
    add_child(root)
    Models.box(root, Vector3.ZERO, Vector3(0.46, 0.28, 0.42), Color("#9dbc7b") if kind == "medkit" else Color("#c8ab6b"))
    Models.box(root, Vector3(0, 0.15, 0), Vector3(0.25, 0.06, 0.25), Color("#edf2cf"))
    pickups.append(root)

func _update_pickups(delta: float) -> void:
    for item in pickups.duplicate():
        if not is_instance_valid(item):
            pickups.erase(item)
            continue
        item.rotate_y(delta * 2)
        if item.global_position.distance_to(player.global_position) < 1.30:
            if item.get_meta("kind") == "medkit":
                hp = mini(100, hp + 30)
            else:
                reserve_ammo += 50
            pickups.erase(item)
            item.queue_free()

func _update_hud() -> void:
    if hp <= 0:
        hud.text = "ZOMBIE OUTBREAK\nVOCE MORREU  |  ABATES %d\nPRESSIONE ENTER PARA RECOMECAR" % score
        return
    var reload_label := "  RECARREGANDO..." if reload_timer > 0 else ""
    hud.text = "ZOMBIE OUTBREAK    ONDA %02d\nVIDA  %03d       ARMA  %02d / %03d%s\nABATES  %03d       ZUMBIS  %02d" % [wave, hp, ammo, reserve_ammo, reload_label, score, zombies.size() + pending_spawns]
