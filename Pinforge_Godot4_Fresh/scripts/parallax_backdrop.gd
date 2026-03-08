extends ColorRect

@export var top_color: Color = Color("0b1027")
@export var bottom_color: Color = Color("111a3c")
@export var menu_top_color: Color = Color("060b1f")
@export var menu_bottom_color: Color = Color("1a0e2d")

@export var blob_color_a: Color = Color(0.35, 0.56, 0.98, 0.13)
@export var blob_color_b: Color = Color(0.76, 0.35, 0.92, 0.11)
@export var ring_color: Color = Color(0.80, 0.92, 1.00, 0.11)

@export var menu_blob_color_a: Color = Color(0.20, 0.56, 0.96, 0.19)
@export var menu_blob_color_b: Color = Color(0.98, 0.42, 0.14, 0.16)
@export var menu_ring_color: Color = Color(1.00, 0.64, 0.20, 0.15)

var _t: float = 0.0
var _is_menu_mode: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	_draw_gradient(w, h)
	_draw_lava_blobs(w, h)
	_draw_rings(w, h)
	_draw_drift_layer(w, h)
	if _is_menu_mode:
		_draw_neon_sweeps(w, h)
		_draw_orb_particles(w, h)
		_draw_parallax_trails(w, h)

func _draw_gradient(w: float, h: float) -> void:
	var top := top_color
	var bottom := bottom_color
	if _is_menu_mode:
		top = menu_top_color
		bottom = menu_bottom_color

	var bands := 22
	for i in range(bands):
		var t0 := float(i) / float(bands)
		var t1 := float(i + 1) / float(bands)
		var c := top.lerp(bottom, t0)
		draw_rect(Rect2(0.0, h * t0, w, h * (t1 - t0) + 1.0), c, true)

func _draw_lava_blobs(w: float, h: float) -> void:
	var a := blob_color_a
	var b := blob_color_b
	if _is_menu_mode:
		a = menu_blob_color_a
		b = menu_blob_color_b

	var p1 := Vector2(
		w * (0.24 + sin(_t * 0.16) * 0.06),
		h * (0.22 + cos(_t * 0.11) * 0.08)
	)
	var p2 := Vector2(
		w * (0.72 + cos(_t * 0.13 + 1.4) * 0.05),
		h * (0.37 + sin(_t * 0.09 + 0.7) * 0.07)
	)
	var p3 := Vector2(
		w * (0.48 + sin(_t * 0.10 + 0.9) * 0.09),
		h * (0.67 + cos(_t * 0.12 + 2.2) * 0.08)
	)
	var p4 := Vector2(
		w * (0.83 + sin(_t * 0.08 + 2.0) * 0.05),
		h * (0.80 + cos(_t * 0.10 + 1.7) * 0.06)
	)

	draw_circle(p1, h * 0.28, a)
	draw_circle(p2, h * 0.24, b)
	draw_circle(p3, h * 0.32, a.lerp(b, 0.45))
	draw_circle(p4, h * 0.21, b)

func _draw_rings(w: float, h: float) -> void:
	var rc := ring_color
	if _is_menu_mode:
		rc = menu_ring_color

	for i in range(5):
		var fi := float(i)
		var cx := w * (0.18 + fi * 0.19 + sin(_t * 0.15 + fi * 1.3) * 0.05)
		var cy := h * (0.15 + fi * 0.16 + cos(_t * 0.12 + fi * 0.9) * 0.04)
		var r := h * (0.08 + fi * 0.015 + sin(_t * 0.20 + fi) * 0.01)
		var alpha_scale := 0.7 + 0.3 * sin(_t * 0.8 + fi * 2.1)
		var c := rc
		c.a *= alpha_scale
		draw_arc(Vector2(cx, cy), r, 0.0, TAU, 64, c, 2.0)

func _draw_neon_sweeps(w: float, h: float) -> void:
	var sweep_a := Color(0.22, 0.70, 1.00, 0.09)
	var sweep_b := Color(1.00, 0.48, 0.18, 0.08)
	var y1 := h * (0.24 + sin(_t * 0.18) * 0.03)
	var y2 := h * (0.70 + cos(_t * 0.15) * 0.04)
	var thickness := h * 0.16
	draw_rect(Rect2(-w * 0.2, y1, w * 1.4, thickness), sweep_a, true)
	draw_rect(Rect2(-w * 0.2, y2, w * 1.4, thickness * 0.8), sweep_b, true)

func _draw_orb_particles(w: float, h: float) -> void:
	for i in range(22):
		var fi := float(i)
		var x := fposmod(w * (0.11 * fi) + (_t * (9.0 + fi * 0.7)), w + 80.0) - 40.0
		var y := h * (0.18 + fposmod(fi * 0.17 + _t * 0.02, 0.74))
		var pulse := sin(_t * 2.6 + fi * 1.7) * 0.5 + 0.5
		var c := Color(0.35 + pulse * 0.65, 0.55 + pulse * 0.35, 1.0, 0.16 + pulse * 0.32)
		draw_circle(Vector2(x, y), 1.6 + pulse * 2.3, c)

func _draw_drift_layer(w: float, h: float) -> void:
	for i in range(16):
		var fi := float(i)
		var x := fposmod(w * (0.06 * fi) + (_t * (3.0 + fi * 0.3)), w + 120.0) - 60.0
		var y := h * (0.08 + fposmod(fi * 0.11 + _t * 0.01, 0.86))
		var p := sin(_t * 1.8 + fi * 2.4) * 0.5 + 0.5
		var c := Color(0.70, 0.84, 1.0, 0.05 + p * 0.08)
		draw_circle(Vector2(x, y), 0.8 + p * 1.4, c)

func _draw_parallax_trails(w: float, h: float) -> void:
	for i in range(7):
		var fi := float(i)
		var y := h * (0.16 + fi * 0.11 + sin(_t * 0.7 + fi) * 0.02)
		var phase := fposmod(_t * (42.0 + fi * 7.0), w + 220.0)
		var x := phase - 110.0
		var alpha := 0.04 + (sin(_t * 1.2 + fi * 0.8) * 0.5 + 0.5) * 0.07
		var c := Color(0.50, 0.86, 1.0, alpha)
		draw_rect(Rect2(x, y, 140.0 + fi * 20.0, 2.0), c, true)

func set_menu_mode(value: bool) -> void:
	_is_menu_mode = value
	queue_redraw()
