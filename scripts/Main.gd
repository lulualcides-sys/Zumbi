extends Node3D
## Prototipo standalone: nenhuma arte externa, API paga ou segredo necessario.

const ARENA_RADIUS := 18.0
const PLAYER_SPEED := 5.5
const SPRINT_MULTIPLIER := 1.5
const FIRE_INTERVAL := 0.13
const MAG_SIZE := 30

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var zombies: Array[CharacterBody3D] = []
var zombie_health: Dictionary = {}
var destructibles: Dictionary = {}
var aim_direction := Vector3.FORWARD
var hp := 100
var ammo := MAG_SIZE
var reserve_ammo := 150
var score := 0
var fire_cooldown := 0.0
var reload_timer := 0.0
var damage_cooldown := 0.0
var spawn_timer := 0.0
var elapsed := 0.0

func _ready() -> void:
    rng.randomize()
    _make_environment()
    _make_level()
    _make_player()
    _make_camera()
    _make_hud()
    for i in range(6):
        _spawn_zombie()
    _refresh_hud()

func _make_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#131e22")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#788b89")
    env.ambient_light_energy = 0.65
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.4
    sun.light_color = Color("#d4e0cf")
    sun.shadow_enabled = true
    add_child(sun)

func _box(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color, solid: bool = false, breakable: bool = false) -> Node3D:
    var mesh_node := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = dimensions
    mesh_node.mesh = cube
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    mesh_node.material_override = material
    mesh_node.position = location
    parent.add_child(mesh_node)
    if not solid:
        return mesh_node
    var physics_body := StaticBody3D.new()
    physics_body.position = location
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = dimensions
    collider.shape = shape
    physics_body.add_child(collider)
    parent.add_child(physics_body)
    if breakable:
        destructibles[physics_body] = {"hp": 3, "mesh": mesh_node, "size": dimensions, "color": color}
    return physics_body

func _make_level() -> void:
    _box(self, Vector3(0, -0.35, 0), Vector3(40, 0.7, 40), Color("#273638"), true)
    # Ruas e linhas de asfalto, apenas geometria original.
    _box(self, Vector3(0, 0.015, 0), Vector3(8, 0.03, 40), Color("#344446"))
    _box(self, Vector3(0, 0.02, 0), Vector3(40, 0.03, 8), Color("#344446"))
    for i in range(-3, 4):
        _box(self, Vector3(0, 0.045, float(i) * 5.2), Vector3(0.12, 0.025, 1.8), Color("#c6ad6b"))
    for i in range(7):
        var a := -15.0 + float(i) * 5.0
        _box(self, Vector3(-19.0, 1.2, a), Vector3(0.7, 2.4, 4.7), Color("#4e5d5d"), true)
        _box(self, Vector3(19.0, 1.2, a), Vector3(0.7, 2.4, 4.7), Color("#4e5d5d"), true)
    _box(self, Vector3(0, 1.0, -19.0), Vector3(39, 2, 0.7), Color("#45575a"), true)
    _box(self, Vector3(0, 1.0, 19.0), Vector3(39, 2, 0.7), Color("#45575a"), true)
    for i in range(12):
        var location := Vector3(rng.randf_range(-15, 15), 0.52, rng.randf_range(-15, 15))
        if location.length() < 4.0:
            continue
        _box(self, location, Vector3(1.2, 1.0, 1.1), Color("#826b4e"), true, true)
    for i in range(5):
        var location := Vector3(rng.randf_range(-13, 13), 0.42, rng.randf_range(-13, 13))
        if location.length() < 5.0:
            continue
        _box(self, location, Vector3(2.7, 0.82, 1.2), Color("#54696d"), true, true)

