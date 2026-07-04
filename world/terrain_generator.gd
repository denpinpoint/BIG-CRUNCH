class_name TerrainGenerator
extends RefCounted
## Deterministic, seed-based world generation.
##
## The single source of truth is `generate_block(wx, wy, wz)`: a pure function
## of world-space block coordinates + the seed. The same seed always produces
## the same world, and because it is sampled in WORLD space (never chunk-local
## space), everything — terrain, cliffs, caves, ores, trees — stitches
## seamlessly across chunk borders: both sides evaluate the same function.
##
## Thread safety: all FastNoiseLite instances are created once in _init() and
## only ever *read* afterwards, so any number of worker threads can generate
## chunks concurrently from one shared TerrainGenerator.

var world_seed: int

var _height_noise: FastNoiseLite    # rolling base terrain
var _mountain_noise: FastNoiseLite  # broad ridged uplift
var _cliff_noise: FastNoiseLite     # plateau/terrace mask -> sheer cliff walls
var _cave_cheese: FastNoiseLite     # 3D blob/cavern noise
var _cave_worm_a: FastNoiseLite     # 3D winding tunnel field A
var _cave_worm_b: FastNoiseLite     # 3D winding tunnel field B
var _entrance_noise: FastNoiseLite  # 2D mask: where tunnels may breach the surface
var _ore_noise: FastNoiseLite       # high-frequency 3D blobs -> ore veins

# Columns this close to an underwater column count as shoreline (sand).
const _BEACH_PROBES: Array[Vector2i] = [
	Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4),
	Vector2i(3, 3), Vector2i(-3, 3), Vector2i(3, -3), Vector2i(-3, -3),
]


func _init(seed_value: int) -> void:
	world_seed = seed_value

	_height_noise = FastNoiseLite.new()
	_height_noise.seed = seed_value
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_height_noise.frequency = 0.0055
	_height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height_noise.fractal_octaves = 4

	_mountain_noise = FastNoiseLite.new()
	_mountain_noise.seed = seed_value + 101
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountain_noise.frequency = 0.0016
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain_noise.fractal_octaves = 3

	_cliff_noise = FastNoiseLite.new()
	_cliff_noise.seed = seed_value + 202
	_cliff_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cliff_noise.frequency = 0.004
	_cliff_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_cliff_noise.fractal_octaves = 2

	# Dedicated seeded 3D noises for caves, offset from the terrain seed so
	# cave shapes are independent of the heightmap.
	_cave_cheese = FastNoiseLite.new()
	_cave_cheese.seed = seed_value + 7001
	_cave_cheese.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_cheese.frequency = 0.045

	_cave_worm_a = FastNoiseLite.new()
	_cave_worm_a.seed = seed_value + 7002
	_cave_worm_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cave_worm_a.frequency = 0.02

	_cave_worm_b = FastNoiseLite.new()
	_cave_worm_b.seed = seed_value + 7003
	_cave_worm_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cave_worm_b.frequency = 0.02

	_entrance_noise = FastNoiseLite.new()
	_entrance_noise.seed = seed_value + 303
	_entrance_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_entrance_noise.frequency = 0.012
	_entrance_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_entrance_noise.fractal_octaves = 2

	_ore_noise = FastNoiseLite.new()
	_ore_noise.seed = seed_value + 9001
	_ore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ore_noise.frequency = 0.09


# --- Public API -------------------------------------------------------------

## Pure per-block generation: (world_x, world_y, world_z, seed) -> block id.
func generate_block(wx: int, wy: int, wz: int) -> int:
	return _block_at(wx, wy, wz, {}, {})


## Terrain surface height (top solid block y) for a column. Deterministic.
## Three stacked layers:
##  * rolling FBM base (gentle hills)
##  * ridged mountain uplift (rare, tall)
##  * cliff terraces: smoothstep over a NARROW band of a low-frequency noise
##    turns a gradual gradient into a 12-14 block wall wherever the noise
##    crosses the band — that's what produces the random sheer cliffs.
func surface_height(wx: int, wz: int) -> int:
	var base := float(Constants.SEA_LEVEL) + 3.0 + _height_noise.get_noise_2d(wx, wz) * 11.0
	var m := maxf(0.0, _mountain_noise.get_noise_2d(wx, wz))
	base += pow(m, 2.3) * 38.0
	var c := _cliff_noise.get_noise_2d(wx, wz)
	base += smoothstep(0.16, 0.24, c) * 14.0  # lower plateau wall
	base += smoothstep(0.48, 0.56, c) * 12.0  # second tier on big plateaus
	return clampi(int(floor(base)), 2, Constants.CHUNK_SIZE_Y - 8)


