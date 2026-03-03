class_name FactionData
extends Resource

@export var faction_id: String = ""
@export var faction_name: String = ""

## Thresholds for disposition strings
@export var hostile_threshold: float = -30.0   # rep <= this → hostile
@export var friendly_threshold: float = 10.0   # rep >= this → friendly (if < allied)
@export var allied_threshold: float = 50.0     # rep >= this → allied

## event_key -> reputation delta
@export var reputation_events: Dictionary = {}

## Starting reputation for new players
@export var default_reputation: float = 0.0
