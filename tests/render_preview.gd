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
    quit(0)
