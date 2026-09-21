class_name StationGeometry
extends RefCounted

const MODULE_SIZE: float = 58.0
const EPSILON: float = 0.001
# Odd dimensions preserve the original center and the complete legacy 9×9 area.
static var grid_dimensions: Vector2i = _read_grid_dimensions()

static func _read_grid_dimensions() -> Vector2i:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/station_grid.json"))
	if parsed is Dictionary:
		var columns: int = int(parsed.get("columns", 0))
		var rows: int = int(parsed.get("rows", 0))
		if columns >= 9 and rows >= 9 and columns % 2 == 1 and rows % 2 == 1 and parsed.columns == columns and parsed.rows == rows:
			return Vector2i(columns, rows)
	push_warning("Invalid station_grid.json: use odd integer dimensions >= 9. Using 17×17.")
	return Vector2i(17, 17)

static func grid_radius() -> Vector2i:
	return (grid_dimensions - Vector2i.ONE) / 2

static func build_extent() -> Vector2:
	return Vector2(grid_radius()) * MODULE_SIZE

static func overlaps(a: Vector2, b: Vector2) -> bool:
	var delta: Vector2 = (a - b).abs()
	return delta.x < MODULE_SIZE - EPSILON and delta.y < MODULE_SIZE - EPSILON

static func connected(a: Vector2, b: Vector2) -> bool:
	var delta: Vector2 = (a - b).abs()
	return (absf(delta.x - MODULE_SIZE) <= EPSILON and delta.y < MODULE_SIZE - EPSILON) or (absf(delta.y - MODULE_SIZE) <= EPSILON and delta.x < MODULE_SIZE - EPSILON)

static func contains_center(point: Vector2) -> bool:
	var extent: Vector2 = build_extent()
	return point.is_finite() and absf(point.x) <= extent.x and absf(point.y) <= extent.y

static func touches_any(point: Vector2, positions: Array) -> bool:
	for existing: Vector2 in positions:
		if connected(point, existing):
			return true
	return false
