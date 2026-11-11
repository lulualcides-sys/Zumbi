extends Node3D
## Zombie Outbreak v0.2: movimento independente da mira, camera 3/4 e objetos quebraveis.
## Modelos e decoracoes sao primitivos originais; nenhum download externo em runtime.

const Models = preload("res://scripts/ActorFactory.gd")
const Artwork = preload("res://scripts/VisualAssets.gd")
const StreetSurface = preload("res://scripts/SurfaceTextures.gd")
const MobileJoystick = preload("res://scripts/MobileControls.gd")
const WeaponVisual = preload("res://scripts/WeaponVisual.gd")
const WALK_SPEED := 5.2
const RUN_SPEED := 8.0
const FIRE_INTERVAL := 0.12
const RELOAD_SECONDS := 1.45
const MAG_SIZE := 32
const MAX_ENEMIES := 14
const WORLD_LIMIT := 17.0
const MOBILE_AUTO_RANGE := 14.0
const CAMERA_OFFSET := Vector3(0.0, 20.5, 5.0)
const CAMERA_LOOK_AHEAD := Vector3(0.0, 0.0, -1.20)

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var footer: Label
var reticle: Control
var mobile_controls: Control
var player_rig: Dictionary = {}
var player_art: Dictionary = {}
var weapon_rig: Dictionary = {}
var zombie_state: Dictionary = {}
var zombies: Array[CharacterBody3D] = []
var destructibles: Dictionary = {}
var pickups: Array[Node3D] = []
var aim_direction := Vector3.FORWARD
var has_player_aim_input := false
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
    _refresh_control_labels()

func _environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#101c26")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#8798a4")
    env.ambient_light_energy = 0.48
    world.environment = env
    add_child(world)
    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-73, -31, 0)
    moon.light_color = Color("#d5e7ee")
    moon.light_energy = 1.08
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
    # Narrow, peaked wood slats like the destructible fence in the reference.
    # A single collider remains intentional so the existing damage system works.
    var body := StaticBody3D.new()
    body.position = at
    add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.88, 1.15, 0.20)
    collider.shape = shape
    body.add_child(collider)
    var wood := Color("#6d5946")
    for n in range(9):
        var x := -0.84 + float(n) * 0.21
        var tint := wood.lightened(0.03 * float(n % 3))
        var slat := _visual_box(body, Vector3(x, -0.02, 0.0), Vector3(0.145, 0.91, 0.105), tint)
        slat.rotation.z = rng.randf_range(-0.011, 0.011)
        var peak := MeshInstance3D.new()
        var cone := CylinderMesh.new()
        cone.top_radius = 0.0
        cone.bottom_radius = 0.088
        cone.height = 0.16
        cone.radial_segments = 4
        peak.mesh = cone
        peak.material_override = Models.material(tint)
        peak.position = Vector3(x, 0.50, 0.0)
        body.add_child(peak)
    for z in [-0.19]:
        _visual_box(body, Vector3(0, 0.29, float(z)), Vector3(1.9, 0.10, 0.14), Color("#513b30"))
        _visual_box(body, Vector3(0, -0.29, float(z)), Vector3(1.9, 0.10, 0.14), Color("#513b30"))
    destructibles[body] = {"health": 4, "size": Vector3(1.88, 1.15, 0.20), "tint": wood}

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
    # Reference-first staging yard: dark desaturated blue, faint grid,
    # sparse obstacles. Remove the neon road paint and blue cartoon barrels.
    var ground := _solid_box(Vector3(0, -0.36, 0), Vector3(40, 0.72, 40), Color("#1a2d3b"))
    var ground_visual: MeshInstance3D = ground.get_child(1) as MeshInstance3D
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color("#182b39")
    ground_mat.roughness = 0.94
    ground_visual.material_override = ground_mat

    # Fine matte grid, close to the test arena in the supplied footage.
    # These lines have no collider and cannot block the player or bullets.
    for i in range(-10, 11):
        var x := float(i) * 2.0
        _visual_box(self, Vector3(x, 0.018, 0.0), Vector3(0.011, 0.009, 39.0), Color("#22394a"))
        _visual_box(self, Vector3(0.0, 0.019, x), Vector3(39.0, 0.009, 0.011), Color("#22394a"))

    # One readable destructible wooden fence is enough for the initial view.
    for i in range(4):
        _fence_segment(Vector3(-3.00 + float(i) * 1.90, 0.60, -3.15))
    # Secondary props occupy the far edges so the character remains focal.
    _solid_box(Vector3(-10.8, 0.56, -9.0), Vector3(2.3, 1.12, 1.4), Color("#51616a"), 6)
    _solid_box(Vector3(10.2, 0.45, 7.6), Vector3(1.0, 0.90, 1.1), Color("#4d5a5a"), 4)
    Artwork.add_prop(self, "container_green.gltf", Vector3(-12.2, 0.0, 12.2), 0.85, 0.0)
    Artwork.add_prop(self, "pallet.gltf", Vector3(-6.4, 0.01, 6.4), 0.90, 0.36)
    Artwork.add_prop(self, "traffic_barrier.gltf", Vector3(9.3, 0.0, -11.1), 0.95, 0.0)

    # Simple low-contrast perimeter walls. No bright streetlight poles.
    for x in [-19.4, 19.4]:
        _solid_box(Vector3(float(x), 0.90, 0), Vector3(0.45, 1.8, 39.0), Color("#354955"))
    for z in [-19.4, 19.4]:
        _solid_box(Vector3(0, 0.90, float(z)), Vector3(39.0, 1.8, 0.45), Color("#354955"))

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Survivor"
    player.position = Vector3(0, 0.88, 0)
    # Reference opens with the rifle pointing at the fence, not downscreen.
    player.rotation.y = PI
    add_child(player)
    player_rig = Models.survivor(player)
    player_art = Artwork.attach_character(player, player_rig, "survivor")
    # Imported survivor does not include its own rifle: attach the CC0 model.
    weapon_rig = WeaponVisual.attach(player, player_art)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.name = "ThreeQuarterCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 8.8
    camera.near = 0.1
    camera.far = 110.0
    camera.current = true
    add_child(camera)
    camera.global_position = player.global_position + CAMERA_OFFSET + CAMERA_LOOK_AHEAD
    camera.look_at(player.global_position + CAMERA_LOOK_AHEAD)

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color(0.035, 0.09, 0.12, 0.38)
    panel.position = Vector2(14, 14)
    panel.size = Vector2(280, 91)
    layer.add_child(panel)
    hud = Label.new()
    hud.position = Vector2(30, 23)
    hud.add_theme_color_override("font_color", Color("#e3efe9"))
    hud.add_theme_font_size_override("font_size", 15)
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
    var joystick_layer := CanvasLayer.new()
    joystick_layer.layer = 10
    add_child(joystick_layer)
    mobile_controls = MobileJoystick.new()
    mobile_controls.name = "MovementJoystick"
    joystick_layer.add_child(mobile_controls)
    mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _refresh_control_labels()

