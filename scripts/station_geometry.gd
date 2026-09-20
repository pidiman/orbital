class_name StationGeometry
extends RefCounted

const MODULE_SIZE: float = 58.0
const BUILD_EXTENT: float = 232.0
const EPSILON: float = 0.001

static func overlaps(a: Vector2, b: Vector2) -> bool:
	var delta: Vector2 = (a - b).abs()
	return delta.x < MODULE_SIZE - EPSILON and delta.y < MODULE_SIZE - EPSILON

static func connected(a: Vector2, b: Vector2) -> bool:
	var delta: Vector2 = (a - b).abs()
	return (absf(delta.x - MODULE_SIZE) <= EPSILON and delta.y < MODULE_SIZE - EPSILON) or (absf(delta.y - MODULE_SIZE) <= EPSILON and delta.x < MODULE_SIZE - EPSILON)

static func contains_center(point: Vector2) -> bool:
	return point.is_finite() and absf(point.x) <= BUILD_EXTENT and absf(point.y) <= BUILD_EXTENT

static func touches_any(point: Vector2, positions: Array) -> bool:
	for existing: Vector2 in positions:
		if connected(point, existing):
			return true
	return false
