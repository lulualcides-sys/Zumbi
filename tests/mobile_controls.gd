extends SceneTree
## Verifica toque, joystick analogico, mira/tiro e recarga automatica.

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, msg: String) -> bool:
    if not condition:
        push_error("MOBILE_TEST_FAILED: " + msg)
    return condition

func _run() -> void:
    var ok := true
    var game := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await physics_frame

    var touch_ui: Control = game.mobile_controls
    ok = _assert(touch_ui != null and touch_ui.size.x > 0, "mobile UI not anchored") and ok
    var press := InputEventScreenTouch.new()
    press.index = 3
    press.pressed = true
    press.position = Vector2(180, 540)
    touch_ui._input(press)
    ok = _assert(game._mobile_enabled(), "first touch did not activate mobile mode") and ok
    var drag := InputEventScreenDrag.new()
    drag.index = 3
    drag.position = Vector2(250, 515)
    touch_ui._input(drag)
    var analog: Vector2 = touch_ui.get("direction")
    ok = _assert(analog.x > 0.5 and analog.y < 0.0 and analog.length() <= 1.0, "analog movement direction invalid") and ok
    game._move_player(0.016)
    var right := game.camera.global_transform.basis.x
    var forward := -game.camera.global_transform.basis.z
    right.y = 0.0
    forward.y = 0.0
    var expected := (right.normalized() * analog.x - forward.normalized() * analog.y).normalized()
    ok = _assert(game.last_move.normalized().dot(expected) > 0.99, "touch movement not aligned with diagonal camera") and ok

    var ignore_drag := InputEventScreenDrag.new()
    ignore_drag.index = 4
    ignore_drag.position = Vector2(400, 520)
    touch_ui._input(ignore_drag)
    ok = _assert((touch_ui.get("direction") as Vector2).is_equal_approx(analog), "foreign finger stole joystick") and ok

    var lift := InputEventScreenTouch.new()
    lift.index = 3
    lift.pressed = false
    lift.position = Vector2(250, 515)
    touch_ui._input(lift)
    ok = _assert((touch_ui.get("direction") as Vector2).length_squared() == 0.0, "joystick kept moving after release") and ok

    # Coloca um zumbi proximo, com linha de tiro desobstruida.
    game._spawn_zombie(2.3, PI / 2.0)
    await physics_frame
    var target = game._nearest_visible_zombie()
    ok = _assert(target != null, "automatic targeting failed to find visible zombie") and ok

    game.fire_cooldown = 0.0
    game.reload_timer = 0.0
    game.ammo = 1
    game._mobile_auto_combat()
    ok = _assert(game.ammo == 0, "auto fire did not consume ammo") and ok
    game._mobile_auto_combat()
    ok = _assert(game.reload_timer > 0.0, "auto reload did not start") and ok

    if not ok:
        quit(1)
        return
    print("MOBILE_OK: single joystick, analog WASD, multitouch, auto aim, automatic fire and reload")
    quit(0)
