class_name LootItem
extends Area2D

# collision_layer 16 = layer 5 "Triggers"
# InteractArea on Player must have collision_mask include 16.

var item_data: ItemData = null


func _ready() -> void:
	add_to_group("loot_items")
	collision_layer = 16
	collision_mask  = 0
	monitoring  = false
	monitorable = true
	z_index     = 1  # draw above ground tiles

	if item_data:
		_build_visual()
	_build_collision()


func _build_visual() -> void:
	const S := 8.0
	var poly     := Polygon2D.new()
	poly.polygon  = PackedVector2Array([
		Vector2(-S, -S), Vector2(S, -S), Vector2(S, S), Vector2(-S, S),
	])
	var type_idx  := clampi(item_data.item_type, 0, ItemData.TYPE_COLORS.size() - 1)
	poly.color    = ItemData.TYPE_COLORS[type_idx]
	add_child(poly)

	var lbl              := Label.new()
	lbl.text              = item_data.item_name.left(7)
	lbl.scale             = Vector2(0.42, 0.42)
	lbl.position         = Vector2(-18.0, -28.0)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(lbl)


func _build_collision() -> void:
	var shape    := CircleShape2D.new()
	shape.radius  = 20.0
	var col      := CollisionShape2D.new()
	col.shape     = shape
	add_child(col)
