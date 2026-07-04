class_name Constants
## Central place for every tunable number in the game. No magic numbers
## elsewhere — if you want to rebalance or resize something, do it here.
##
## Coordinate conventions (used EVERYWHERE, do not deviate):
##  * World space:   Vector3  (floats). 1 block = 1x1x1 world unit.
##  * Block space:   Vector3i (integers). Block (x, y, z) occupies the world
##                   AABB from (x, y, z) to (x+1, y+1, z+1).
##  * Chunk space:   Vector2i (integers). A chunk is a full-height column of
##                   CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z blocks.
##                   Chunk (cx, cz) starts at block (cx*CHUNK_SIZE_X, 0, cz*CHUNK_SIZE_Z).
##  * Local space:   Vector3i inside a chunk, x in [0, SIZE_X), y in [0, SIZE_Y),
##                   z in [0, SIZE_Z).

# --- Chunk dimensions -------------------------------------------------------
const CHUNK_SIZE_X: int = 16
const CHUNK_SIZE_Y: int = 64  # world height; y=0 is bedrock
const CHUNK_SIZE_Z: int = 16

# --- World / streaming ------------------------------------------------------
const RENDER_DISTANCE: int = 8          # chunks (radius) around the player
const UNLOAD_DISTANCE: int = RENDER_DISTANCE + 2
const DEFAULT_SEED: int = 1337
const MESH_APPLY_BUDGET_USEC: int = 6000  # max time per frame spent attaching finished chunks

# --- Terrain ----------------------------------------------------------------
const SEA_LEVEL: int = 22
const BEACH_HEIGHT: int = SEA_LEVEL + 1  # columns at/below this get sand tops
const CAVE_MIN_DEPTH: int = 6            # caves only carve this far below the surface
const TREE_CHANCE: float = 0.02          # per grass column

# --- Player -----------------------------------------------------------------
const GRAVITY: float = 28.0
const TERMINAL_VELOCITY: float = 50.0
const JUMP_VELOCITY: float = 8.4         # clears a bit over 1.25 blocks
const WALK_SPEED: float = 4.5
const SPRINT_SPEED: float = 5.9
const CROUCH_SPEED: float = 1.8
const FLY_SPEED: float = 10.0
const FLY_SPRINT_SPEED: float = 20.0
const MOUSE_SENSITIVITY: float = 0.0022
const EYE_HEIGHT: float = 1.62           # player is ~1.8 units tall
const REACH: float = 5.0                 # block interaction distance
const SAFE_FALL_BLOCKS: float = 3.0      # fall damage starts past this distance
const PLAYER_ATTACK_DAMAGE: float = 4.0
const PLAYER_ATTACK_COOLDOWN: float = 0.4
const PLACE_REPEAT_DELAY: float = 0.25
const CREATIVE_BREAK_DELAY: float = 0.2
const BREAK_TIME_PER_HARDNESS: float = 0.45  # seconds of mining per hardness point

# --- Survival stats ---------------------------------------------------------
const MAX_HEALTH: float = 20.0
const MAX_HUNGER: float = 20.0
const HUNGER_DRAIN_PER_SEC: float = 0.02        # ~1 point / 50 s idle
const HUNGER_SPRINT_DRAIN_PER_SEC: float = 0.10 # extra while sprinting
const HUNGER_REGEN_THRESHOLD: float = 18.0      # health regens when hunger >= this
const HEALTH_REGEN_PER_SEC: float = 0.5
const STARVE_DAMAGE_PER_SEC: float = 0.5
const SPRINT_MIN_HUNGER: float = 6.0

# --- Day / night ------------------------------------------------------------
const DAY_LENGTH_SEC: float = 600.0  # full day-night cycle
const START_TIME_OF_DAY: float = 0.35  # 0 = midnight, 0.5 = noon

# --- Mobs -------------------------------------------------------------------
const MOB_GLOBAL_CAP: int = 18
const PASSIVE_MOB_CAP: int = 8
const HOSTILE_MOB_CAP: int = 10
const MOB_SPAWN_INTERVAL: float = 2.0
const MOB_SPAWN_ATTEMPTS_PER_TICK: int = 8  # spawn budget so spawning can't hitch a frame
const MOB_SPAWN_RING_MIN: float = 20.0      # blocks from player
const MOB_SPAWN_RING_MAX: float = 44.0
const MOB_MIN_PLAYER_DISTANCE: float = 16.0
const MOB_DESPAWN_DISTANCE: float = 80.0
const HOSTILE_CAVE_DEPTH: int = 6  # blocks below the surface counts as "dark cave"


# --- Coordinate helpers -----------------------------------------------------

## World-space position -> block coordinate that contains it.
static func world_to_block(p: Vector3) -> Vector3i:
	# floor() first: Vector3i(Vector3) truncates toward zero, which is wrong
	# for negative coordinates.
	return Vector3i(p.floor())


## Block coordinate -> chunk coordinate that contains it (floor division).
static func block_to_chunk(b: Vector3i) -> Vector2i:
	return Vector2i(
		floori(float(b.x) / float(CHUNK_SIZE_X)),
		floori(float(b.z) / float(CHUNK_SIZE_Z))
	)


## Block coordinate -> chunk-local coordinate (y passes through unchanged).
static func block_to_local(b: Vector3i) -> Vector3i:
	return Vector3i(posmod(b.x, CHUNK_SIZE_X), b.y, posmod(b.z, CHUNK_SIZE_Z))


## Chunk-local coordinate -> index into the chunk's flat PackedByteArray.
## Layout: index = x + y * SIZE_X + z * SIZE_X * SIZE_Y, i.e. x varies fastest,
## then y, then z. One full vertical slab of 16*64 entries per z step.
static func local_block_index(l: Vector3i) -> int:
	return l.x + l.y * CHUNK_SIZE_X + l.z * CHUNK_SIZE_X * CHUNK_SIZE_Y


## True if a local coordinate is inside chunk bounds.
static func local_in_bounds(l: Vector3i) -> bool:
	return (
		l.x >= 0 and l.x < CHUNK_SIZE_X
		and l.y >= 0 and l.y < CHUNK_SIZE_Y
		and l.z >= 0 and l.z < CHUNK_SIZE_Z
	)
