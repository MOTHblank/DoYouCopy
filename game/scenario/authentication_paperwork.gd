class_name AuthenticationPaperwork
extends Resource

## The order is newest-first. Availability is based on campaign contact and flags,
## never on a caller's claimed identity or the hidden GHOST knowledge state.
@export var documents: Array[AuthenticationDocument] = []

func reference_for(contact_number: int, flags: Dictionary) -> String:
	var sections := PackedStringArray()
	for document in documents:
		if document == null:
			continue
		var rendered := document.render_for(contact_number, flags)
		if not rendered.is_empty():
			sections.append(rendered)
	if sections.is_empty():
		return "NO AUTHENTICATION PAPERWORK AVAILABLE."
	return "\n\n".join(sections)
