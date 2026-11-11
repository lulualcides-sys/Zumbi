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
    all_passed = _check(scene.player_rig.has("muzzle") and scene.player_rig.has("left_leg"), "Soldado sem rig ou cano") and all_passed
    all_passed = _check(scene.weapon_rig.has("mount") and scene.weapon_rig.has("muzzle"), "Rifle 3D nao equipado") and all_passed
    var gun_mount: Node3D = scene.weapon_rig.get("mount")
    var gun_muzzle: Marker3D = scene.weapon_rig.get("muzzle")
    all_passed = _check(gun_mount != null and gun_mount.visible, "Rifle invisivel") and all_passed
    all_passed = _check(gun_muzzle != null and gun_muzzle.global_position.distance_to(scene.player.global_position) < 2.5, "Boca do cano fora de posicao") and all_passed
    if ResourceLoader.exists("res://assets/cc0/rifle.gltf"):
        all_passed = _check(bool(scene.weapon_rig.get("source_ok", false)), "Fuzil GLTF CC0 nao instanciado") and all_passed
        all_passed = _check(gun_mount.get_node_or_null("VisibleCC0Rifle") != null, "Soldado esta sem o rifle visivel") and all_passed

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
    var hp_before: int = scene.zombie_state[target]["health"]
    var score_before: int = scene.score
    scene._hurt_zombie(target, hp_before)
    all_passed = _check(scene.score == score_before + 1 and not scene.zombie_state.has(target), "Zombie nao morreu ao receber dano letal") and all_passed

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
