extends RefCounted
## Stateless first-block decision from detached friendly knowledge only.

static func decide(input: Dictionary) -> Dictionary:
	var nodes: Dictionary = input.get("nodes",{})
	var elements: Array = input.get("elements",[])
	var start := str(input.get("origin",""))
	var finish := str(input.get("destination",""))
	if not nodes.has(start) or not nodes.has(finish) or elements.is_empty():
		return {"ok":false,"reason":"A known start, destination and own element are required."}
	var movement := str(elements[0].get("movement",""))
	var routes: Array[Dictionary] = []
	_visit(start,finish,input.get("connections",[]),movement,[start],[],0.0,routes)
	if routes.is_empty(): return {"ok":false,"reason":"No known compatible route is available."}
	routes.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.metres) < float(b.metres))
	var chosen: Dictionary = routes[0]
	var crossing := ""
	for id: String in chosen.edges:
		for edge: Dictionary in input.connections:
			if edge.id == id and edge.constraint == "crossing": crossing = id; break
	var point_id: String = str(chosen.nodes[chosen.nodes.size()-2]) if chosen.nodes.size() > 1 else start
	var question := "Can hostile forces observe or threaten the route near %s?" % str(nodes[point_id].label)
	var event := {
		"sequence":1, "kind":"commander_decision", "time_seconds":float(input.get("time_seconds",0.0)),
		"side":str(input.side), "actor":str(input.commander), "position":nodes[start].position,
		"input_refs":["mission","known-geography","own-elements","known-hq-coordinates"],
		"inputs":input.duplicate(true),
		"mission":str(input.mission), "selected_route":chosen.duplicate(true),
		"alternatives":routes.slice(1).duplicate(true),
		"reason":"Shortest known compatible route supports the stated access mission; threat is unconfirmed.",
		"uncertainty":question, "uncertainty_location":nodes[point_id].position,
		"constrained_connection":crossing, "causes":[]
	}
	return {"ok":true,"effect":"Keep the selected approach usable.","route":chosen,"alternatives":routes.slice(1),"question":question,"question_at":point_id,"journal":[event]}

static func reassess(_input: Dictionary, previous: Dictionary, delivered: Dictionary) -> Dictionary:
	# The only new information is the delivered local observation, not world truth.
	var result: Dictionary = previous.duplicate(true)
	var detected: Array = delivered.get("detected_classes",[])
	result["received_observation"] = delivered.duplicate(true)
	result["reassessment"] = "Retain the route provisionally: nothing was detected within the reported area at the observation time; other areas and later movement remain unknown." if detected.is_empty() else "Retain the route as an uncommitted candidate: a local report identified %s; the commander needs further assessment." % ", ".join(detected)
	return result

static func _visit(current: String, finish: String, edges: Array, movement: String, path: Array, used: Array, length: float, routes: Array[Dictionary]) -> void:
	if current == finish:
		routes.append({"nodes":path.duplicate(),"edges":used.duplicate(),"metres":length})
		return
	for edge: Dictionary in edges:
		if movement not in edge.movement or float(edge.metres) <= 0.0: continue
		var next := ""
		if edge.from == current: next = str(edge.to)
		elif edge.to == current: next = str(edge.from)
		if next.is_empty() or next in path: continue
		_visit(next,finish,edges,movement,path+[next],used+[str(edge.id)],length+float(edge.metres),routes)
