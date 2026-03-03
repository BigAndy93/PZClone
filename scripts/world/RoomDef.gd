class_name RoomDef
extends RefCounted

enum RoomPurpose { BEDROOM=0, KITCHEN=1, LIVING=2, STORAGE=3, HALLWAY=4, COMMERCIAL=5 }

# Signed-fraction bounds in building nf/ef space (±1 ≈ exterior wall, 0 = centre).
var purpose: int = RoomPurpose.LIVING
var nf_min: float = -1.0;  var nf_max: float = 1.0
var ef_min: float = -1.0;  var ef_max: float = 1.0

static func make(p: int, nf0: float, nf1: float, ef0: float, ef1: float) -> RoomDef:
	var r := RoomDef.new()
	r.purpose = p;  r.nf_min = nf0;  r.nf_max = nf1;  r.ef_min = ef0;  r.ef_max = ef1
	return r

func nf_centre() -> float: return (nf_min + nf_max) * 0.5
func ef_centre() -> float: return (ef_min + ef_max) * 0.5


class InteriorWallDef extends RefCounted:
	enum Axis { NF = 0, EF = 1 }

	# axis=NF → wall at fixed nf value, runs in EF direction (lo/hi are ef bounds).
	# axis=EF → wall at fixed ef value, runs in NF direction (lo/hi are nf bounds).
	var axis:          int   = Axis.EF
	var value:         float = 0.0
	var lo:            float = -0.80
	var hi:            float =  0.80
	# door_fraction: position of door gap on the parallel axis. -INF = no door.
	var door_fraction: float = -INF

	static func make(ax: int, val: float, lo_: float, hi_: float,
			door_frac: float = -INF) -> InteriorWallDef:
		var w := InteriorWallDef.new()
		w.axis = ax;  w.value = val;  w.lo = lo_;  w.hi = hi_
		w.door_fraction = door_frac
		return w
