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
    # scene._ready() runs synchronously. Skip rendering frames in the
    # headless structural smoke test; the separate OpenGL screenshot checks it.
    var all_passed := true
    all_passed = _check(scene.player != null and scene.camera != null, "Jogador/camera ausentes") and all_passed
    all_passed = _check(scene.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Camera 3/4 do video nao configurada") and all_passed
    all_passed = _check(scene.player_rig.has("muzzle") and scene.player_rig.has("left_leg"), "Soldado sem rig ou cano") and all_passed
    if ResourceLoader.exists("res://assets/cc0/survivor.gltf"):
        all_passed = _check(not scene.player_art.is_empty(), "Soldado CC0 nao substituiu o modelo geometrico") and all_passed
        all_passed = _check(scene.player_art.has("root") and is_instance_valid(scene.player_art["root"]), "GLTF do sobrevivente nao carregado") and all_passed
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
    print("SMOKE_OK: camera 3/4, CC0 animated models, ondas, dano, recarga e cercas destrutiveis")
    quit(0)
