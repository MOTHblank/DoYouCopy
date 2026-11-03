class_name AuthenticationDocument
extends Resource

## An operator-visible reference. This does not grant or check GHOST knowledge.
@export var challenge_id: StringName = &""
@export_multiline var prompt: String = ""
@export var answer: String = ""
@export var revision_date: String = ""

@export_group("Validity (one-based campaign contact numbers)")
@export_range(1, 99, 1) var valid_from_contact: int = 1
@export_range(1, 99, 1) var valid_through_contact: int = 1
## The first obsolete stage can be FILED; later copies show as RETIRED.
@export_range(0, 99, 1) var filed_through_contact: int = 0

@export_group("Operator Visibility")
@export_range(1, 99, 1) var visible_from_contact: int = 1
@export_range(1, 99, 1) var visible_through_contact: int = 8
@export var required_flags: PackedStringArray = PackedStringArray()
@export var excluded_flags: PackedStringArray = PackedStringArray()

func is_visible(contact_number: int, flags: Dictionary) -> bool:
	if contact_number < visible_from_contact or contact_number > visible_through_contact:
		return false
	# Do not display a challenge before its first issuance.
	if contact_number < valid_from_contact:
		return false
	for flag in required_flags:
		if not flags.has(String(flag)):
			return false
	for flag in excluded_flags:
		if flags.has(String(flag)):
			return false
	return true

func status_at(contact_number: int) -> String:
	if contact_number <= valid_through_contact:
		return "CURRENT"
	if contact_number <= filed_through_contact:
		return "FILED"
	return "RETIRED"

func render_for(contact_number: int, flags: Dictionary) -> String:
	if not is_visible(contact_number, flags):
		return ""
	var status := status_at(contact_number)
	var lines := PackedStringArray(["%s / %s" % [String(challenge_id), status]])
	if status == "CURRENT" and not prompt.is_empty():
		lines.append(prompt)
	lines.append(answer)
	if not revision_date.is_empty():
		lines.append("REVISION: " + revision_date)
	return "\n".join(lines)
