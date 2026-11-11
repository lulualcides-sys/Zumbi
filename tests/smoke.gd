extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene_resource := load("res://scenes/Main.tscn") as PackedScene
    if scene_resource == null:
        push_error("Main.tscn indisponivel")
        quit(1)
        return
    var scene := scene_resource.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    if not scene.has_method("_spawn_zombie") or not scene.has_method("_fire"):
        push_error("Mecanicas esperadas ausentes")
        quit(1)
        return
    if scene.zombies.size() < 1 or scene.player == null or scene.camera == null:
        push_error("Cena nao inicializou jogador, camera e zumbis")
        quit(1)
        return
    print("SMOKE_OK: cena, jogador, camera, inimigos e mecanica de tiros carregados")
    quit(0)
