extends SceneTree
## Optional real-render screenshot smoke on Linux Xvfb/OpenGL, not a mockup.

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var scene := load("res://scenes/Main.tscn") as PackedScene
    if scene == null:
        push_error("Screenshot scene missing")
        quit(1)
        return
    root.size = Vector2i(1280, 720)
    root.add_child(scene.instantiate())
    # Give GL texture uploads and animation pose time to render.
    for frame in range(8):
        await process_frame
    var canvas := root.get_texture()
    if canvas == null:
        push_error("No render target from Window")
        quit(1)
        return
    var image := canvas.get_image()
    if image == null or image.is_empty() or image.get_width() < 640:
        push_error("No usable rendered frame")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
    var result := image.save_png("res://build/preview.png")
    if result != OK:
        push_error("Could not save screenshot: %s" % str(result))
        quit(1)
        return
    print("RENDER_PREVIEW_OK: 1280x720 - build/preview.png")
    # Capture actual narrower mobile UI; tests should reveal clipped UI,
    # weapon orientation and fence visibility in landscape and portrait.
    var game: Node3D = root.get_child(root.get_child_count()-1) as Node3D
    var touch_control: Control = game.get("mobile_controls")
    touch_control.active = true
    touch_control.visible = true
    game.call("_refresh_control_labels")
    for viewport_size in [Vector2i(896, 414), Vector2i(720, 1280)]:
        root.size = viewport_size
        for frame in range(6):
            await process_frame
        touch_control.queue_redraw()
        await process_frame
        var mobile_image := root.get_texture().get_image()
        if mobile_image == null or mobile_image.is_empty() or mobile_image.get_width() < 600:
            push_error("Mobile screen capture failed: " + str(viewport_size))
            quit(1)
            return
        var tag := "mobile-landscape" if viewport_size.x > viewport_size.y else "mobile-portrait"
        if mobile_image.save_png("res://build/preview-" + tag + ".png") != OK:
            push_error("Could not save " + tag)
            quit(1)
            return
        print("RENDER_MOBILE_OK: ", str(viewport_size), " build/preview-", tag, ".png")
    quit(0)