func _mobile_enabled() -> bool:
    return mobile_controls != null and bool(mobile_controls.get("active"))

func _refresh_control_labels() -> void:
    if footer == null or reticle == null:
        return
    if _mobile_enabled():
        footer.text = "ARRASTE O JOYSTICK PARA MOVER  |  TIRO E RECARGA AUTOMATICOS"
        reticle.visible = false
    else:
        footer.text = "WASD MOVER    SHIFT CORRER    MOUSE MIRAR / ATIRAR    R RECARREGAR"
        reticle.visible = true

func _input(event: InputEvent) -> void:
    if (event is InputEventMouseMotion or event is InputEventMouseButton) and not _mobile_enabled():
        has_player_aim_input = true
    if hp <= 0 and _mobile_enabled() and event is InputEventScreenTouch and event.pressed:
        get_tree().reload_current_scene()

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
    if not _mobile_enabled() and has_player_aim_input:
        _aim_at_mouse()
    _animate_survivor(delta)
    _move_zombies(delta)
    _update_pickups(delta)
    if _mobile_enabled():
        _mobile_auto_combat()
    else:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _fire()
        if Input.is_key_pressed(KEY_R):
            _begin_reload()
    _advance_wave(delta)
    if _mobile_enabled():
        reticle.visible = false
    else:
        reticle.visible = true
        reticle.position = get_viewport().get_mouse_position()
    _refresh_control_labels()
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
    if _mobile_enabled():
        var analog: Vector2 = mobile_controls.get("direction")
        # Landscape joystick is camera-relative; "up" means up on screen
        # even when the camera moves to the diagonal view of the video.
        var screen_right := camera.global_transform.basis.x
        var screen_up := -camera.global_transform.basis.z
        screen_right.y = 0.0
        screen_up.y = 0.0
        screen_right = screen_right.normalized()
        screen_up = screen_up.normalized()
        motion = (screen_right * analog.x - screen_up * analog.y).limit_length(1.0)
    else:
        motion = motion.normalized()
    last_move = motion
    var speed := WALK_SPEED
    if (_mobile_enabled() and motion.length() > 0.82) or (not _mobile_enabled() and Input.is_key_pressed(KEY_SHIFT)):
        speed = RUN_SPEED
    var target := motion * speed
    player.velocity.x = move_toward(player.velocity.x, target.x, delta * 28.0)
    player.velocity.z = move_toward(player.velocity.z, target.z, delta * 28.0)
    player.velocity.y -= 24.0 * delta
    player.move_and_slide()

