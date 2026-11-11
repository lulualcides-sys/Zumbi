extends SceneTree
## Renders 3D soldier from side and front, to diagnose imports/IK faithfully.
const Gun = preload("res://scripts/WeaponVisual.gd")
func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var loaded := load("res://scenes/Main.tscn") as PackedScene
    if loaded == null:
        push_error("Missing Main scene")
        quit(1)
        return
    root.size = Vector2i(1280, 720)
    var scene := loaded.instantiate()
    root.add_child(scene)
    scene.set_physics_process(false)
    scene.player.rotation.y = 0.0
    scene.aim_direction = Vector3.BACK
    var animations: AnimationPlayer = scene.player_art.get("player")
    if animations == null:
        push_error("Imported soldier has no animator")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
    for pose in ["ready_idle", "aim_idle", "idle"]:
        if not animations.has_animation(pose):
            continue
        animations.play(pose, 0.0, 1.0)
        animations.seek(0.38, true)
        Gun.align_to_hands(scene.weapon_rig, scene.player, 1.0)
        for axis in ["front", "side"]:
            scene.camera.size = 3.7
            var offset := Vector3(0.5, 2.05, 5.2) if axis == "front" else Vector3(5.0, 2.05, 0.4)
            scene.camera.global_position = scene.player.global_position + offset
            scene.camera.look_at(scene.player.global_position + Vector3(0, 0.35, 0))
            for frame in range(7):
                await process_frame
            var img := root.get_texture().get_image()
            if img == null or img.is_empty():
                push_error("Rig profile screenshot failed")
                quit(1)
                return
            var path := "res://build/rig-%s-%s.png" % [pose,axis]
            if img.save_png(path) != OK:
                push_error("Unable to save " + path)
                quit(1)
                return
            print("RIG_PROFILE_OK: ", path)
    quit(0)
