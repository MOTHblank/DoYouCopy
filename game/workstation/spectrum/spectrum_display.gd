class_name SpectrumDisplay
extends Control

## Low-cost, deterministic visual spectrum. The carrier is not procedural evidence.
var tuned_frequency: float = 101.0
var carrier_frequency: float = 101.3
var quality: float = 0.0
var blocked: bool = false
var anomaly_frequency: float = -1.0
var elapsed: float = 0.0
var redraw_timer: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	redraw_timer += delta
	if redraw_timer > 0.12:
		redraw_timer = 0.0
		queue_redraw()

func set_signal(tuned: float, carrier: float, signal_quality: float, is_blocked: bool, phantom_carrier: float = -1.0) -> void:
	tuned_frequency = tuned
	carrier_frequency = carrier
	quality = signal_quality
	blocked = is_blocked
	anomaly_frequency = phantom_carrier
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color("#061c1d"))
	var left := 25.0
	var right := size.x - 22.0
	var top := 42.0
	var bottom := size.y - 35.0
	for n in range(6):
		var y := lerpf(top, bottom, float(n) / 5.0)
		draw_line(Vector2(left, y), Vector2(right, y), Color("#174a45"), 1.0)
	for n in range(11):
		var x := lerpf(left, right, float(n) / 10.0)
		draw_line(Vector2(x, top), Vector2(x, bottom), Color("#174a45"), 1.0)
	var carrier_x := left + ((carrier_frequency - 100.0) / 10.0) * (right - left)
	var tune_x := left + ((tuned_frequency - 100.0) / 10.0) * (right - left)
	for x_int in range(int(left), int(right), 4):
		var x := float(x_int)
		var ripple := absf(sin(x * 0.31 + elapsed * 0.05) * cos(x * 0.77)) * 12.0
		var carrier := exp(-pow((x - carrier_x) / 18.0, 2.0)) * 104.0
		var height := 9.0 + ripple + carrier
		var y := bottom - height
		draw_line(Vector2(x, bottom), Vector2(x, y), Color("#55bcb0", 0.70), 2.0)
	draw_line(Vector2(tune_x, top), Vector2(tune_x, bottom), Color("#efd18d"), 3.0)
	if anomaly_frequency > 0.0:
		var anomaly_x := left + ((anomaly_frequency - 100.0) / 10.0) * (right - left)
		draw_line(Vector2(anomaly_x, top + 6.0), Vector2(anomaly_x, bottom - 6.0), Color("#b47367", 0.64), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(left, 25), "SPECTRUM / LIVE CARRIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a7dfd3"))
	draw_string(font, Vector2(left, size.y - 8), "RX %.2f MHz   SIG %02d%%" % [tuned_frequency, roundi(quality * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#efd18d"))
	if blocked:
		draw_rect(bounds.grow(-4), Color("#9b3f35", 0.20))
		draw_string(font, Vector2(size.x * 0.37, size.y * 0.52), "BLOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#f4ac95"))
