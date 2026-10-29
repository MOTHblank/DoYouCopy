class_name FieldMapDisplay
extends Control

## Paper/map truth is intentionally separate from the fallible terminal.
const STATIONS := {
	"Relay": Vector2(165, 105),
	"Junction": Vector2(475, 105),
	"Pump Station B": Vector2(165, 275),
	"East Service": Vector2(475, 275)
}
var verified_locations: Dictionary = {}
var field_status: Dictionary = {}

func update_verified_positions(locations: Dictionary, statuses: Dictionary) -> void:
	verified_locations = locations.duplicate()
	field_status = statuses.duplicate()
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("#b7bca7"))
	draw_rect(Rect2(18, 18, size.x - 36, size.y - 36), Color("#d1d0b7"), false, 3.0)
	draw_string(font, Vector2(30, 44), "FIELD MAP / VERIFIED READ-BACKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("#344d48"))
	for pair in [
		["Relay", "Junction"], ["Relay", "Pump Station B"],
		["Junction", "East Service"], ["Pump Station B", "East Service"]
	]:
		draw_line(STATIONS[pair[0]], STATIONS[pair[1]], Color("#74867c"), 5.0)
	for name in STATIONS.keys():
		var point: Vector2 = STATIONS[name]
		draw_circle(point, 14.0, Color("#435f56"))
		draw_string(font, point + Vector2(-70, -24), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#33433f"))
	for callsign in ["ECHO-ACTUAL", "ECHO-2"]:
		var position_name: String = str(verified_locations.get(callsign, ""))
		if not STATIONS.has(position_name):
			continue
		var point: Vector2 = STATIONS[position_name]
		var shift := Vector2(24, -2) if callsign == "ECHO-ACTUAL" else Vector2(24, 18)
		var color := Color("#2d5c66") if callsign == "ECHO-ACTUAL" else Color("#995e45")
		draw_circle(point + shift, 10.0, color)
		var suffix := "*" if str(field_status.get(callsign, "")) != "AVAILABLE" else ""
		draw_string(font, point + shift + Vector2(15, 5), ("A" if callsign == "ECHO-ACTUAL" else "2") + suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
	draw_string(font, Vector2(30, size.y - 18), "Only operator-confirmed movements update these positions.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#65756c"))
