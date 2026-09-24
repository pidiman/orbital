extends SceneTree

const ShipMotion = preload("res://scripts/ship_motion.gd")

func _initialize() -> void:
	# A miner and Xeno Miner share the same arrival-gated extraction rule.
	for state: String in ["FLYING_TO", "FLYING_BACK", "IDLE", "PARKED", "WAITING"]:
		assert(not ShipMotion.beam_visible_for(state, false))
		assert(not ShipMotion.beam_visible_for(state, true))
	assert(not ShipMotion.beam_visible_for("EXTRACTING", false))
	assert(ShipMotion.beam_visible_for("EXTRACTING", true))
	assert(not ShipMotion.beam_visible_for("EXTRACTING", false))
	# Repair uses the same visual predicate with its own active state and color.
	assert(not ShipMotion.beam_visible_for("REPAIRING", false))
	assert(ShipMotion.beam_visible_for("REPAIRING", true))
	print("PASS: miner, Xeno Miner, and Repair Ship beams are arrival-gated")
	quit(0)