## Fills a whole chunk's flat block array. Same results as calling
## generate_block for every cell, but with per-column caching of heights and
## tree data (leaves + beach checks sample column neighborhoods, so caching
## matters a lot here).
## PERF: this is the hottest generation path (~24k blocks + 3D cave/ore noise
## per chunk). It runs on worker threads. If it ever becomes the bottleneck,
## port this file to C# or GDExtension — the algorithm translates 1:1.
func generate_chunk_data(cpos: Vector2i) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(Constants.CHUNK_SIZE_X * Constants.CHUNK_SIZE_Y * Constants.CHUNK_SIZE_Z)

	var hcache: Dictionary[Vector2i, int] = {}
	var tcache: Dictionary[Vector2i, int] = {}
	var base_x := cpos.x * Constants.CHUNK_SIZE_X
	var base_z := cpos.y * Constants.CHUNK_SIZE_Z

	for lz in Constants.CHUNK_SIZE_Z:
		for lx in Constants.CHUNK_SIZE_X:
			var wx := base_x + lx
			var wz := base_z + lz
			for ly in Constants.CHUNK_SIZE_Y:
				var id := _block_at(wx, ly, wz, hcache, tcache)
				if id != BlockTypes.AIR:
					data[Constants.local_block_index(Vector3i(lx, ly, lz))] = id
	return data


# --- Internals --------------------------------------------------------------

## Shared implementation behind generate_block/generate_chunk_data. The two
## caches memoize per-column surface heights and tree heights; passing fresh
## empty dictionaries gives identical (pure) results, just slower.
func _block_at(wx: int, wy: int, wz: int, hcache: Dictionary[Vector2i, int], tcache: Dictionary[Vector2i, int]) -> int:
	if wy <= 0:
		return BlockTypes.BEDROCK  # the world floor is always intact
	if wy >= Constants.CHUNK_SIZE_Y:
		return BlockTypes.AIR

	var h := _cached_height(wx, wz, hcache)

	if wy <= h:
		# Solid terrain column first, then subtract cave air (carving order
		# matters: caves never punch through bedrock or float above ground).
		if _is_cave(wx, wy, wz, h):
			# TODO: flood carved air with water/lava below a cave-water level.
			# TODO: grass/dirt recovery on newly exposed cave ceilings.
			return BlockTypes.AIR
		if wy >= h - 3:
			# Surface crust: grass/dirt inland, sand ONLY on real shorelines
			# (at water height AND with actual water nearby) and underwater.
			if h < Constants.SEA_LEVEL:
				return BlockTypes.SAND if h >= Constants.SEA_LEVEL - 7 else BlockTypes.STONE
			if _is_beach(wx, wz, h, hcache):
				return BlockTypes.SAND
			if wy == h:
				return BlockTypes.GRASS
			return BlockTypes.DIRT
		return _stone_or_ore(wx, wy, wz)

	# Above the surface: water up to sea level...
	if wy <= Constants.SEA_LEVEL:
		return BlockTypes.WATER

	# ...then trees. Trunk of this column's own tree:
	var th := _cached_tree_height(wx, wz, hcache, tcache)
	if th > 0 and wy <= h + th:
		return BlockTypes.WOOD

	# Leaf canopies can reach over from trees up to 2 columns away, so scan
	# the 5x5 neighborhood. Only bother near surface height.
	# PERF: 25 cached column lookups per near-surface air block.
	if wy <= h + 12:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if dx == 0 and dz == 0:
					continue  # own trunk handled above
				var nx := wx + dx
				var nz := wz + dz
				var nth := _cached_tree_height(nx, nz, hcache, tcache)
				if nth == 0:
					continue
				var top := _cached_height(nx, nz, hcache) + nth  # trunk top block
				var rel := wy - top
				var in_canopy := false
				match rel:
					-2, -1:
						# wide layers, minus the corners for a rounder look
						in_canopy = not (absi(dx) == 2 and absi(dz) == 2)
					0:
						in_canopy = absi(dx) <= 1 and absi(dz) <= 1
					1:
						in_canopy = absi(dx) + absi(dz) <= 1
				if in_canopy:
					return BlockTypes.LEAVES
	# The trunk's own crown block:
	if th > 0 and wy == h + th + 1:
		return BlockTypes.LEAVES
	return BlockTypes.AIR


## Sand only forms next to actual water: the column must sit at water height
## AND at least one probed neighbor column must be underwater. Low inland
## plains stay grass.
func _is_beach(wx: int, wz: int, h: int, hcache: Dictionary[Vector2i, int]) -> bool:
	if h > Constants.SEA_LEVEL + 2:
		return false
	for probe: Vector2i in _BEACH_PROBES:
		if _cached_height(wx + probe.x, wz + probe.y, hcache) < Constants.SEA_LEVEL:
			return true
	return false


