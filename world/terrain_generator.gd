class_name TerrainGenerator
extends RefCounted
## Deterministic, seed-based world generation.
##
## The single source of truth is `generate_block(wx, wy, wz)`: a pure function
## of world-space block coordinates + the seed. The same seed always produces
## the same world, and because it is sampled in WORLD space (never chunk-local
## space), everything — terrain, caves, trees — stitches seamlessly across
## chunk borders for free: both sides of a border evaluate the exact same
## function.
##
## Thread safety: all FastNoiseLite instances are created once in _init() and
## only ever *read* afterwards, so any number of worker threads can generate
## chunks concurrently from one shared TerrainGenerator.

var world_seed: int

var _height_noise: FastNoiseLite    # rolling base terrain
var _mountain_noise: FastNoiseLite  # broad ridged uplift
var _cave_cheese: FastNoiseLite     # 3D blob/cavern noise
var _cave_worm_a: FastNoiseLite     # 3D winding tunnel field A
var _cave_worm_b: FastNoiseLite     # 3D winding tunnel field B


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


# --- Public API -------------------------------------------------------------

## Pure per-block generation: (world_x, world_y, world_z, seed) -> block id.
func generate_block(wx: int, wy: int, wz: int) -> int:
	return _block_at(wx, wy, wz, {}, {})


## Terrain surface height (top solid block y) for a column. Deterministic.
func surface_height(wx: int, wz: int) -> int:
	var base := float(Constants.SEA_LEVEL) + 2.0 + _height_noise.get_noise_2d(wx, wz) * 9.0
	# Ridged noise squashed & squared: mostly flat, occasional bold mountains.
	var m := maxf(0.0, _mountain_noise.get_noise_2d(wx, wz))
	base += pow(m, 2.4) * 30.0
	return clampi(int(floor(base)), 2, Constants.CHUNK_SIZE_Y - 8)


## Fills a whole chunk's flat block array. Same results as calling
## generate_block for every cell, but with per-column caching of heights and
## tree data (the leaves pass samples a 5x5 column neighborhood, so caching
## matters a lot here).
## PERF: this is the hottest generation path (~16k blocks + 3D cave noise per
## chunk). It runs on worker threads. If it ever becomes the bottleneck, port
## this file to C# or GDExtension — the algorithm translates 1:1.
func generate_chunk_data(cpos: Vector2i) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(Constants.CHUNK_SIZE_X * Constants.CHUNK_SIZE_Y * Constants.CHUNK_SIZE_Z)

	var hcache := {}
	var tcache := {}
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
func _block_at(wx: int, wy: int, wz: int, hcache: Dictionary, tcache: Dictionary) -> int:
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
		var sandy := h <= Constants.BEACH_HEIGHT
		if wy == h:
			return BlockTypes.SAND if sandy else BlockTypes.GRASS
		if wy >= h - 3:
			return BlockTypes.SAND if sandy else BlockTypes.DIRT
		return BlockTypes.STONE

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


func _cached_height(wx: int, wz: int, hcache: Dictionary) -> int:
	var key := Vector2i(wx, wz)
	if hcache.has(key):
		return hcache[key]
	var h := surface_height(wx, wz)
	hcache[key] = h
	return h


## Tree height for a column (0 = no tree). Trees only grow on grass tops
## (above the beach line), placed by a deterministic integer hash so tree
## positions are stable per seed without extra noise instances.
func _cached_tree_height(wx: int, wz: int, hcache: Dictionary, tcache: Dictionary) -> int:
	var key := Vector2i(wx, wz)
	if tcache.has(key):
		return tcache[key]
	var th := 0
	var h := _cached_height(wx, wz, hcache)
	if h > Constants.BEACH_HEIGHT and h < Constants.CHUNK_SIZE_Y - 12:
		if _hash01(wx, wz, world_seed) < Constants.TREE_CHANCE:
			# Make sure the trunk base isn't hovering over a carved cave mouth.
			if not _is_cave(wx, h, wz, h):
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
##    branching tunnels.
## PERF: 3D noise per underground block is the expensive part of generation
## (~3 samples per block below the surface). If needed: early-out on the
## cheapest field, or sample on a coarse 4^3 grid and trilinearly interpolate.
func _is_cave(wx: int, wy: int, wz: int, surface_h: int) -> bool:
	if wy <= 1:
		return false  # keep the bedrock floor + one stone layer intact
	if wy > surface_h - Constants.CAVE_MIN_DEPTH:
		return false  # never carve within a few blocks of the surface

	# 0 at bedrock -> 1 near the surface; deeper = lower threshold = more caves.
	var depth_frac := clampf(float(wy) / float(Constants.SEA_LEVEL), 0.0, 1.0)

	var cheese := _cave_cheese.get_noise_3d(wx, wy, wz)
	if cheese > lerpf(0.38, 0.62, depth_frac):
		return true

	var a := absf(_cave_worm_a.get_noise_3d(wx, wy, wz))
	if a < 0.065:
		var b := absf(_cave_worm_b.get_noise_3d(wx, wy, wz))
		if b < 0.065:
			return true
	return false


## Deterministic integer hash -> [0, 1). Stable across runs and platforms.
func _hash01(x: int, z: int, s: int) -> float:
	var h := x * 374761393 + z * 668265263 + s * 2246822519
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)
