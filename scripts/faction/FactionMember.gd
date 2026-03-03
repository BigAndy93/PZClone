class_name FactionMember
extends Resource

## Describes an individual NPC's faction membership and behaviour modifiers.

@export var faction_id: String = ""
@export var member_name: String = ""
@export var is_leader: bool = false
@export var aggression_modifier: float = 1.0  # multiplier on attack triggers