func _update_camera(delta: float) -> void:
    # Camera independente da rotacao do soldado; trava a mesma inclinacao do video.
    var location := player.global_position + CAMERA_OFFSET + CAMERA_LOOK_AHEAD
    camera.global_position = camera.global_position.lerp(location, minf(1.0, delta * 7.0))
    camera.look_at(player.global_position + CAMERA_LOOK_AHEAD)

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

func _nearest_visible_zombie() -> CharacterBody3D:
    var nearest: CharacterBody3D = null
    var best_distance_sq := MOBILE_AUTO_RANGE * MOBILE_AUTO_RANGE
    for zombie in zombies:
        if not is_instance_valid(zombie) or not zombie_state.has(zombie):
            continue
        var delta := zombie.global_position - player.global_position
        delta.y = 0.0
        var distance_sq := delta.length_squared()
        if distance_sq < 0.09 or distance_sq >= best_distance_sq:
            continue
        # Muralhas e cercas impedem selecionar inimigos invisiveis.
        var start := player.global_position + Vector3(0.0, 0.16, 0.0)
        var target := zombie.global_position + Vector3(0.0, 0.16, 0.0)
        var ray := PhysicsRayQueryParameters3D.create(start, target)
        ray.exclude = [player.get_rid()]
        var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.get("collider") != zombie:
            continue
        nearest = zombie
        best_distance_sq = distance_sq
    return nearest

func _mobile_auto_combat() -> void:
    if ammo <= 0 and reserve_ammo > 0:
        _begin_reload()
        return
    var target := _nearest_visible_zombie()
    if target == null:
        return
    var vector := target.global_position - player.global_position
    vector.y = 0.0
    if vector.length_squared() < 0.0001:
        return
    aim_direction = vector.normalized()
    player.rotation.y = atan2(aim_direction.x, aim_direction.z)
    if fire_cooldown <= 0.0 and reload_timer <= 0.0:
        _fire()

func _animate_survivor(delta: float) -> void:
    var moving := last_move.length_squared() > 0.01
    var running := (_mobile_enabled() and last_move.length() > 0.82) or (not _mobile_enabled() and Input.is_key_pressed(KEY_SHIFT))
    if moving:
        walk_cycle += delta * (13.0 if running else 9.0)
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
    Artwork.animate(player_art, "walk" if moving else "idle", moving and running)
    WeaponVisual.align_to_hands(weapon_rig, player, delta)

func _fire() -> void:
    if fire_cooldown > 0 or reload_timer > 0:
        return
    if ammo <= 0:
        _begin_reload()
        return
    fire_cooldown = FIRE_INTERVAL
    ammo -= 1
    recoil = 0.21
    # The actual, visible rifle is the source of all gunfire; never shoot
    # from the invisible placeholder rifle in the procedural fallback.
    var muzzle: Marker3D = weapon_rig["muzzle"]
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
    WeaponVisual.animate_fire(weapon_rig)
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
        if zombie.global_position.distance_to(player.global_position) < 1.55:
            Artwork.animate(state.get("art", {}), "attack")
        else:
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
        hud.text = ("ZOMBIE OUTBREAK\nVOCE MORREU  |  ABATES %d\nTOQUE PARA REINICIAR" if _mobile_enabled() else "ZOMBIE OUTBREAK\nVOCE MORREU  |  ABATES %d\nPRESSIONE ENTER PARA RECOMECAR") % score
        return
    var reload_label := "  RECARREGANDO..." if reload_timer > 0 else ""
    hud.text = "ZOMBIE OUTBREAK    ONDA %02d\nVIDA  %03d       ARMA  %02d / %03d%s\nABATES  %03d       ZUMBIS  %02d" % [wave, hp, ammo, reserve_ammo, reload_label, score, zombies.size() + pending_spawns]
