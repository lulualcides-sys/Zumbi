extends SceneTree
## Real Godot screenshots for comparing rig/weapon idle poses, not concept art.
const Gun = preload("res://scripts/WeaponVisual.gd")

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var scene_resource := load("res://scenes/Main.tscn") as PackedScene
    if scene_resource == null:
        push_error("Missing scene")
        quit(1)
        return
    root.size = Vector2i(1280, 720)
    var scene := scene_resource.instantiate()
    root.add_child(scene)
    scene.set_physics_process(false)
    var player_anim: AnimationPlayer = scene.player_art.get("player")
    if player_anim == null:
        push_error("Missing AnimationPlayer")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
    var count := 0
    for clip in ["ready_idle", "aim_idle", "idle"]:
        if not player_anim.has_animation(clip):
            push_warning("Clip missing for pose comparison: " + clip)
            continue
        player_anim.play(clip, 0.0, 1.0)
        player_anim.seek(0.33, true)
        Gun.align_to_hands(scene.weapon_rig, scene.player, 1.0)
        for frame in range(5):
            await process_frame
        var screenshot := root.get_texture().get_image()
        if screenshot == null or screenshot.is_empty():
            push_error("Screenshot unavailable: " + clip)
            quit(1)
            return
        var path := "res://build/pose_%s.png" % clip
        if screenshot.save_png(path) != OK:
            push_error("Pose screenshot failed: " + path)
            quit(1)
            return
        print("POSE_CAPTURE_OK: ", clip, " -> ", path)
        count += 1
    quit(0 if count >= 2 else 1)
