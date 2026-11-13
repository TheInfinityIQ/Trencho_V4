extends RefCounted
## Prototype physical world. The commander never receives this object.
var people: Dictionary = {}
var _hostiles: Array = []

func _init(known: Dictionary, fixture: Dictionary) -> void:
	var start: Vector2 = known.nodes[known.origin].position
	for element: Dictionary in known.elements:
		for id: String in element.individuals:
			people[id] = {"id":id,"position":start}
	_hostiles = fixture.get("hostiles",[]).duplicate(true)

func move_toward(ids: Array, destination: Vector2, distance: float) -> void:
	for id: String in ids:
		if people.has(id): people[id].position = (people[id].position as Vector2).move_toward(destination,distance)

func observe(ids: Array, radius: float, at: float) -> Dictionary:
	if ids.is_empty() or not people.has(ids[0]): return {}
	var observer := str(ids[0])
	var position: Vector2 = people[observer].position
	var classes: Array[String] = []
	for hostile: Dictionary in _hostiles:
		if position.distance_to(hostile.position) <= radius: classes.append(str(hostile.get("class","unknown")))
	return {"observer":observer,"observed_at":at,"position":position,"radius_m":radius,"detected_classes":classes,
		"scope":"Circular unobstructed prototype sensor; only this area and instant were checked."}