func _actor_mesh(body: CharacterBody3D, color: Color, radius: float) -> void:
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = radius
    capsule.height = 1.5
    collider.shape = capsule
    body.add_child(collider)
    var visible_mesh := MeshInstance3D.new()
    var shape_mesh := CapsuleMesh.new()
    shape_mesh.radius = radius
    shape_mesh.height = 1.45
    visible_mesh.mesh = shape_mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.95
    visible_mesh.material_override = mat
    body.add_child(visible_mesh)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Survivor"
    player.position = Vector3(0, 1.0, 0)
    add_child(player)
    _actor_mesh(player, Color("#b7c6a5"), 0.35)
    _box(player, Vector3(0.23, 0.12, 0.48), Vector3(0.17, 0.17, 0.85), Color("#293439"))

func _make_camera() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 52.0
    add_child(camera)
    camera.global_position = player.global_position + Vector3(0, 16, 15)
    camera.look_at(player.global_position)

func _make_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(24, 20)
    hud.add_theme_color_override("font_color", Color("#ebf3e7"))
    hud.add_theme_font_size_override("font_size", 22)
    layer.add_child(hud)

func _physics_process(delta: float) -> void:
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    reload_timer = maxf(0.0, reload_timer - delta)
    damage_cooldown = maxf(0.0, damage_cooldown - delta)
    if hp <= 0:
        if Input.is_key_pressed(KEY_ENTER):
            get_tree().reload_current_scene()
        return
    elapsed += delta
    _move_player(delta)
    _aim_at_mouse()
    _move_zombies(delta)
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _fire()
    if Input.is_key_pressed(KEY_R):
        _begin_reload()
    spawn_timer -= delta
    if spawn_timer <= 0.0:
        spawn_timer = maxf(1.6, 4.7 - elapsed / 75.0)
        _spawn_zombie()
    var camera_target := player.global_position + Vector3(0, 16, 15)
    camera.global_position = camera.global_position.lerp(camera_target, minf(1.0, delta * 6.0))
    camera.look_at(player.global_position)
    _refresh_hud()

func _move_player(delta: float) -> void:
    var movement := Vector3.ZERO
    if Input.is_key_pressed(KEY_W):
        movement.z -= 1.0
    if Input.is_key_pressed(KEY_S):
        movement.z += 1.0
    if Input.is_key_pressed(KEY_A):
        movement.x -= 1.0
    if Input.is_key_pressed(KEY_D):
        movement.x += 1.0
    movement = movement.normalized()
    var speed := PLAYER_SPEED
    if Input.is_key_pressed(KEY_SHIFT):
        speed *= SPRINT_MULTIPLIER
    player.velocity.x = movement.x * speed
    player.velocity.z = movement.z * speed
    player.velocity.y -= 24.0 * delta
    player.move_and_slide()

func _aim_at_mouse() -> void:
    var mouse := get_viewport().get_mouse_position()
    var origin := camera.project_ray_origin(mouse)
    var direction := camera.project_ray_normal(mouse)
    if absf(direction.y) <= 0.0001:
        return
    var t := (player.global_position.y - origin.y) / direction.y
    if t <= 0.0:
        return
    var hit_point := origin + direction * t
    var horizontal := hit_point - player.global_position
    horizontal.y = 0.0
    if horizontal.length_squared() <= 0.01:
        return
    aim_direction = horizontal.normalized()
    player.rotation.y = atan2(aim_direction.x, aim_direction.z)

func _fire() -> void:
    if fire_cooldown > 0.0 or reload_timer > 0.0 or ammo <= 0:
        return
    fire_cooldown = FIRE_INTERVAL
    ammo -= 1
    var start := player.global_position + Vector3(0, 0.28, 0) + aim_direction * 0.65
    var target := start + aim_direction * 28.0
    var query := PhysicsRayQueryParameters3D.create(start, target)
    query.exclude = [player.get_rid()]
    var result := get_world_3d().direct_space_state.intersect_ray(query)
    if not result.is_empty():
        target = result["position"]
        var victim = result["collider"]
        if zombie_health.has(victim):
            zombie_health[victim] -= 1
            if zombie_health[victim] <= 0:
                zombie_health.erase(victim)
                zombies.erase(victim)
                victim.queue_free()
                score += 1
        elif destructibles.has(victim):
            destructibles[victim]["hp"] -= 1
            if destructibles[victim]["hp"] <= 0:
                _break_prop(victim)
    _tracer(start, target)

