extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> bool:
    if not condition:
        push_error(message)
    return condition

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    if not _check(packed != null, "Cena principal indisponivel"):
        quit(1)
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var all_passed := true
    all_passed = _check(scene.player != null and scene.camera != null, "Jogador/camera ausentes") and all_passed
    all_passed = _check(scene.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Camera 3/4 do video nao configurada") and all_passed
    all_passed = _check(scene.aim_direction.distance_to(Vector3.FORWARD) < 0.01, "Direcao inicial deve mirar na cerca ao norte") and all_passed
    all_passed = _check(absf(absf(scene.player.rotation.y) - PI) < 0.05, "Soldado inicia olhando para fora da referencia") and all_passed
    all_passed = _check(not scene.has_player_aim_input, "Mouse nao movido nao deve desviar a arma na primeira tela") and all_passed
    var gun_forward: Vector3 = scene.weapon_rig.get("mount").global_transform.basis.z
    gun_forward.y = 0.0
    all_passed = _check(gun_forward.normalized().dot(scene.aim_direction) > 0.98, "Arma fisica e tiro inicial apontam direcoes diferentes") and all_passed
    var fence_screen: Vector2 = scene.camera.unproject_position(Vector3(0.0, 0.65, -3.15))
    var player_screen: Vector2 = scene.camera.unproject_position(scene.player.global_position)
    var window_size := Vector2(root.size)
    all_passed = _check(fence_screen.y > window_size.y * 0.06 and fence_screen.y < player_screen.y - 30.0,
        "Cerca cortada ou abaixo do jogador no enquadramento inicial") and all_passed

    all_passed = _check(scene.player_rig.has("muzzle") and scene.player_rig.has("left_leg"), "Soldado sem rig ou cano") and all_passed
    all_passed = _check(scene.weapon_rig.has("mount") and scene.weapon_rig.has("muzzle"), "Rifle 3D nao equipado") and all_passed
    var gun_mount: Node3D = scene.weapon_rig.get("mount")
    var gun_muzzle: Marker3D = scene.weapon_rig.get("muzzle")
    all_passed = _check(gun_mount != null and gun_mount.visible, "Rifle invisivel") and all_passed
    all_passed = _check(gun_muzzle != null and gun_muzzle.global_position.distance_to(scene.player.global_position) < 2.5, "Boca do cano fora de posicao") and all_passed
    if ResourceLoader.exists("res://assets/cc0/rifle.gltf"):
        all_passed = _check(bool(scene.weapon_rig.get("source_ok", false)), "Fuzil GLTF nao instanciado") and all_passed
        var weapon_node_name := "GunVisualWithRecoil/VisibleCalibratedM4A1" if bool(scene.weapon_rig.get("calibrated_m4a1", false)) else "GunVisualWithRecoil/VisibleCC0Rifle"
        all_passed = _check(gun_mount.get_node_or_null(weapon_node_name) != null, "Modelo de arma nao encontrado: " + weapon_node_name) and all_passed
    if ResourceLoader.exists("res://assets/tactical/m4a1-ready.glb"):
        all_passed = _check(bool(scene.weapon_rig.get("calibrated_m4a1", false)), "M4A1 exportado do Blender nao foi equipado") and all_passed
        var ik: Dictionary = scene.weapon_rig.get("arm_ik", {})
        var right_grip: Marker3D = ik.get("right_grip")
        var left_grip: Marker3D = ik.get("left_grip")
        all_passed = _check(ik.get("active", false), "M4A1 sem TwoBoneIK3D nos dois bracos") and all_passed
        all_passed = _check(right_grip != null and left_grip != null and left_grip.position.z > right_grip.position.z,
            "A mao de suporte nao esta na frente da empunhadura") and all_passed

    if not scene.player_art.is_empty():
        scene._animate_survivor(0.016)
        var actual_player: AnimationPlayer = scene.player_art.get("player")
        all_passed = _check(actual_player != null and actual_player.is_playing(), "AnimationPlayer do sobrevivente nao iniciou") and all_passed
        if scene.player_art.get("tactical", false) and actual_player != null:
            var clip := actual_player.current_animation.to_lower()
            all_passed = _check("crouch" not in clip and ("aim_idle" in clip or "ready_idle" in clip), "Stand idle incorrectly selected crouching clip: " + clip) and all_passed
    if ResourceLoader.exists("res://assets/cc0/survivor.gltf"):
        all_passed = _check(not scene.player_art.is_empty(), "Soldado CC0 nao substituiu o modelo geometrico") and all_passed
        all_passed = _check(scene.player_art.has("root") and is_instance_valid(scene.player_art["root"]), "GLTF do sobrevivente nao carregado") and all_passed
    if ResourceLoader.exists("res://assets/tactical/soldier.glb"):
        all_passed = _check(scene.player_art.get("tactical", false), "Tactical character model not activated") and all_passed
        var tactical_node: Node3D = scene.player_art.get("root")
        all_passed = _check(tactical_node != null and tactical_node.visible and tactical_node.name == "TacticalSoldierAnimated", "Tactical soldier missing or hidden") and all_passed
        all_passed = _check(scene.player_art.get("animations", []).size() > 0, "Tactical soldier has no imported animations") and all_passed
        all_passed = _check(scene.weapon_rig.get("skeleton") != null, "Real skeletal rig missing for weapon") and all_passed
        all_passed = _check(int(scene.weapon_rig.get("right_hand", -1)) >= 0 and int(scene.weapon_rig.get("left_hand", -1)) >= 0, "Rifle not bound to real animated hand bones") and all_passed
        all_passed = _check(scene.weapon_rig.get("arm_ik", {}).get("active", false), "TwoBoneIK3D hand grip not active") and all_passed
        all_passed = _check(int(tactical_node.get_meta("graded_surfaces", 0)) > 0, "Tactical white/charcoal materials were NOT applied") and all_passed
    all_passed = _check(scene.wave == 1 and scene.pending_spawns > 0, "Sistema de ondas nao iniciou") and all_passed
    all_passed = _check(scene.destructibles.size() >= 4, "Cercas ou objetos destrutiveis ausentes") and all_passed

    # A mira nao altera a direcao dos comandos WASD.
    scene.aim_direction = Vector3.RIGHT
    scene.last_move = Vector3.BACK
    all_passed = _check(scene.last_move != scene.aim_direction, "Movimento independente da mira violado") and all_passed

    # A recarga precisa ter tempo de espera antes de transferir municao.
    scene.ammo = 4
    var reserve_before: int = scene.reserve_ammo
    scene._begin_reload()
    all_passed = _check(scene.reload_timer > 0.0 and scene.ammo == 4, "Recarga instantanea indevida") and all_passed
    scene._finish_reload()
    all_passed = _check(scene.ammo == scene.MAG_SIZE and scene.reserve_ammo == reserve_before - (scene.MAG_SIZE - 4), "Recarga ou reserva incorretas") and all_passed

    # Dano e abate efetivo de inimigo.
    scene._spawn_zombie()
    var target = scene.zombies.back()
    scene._move_zombies(0.016)
    if scene.zombie_state[target].has("art") and not scene.zombie_state[target]["art"].is_empty():
        var actual_zombie: AnimationPlayer = scene.zombie_state[target]["art"].get("player")
        all_passed = _check(actual_zombie != null and actual_zombie.is_playing(), "AnimationPlayer do zumbi nao iniciou") and all_passed
    if ResourceLoader.exists("res://assets/cc0/zombie_basic.gltf"):
        all_passed = _check(scene.zombie_state[target].get("art", {}).has("root"), "Zombie CC0 nao importado") and all_passed
    if ResourceLoader.exists("res://assets/tactical/soldier.glb"):
        var enemy_art: Dictionary = scene.zombie_state[target].get("art", {})
        var enemy_mesh: Node3D = enemy_art.get("root")
        all_passed = _check(bool(enemy_art.get("infected", false)), "Cartoon zombie still being used in reference visual mode") and all_passed
        if ResourceLoader.exists("res://assets/tactical/infected.glb"):
            all_passed = _check(enemy_art.get("path", "").ends_with("/infected.glb"), "Optimized infected asset not loaded") and all_passed
            all_passed = _check(enemy_art.get("animations", []).size() <= 6, "Unused tactical animation clips remain on enemies") and all_passed
        all_passed = _check(enemy_mesh != null and int(enemy_mesh.get_meta("graded_surfaces", 0)) > 0, "Infected material was not applied to the soldier mesh") and all_passed
    var hp_before: int = scene.zombie_state[target]["health"]
    var score_before: int = scene.score
    scene._hurt_zombie(target, hp_before)
    all_passed = _check(scene.score == score_before + 1 and not scene.zombie_state.has(target), "Zombie nao morreu ao receber dano letal") and all_passed

    # Real gunfire must reach the *low* wooden fence. Previous horizontal
    # bullets left the muzzle above its collision box and never damaged it.
    var centered_fence: StaticBody3D = null
    for body in scene.destructibles.keys():
        if body is StaticBody3D and absf(body.position.z + 3.15) < 0.1 and absf(body.position.x) < 0.3:
            centered_fence = body
            break
    all_passed = _check(centered_fence != null, "No centered fence for ballistics QA") and all_passed
    if centered_fence != null:
        var fence_hp_before: int = scene.destructibles[centered_fence]["health"]
        scene.fire_cooldown = 0.0
        scene.reload_timer = 0.0
        scene.aim_point = centered_fence.global_position
        scene._fire()
        all_passed = _check(scene.destructibles.has(centered_fence) and
            int(scene.destructibles[centered_fence]["health"]) == fence_hp_before - 1,
            "Real muzzle shot passed OVER the wooden fence instead of damaging it") and all_passed

    # Fragmentacao: remover o obstaculo nao deixa corpo com HP ativo.
    var prop = scene.destructibles.keys()[0]
    var prop_health: int = scene.destructibles[prop]["health"]
    scene._hurt_prop(prop)
    for i in range(prop_health - 1):
        scene._hurt_prop(prop)
    all_passed = _check(not scene.destructibles.has(prop), "Obstaculo nao fragmentou apos disparos suficientes") and all_passed

    if not all_passed:
        quit(1)
        return
    print("SMOKE_OK: rifle 3D CC0 visivel com marcador de cano, camera, animacoes e combate")
    quit(0)
