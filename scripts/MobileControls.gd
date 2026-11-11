extends Control
## Joystick de toque unico. Nenhum botao de tiro, mira, corrida ou recarga.
## Desktop: fica oculto e nao intercepta mouse ou teclado.

const RADIUS := 80.0
const DEAD_ZONE := 0.12
var active: bool = false
var direction := Vector2.ZERO
var finger_index: int = -1
var base := Vector2.ZERO
var thumb := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    active = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
    if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
        # Em navegadores mobile, maxTouchPoints e mais confiavel que o
        # tipo de sistema operacional informado pela exportacao Web.
        var touch_value: Variant = JavaScriptBridge.eval("navigator.maxTouchPoints || 0")
        if touch_value is float or touch_value is int:
            active = active or int(touch_value) > 0
    visible = active
    resized.connect(queue_redraw)

func _default_base() -> Vector2:
    return Vector2(maxf(118.0, size.x * 0.12), size.y - maxf(116.0, size.y * 0.18))

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if finger_index != -1:
                return
            if touch.position.x > size.x * 0.5 or touch.position.y < size.y * 0.30:
                return
            active = true
            visible = true
            finger_index = touch.index
            base = touch.position
            thumb = base
            direction = Vector2.ZERO
            queue_redraw()
            get_viewport().set_input_as_handled()
        elif touch.index == finger_index:
            finger_index = -1
            direction = Vector2.ZERO
            queue_redraw()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index != finger_index:
            return
        active = true
        visible = true
        var offset := drag.position - base
        direction = offset.limit_length(RADIUS) / RADIUS
        if direction.length() < DEAD_ZONE:
            direction = Vector2.ZERO
        thumb = base + direction * RADIUS
        queue_redraw()
        get_viewport().set_input_as_handled()

func _draw() -> void:
    if not active:
        return
    var center := base if finger_index >= 0 else _default_base()
    draw_circle(center, RADIUS + 19.0, Color(0.02, 0.09, 0.12, 0.20))
    draw_circle(center, RADIUS, Color(0.12, 0.22, 0.26, 0.40))
    draw_arc(center, RADIUS, 0.0, TAU, 64, Color(0.85, 0.94, 0.94, 0.55), 4.0, true)
    var current := thumb if finger_index >= 0 else center
    draw_circle(current, 34.0, Color(0.55, 0.80, 0.78, 0.82))
    draw_arc(current, 34.0, 0.0, TAU, 32, Color(0.96, 1.0, 0.96, 0.87), 3.0, true)