func _tracer(start: Vector3, end: Vector3) -> void:
    var distance := start.distance_to(end)
    if distance < 0.03:
        return
    var beam := MeshInstance3D.new()
    var tube := CylinderMesh.new()
    tube.top_radius = 0.025
    tube.bottom_radius = 0.025
    tube.height = distance
    beam.mesh = tube
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color("#ffc56e")
    beam.material_override = mat
    beam.position = (start + end) * 0.5
    beam.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
    add_child(beam)
    get_tree().create_timer(0.075).timeout.connect(beam.queue_free)

func _break_prop(body: StaticBody3D) -> void:
    var info: Dictionary = destructibles[body]
    destructibles.erase(body)
    var old_mesh: MeshInstance3D = info["mesh"]
    var at: Vector3 = body.global_position
    var original_size: Vector3 = info["size"]
    var tint: Color = info["color"]
    old_mesh.queue_free()
    body.queue_free()
    for i in range(6):
        var fragment := _box(self, at + Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.4, 0.4)), original_size * 0.25, tint)
        var drift := Vector3(rng.randf_range(-1.1, 1.1), -0.2, rng.randf_range(-1.1, 1.1))
        var animation := create_tween()
        animation.tween_property(fragment, "position", fragment.position + drift, 0.35)
        animation.tween_callback(fragment.queue_free)

func _spawn_zombie() -> void:
    if zombies.size() >= 35:
        return
    var angle := rng.randf_range(0, TAU)
    var spawn_at := Vector3(cos(angle) * rng.randf_range(11, 16), 1.0, sin(angle) * rng.randf_range(11, 16))
    var zombie := CharacterBody3D.new()
    zombie.name = "Zombie"
    zombie.position = spawn_at
    add_child(zombie)
    _actor_mesh(zombie, Color("#6e9371"), 0.4)
    _box(zombie, Vector3(0, 0.6, 0), Vector3(0.6, 0.2, 0.4), Color("#394b3a"))
    zombies.append(zombie)
    zombie_health[zombie] = 3

func _move_zombies(delta: float) -> void:
    var near_player := false
    for zombie in zombies:
        if not is_instance_valid(zombie):
            continue
        var direction := player.global_position - zombie.global_position
        direction.y = 0
        if direction.length_squared() > 0.03:
            var chase := direction.normalized()
            zombie.velocity.x = chase.x * 2.2
            zombie.velocity.z = chase.z * 2.2
            zombie.rotation.y = atan2(chase.x, chase.z)
        zombie.velocity.y -= 24.0 * delta
        zombie.move_and_slide()
        if zombie.global_position.distance_to(player.global_position) < 1.25:
            near_player = true
    if near_player and damage_cooldown <= 0.0:
        hp = maxi(0, hp - 9)
        damage_cooldown = 0.8

func _begin_reload() -> void:
    if reload_timer > 0.0 or ammo >= MAG_SIZE or reserve_ammo <= 0:
        return
    reload_timer = 1.25
    var needed := mini(MAG_SIZE - ammo, reserve_ammo)
    ammo += needed
    reserve_ammo -= needed

func _refresh_hud() -> void:
    if hp <= 0:
        hud.text = "VOCE MORREU    |    Abates: %d    |    ENTER para reiniciar" % score
        return
    hud.text = "ZOMBIE OUTBREAK  |  VIDA %d  |  AS VAL %d / %d  |  ABATES %d  |  ZUMBIS %d\nWASD mover  |  SHIFT correr  |  MOUSE mirar/atirar  |  R recarregar" % [hp, ammo, reserve_ammo, score, zombies.size()]