## Deep stone with embedded ore veins. One extra 3D noise sample per stone
## block: where the high-frequency field spikes we place ore, and the vein's
## TYPE comes from a hash of the 4x4x4 region it sits in — so a whole blob is
## one consistent ore instead of confetti. Rarity gates by depth:
##   coal anywhere, iron below y=52, gold below y=26, diamond below y=14.
func _stone_or_ore(wx: int, wy: int, wz: int) -> int:
	var n := _ore_noise.get_noise_3d(wx, wy, wz)
	if n < 0.62:
		return BlockTypes.STONE
	var r := _hash3(wx >> 2, wy >> 2, wz >> 2)
	if wy <= 14 and r > 0.90:
		return BlockTypes.DIAMOND_ORE
	if wy <= 26 and r > 0.78:
		return BlockTypes.GOLD_ORE
	if wy <= 52 and r > 0.45:
		return BlockTypes.IRON_ORE
	return BlockTypes.COAL_ORE


func _cached_height(wx: int, wz: int, hcache: Dictionary[Vector2i, int]) -> int:
	var key := Vector2i(wx, wz)
	if hcache.has(key):
		return hcache[key]
	var h := surface_height(wx, wz)
	hcache[key] = h
	return h


## Tree height for a column (0 = no tree). Trees only grow on grass tops,
## placed by a deterministic integer hash so tree positions are stable per
## seed without extra noise instances.
func _cached_tree_height(wx: int, wz: int, hcache: Dictionary[Vector2i, int], tcache: Dictionary[Vector2i, int]) -> int:
	var key := Vector2i(wx, wz)
	if tcache.has(key):
		return tcache[key]
	var th := 0
	var h := _cached_height(wx, wz, hcache)
	if h > Constants.SEA_LEVEL + 1 and h < Constants.CHUNK_SIZE_Y - 12:
		if not _is_beach(wx, wz, h, hcache):
			if _hash01(wx, wz, world_seed) < Constants.TREE_CHANCE:
				th = 4 + int(_hash01(wx * 3 + 1, wz * 7 + 3, world_seed) * 3.0)  # 4..6
	tcache[key] = th
	return th


## Cave carving test. Two styles, both sampled in world space:
##  * "Cheese" caves: one 3D density noise; where it crosses a threshold we
##    carve open blobs/caverns. The threshold is biased by depth so caves are
##    rare near the surface and common down deep.
##  * "Spaghetti" tunnels: two independent smooth 3D fields; carve where BOTH
##    |a| and |b| are near zero. Each field's zero-set is a winding surface,
##    and the intersection of two surfaces is a long 1D worm — natural
##    branching tunnels. Cave mouths appear where tunnels meet cliff walls.
## PERF: 3D noise per underground block is the expensive part of generation
## (~3 samples per block below the surface). If needed: early-out on the
## cheapest field, or sample on a coarse 4^3 grid and trilinearly interpolate.
func _is_cave(wx: int, wy: int, wz: int, surface_h: int) -> bool:
	if wy <= 1:
		return false  # keep the bedrock floor + one stone layer intact
	if wy > surface_h - Constants.CAVE_MIN_DEPTH:
		# Near/at the surface, carving is normally forbidden — EXCEPT inside
		# designated "entrance regions" (a sparse low-frequency 2D mask),
		# where worm tunnels are allowed to keep going and punch through the
		# crust. That's what turns SOME caves into walk-in cave mouths while
		# most of the network stays sealed underground.
		var entrance := _entrance_factor(wx, wz)
		if entrance <= 0.0:
			return false
		var width := 0.065 * entrance  # mouths narrow slightly vs. deep tunnels
		if absf(_cave_worm_a.get_noise_3d(wx, wy, wz)) < width:
			if absf(_cave_worm_b.get_noise_3d(wx, wy, wz)) < width:
				return true
		return false

	# 0 at bedrock -> 1 near sea level; deeper = lower threshold = more caves.
	var depth_frac := clampf(float(wy) / float(Constants.SEA_LEVEL), 0.0, 1.0)

	var cheese := _cave_cheese.get_noise_3d(wx, wy, wz)
	if cheese > lerpf(0.34, 0.60, depth_frac):
		return true

	var a := absf(_cave_worm_a.get_noise_3d(wx, wy, wz))
	if a < 0.08:
		var b := absf(_cave_worm_b.get_noise_3d(wx, wy, wz))
		if b < 0.08:
			return true
	return false


## 0 almost everywhere; ramps to 1 inside sparse entrance regions (roughly a
## tenth of the map). Purely 2D + seeded, so entrances are deterministic and
## chunk-border safe like everything else.
func _entrance_factor(wx: int, wz: int) -> float:
	return smoothstep(0.42, 0.58, _entrance_noise.get_noise_2d(wx, wz))


## Deterministic integer hash -> [0, 1). Stable across runs and platforms.
func _hash01(x: int, z: int, s: int) -> float:
	var h := x * 374761393 + z * 668265263 + s * 2246822519
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)


func _hash3(x: int, y: int, z: int) -> float:
	var h := x * 73856093 + y * 19349663 + z * 83492791 + world_seed * 2246822519
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)
