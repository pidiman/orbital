extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var a := StationModel.new()
	var af := MiningFleet.new(a)
	af.regions.records = RegionModel.new(42).records
	var sa := SectorSupply.new(a, af, 42)
	var b := StationModel.new()
	var bf := MiningFleet.new(b)
	bf.regions.records = RegionModel.new(42).records
	var rules: Dictionary = sa.floating_rules.duplicate(true)
	rules.types.materials.erase("visual_variants")
	var sb := SectorSupply.new(b, bf, 42, {}, rules)
	var found: Dictionary = {}
	var economics_match: bool = true
	for i in range(500):
		sa._spawn_debris()
		sb._spawn_debris()
		var piece: Dictionary = sa.floating.home.pieces[sa.next_debris_id].duplicate(true)
		if piece.resource == "materials": found[piece.visual_variant] = sa.next_debris_id
		piece.erase("visual_variant")
		economics_match = economics_match and piece == sb.floating.home.pieces[sb.next_debris_id]
	checks.five_random_variants = found.size() == 5
	checks.economy_rng_unchanged = economics_match and af.regions.records.home.rng_state == bf.regions.records.home.rng_state
	var store = preload("res://scripts/save_store.gd").new(a, af, sa)
	var snapshot: Dictionary = store.snapshot()
	checks.roundtrip = store.restore(snapshot).is_empty() and snapshot == store.snapshot()
	# A gallery of naturally chosen variants, repositioned only in this disposable fixture.
	var shown: Dictionary = {}
	var index: int = 0
	for variant: String in found:
		var id: int = found[variant]
		var piece: Dictionary = sa.floating.home.pieces[id]
		piece.position = Vector2(0.22 + index * 0.2, 0.52)
		shown[id] = piece
		index += 1
	sa.floating.home.pieces = shown
	sa.sync_mining_nodes()
	# Clear orphaned targets in the isolated gallery fixture.
	for target: int in af.resource_targets.keys():
		af.asteroids.erase(target)
		af.resource_targets.erase(target)
	checks.gallery_restore = game.persistence.restore(store.snapshot()).is_empty()
	game.model.materials = 0
	game.model.changed.emit()
	await settle(3)
	save_frame("five_amber_variants")
	game.ship_camera.zoom_view(0.3)
	await settle(2)
	checks.zoomed_out_readable = is_equal_approx(game.debris._visual_scale(game.debris.pieces[0]) * game.ship_camera.zoom.x, 0.6)
	save_frame("debris_zoomed_out")
	game.ship_camera.reset_view()
	var first: Dictionary = game.debris.pieces[0]
	var amount: int = first.amount
	game.ship_camera.position = first.point
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport_rect().size * 0.5)
	checks.salvage = game.model.materials == amount and not game.supply.floating.home.pieces.has(first.id)
	var remaining: int = game.supply.floating.home.pieces.keys()[0]
	game.supply.floating.home.pieces[remaining].erase("visual_variant")
	game.debris._sync_view()
	var legacy_look: String = game.debris._variant(game.supply.floating.home.pieces[remaining], remaining)
	var legacy: Dictionary = game.persistence.snapshot()
	checks.legacy_roundtrip = game.persistence.restore(legacy).is_empty() and game.debris._variant(game.supply.floating.home.pieces[remaining], remaining) == legacy_look
	report("checks", checks)
	finish()
