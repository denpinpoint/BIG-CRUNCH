class_name ResourcePacks
## Discovers texture resource packs. A pack is just a folder of 16x16 PNGs
## named per the BlockTypes.tile_names() contract; any present file overrides
## that atlas tile (see block_library._apply_resource_pack).
##
## Packs are searched in two roots, user:// first so they work in an exported
## game without touching the repo:
##   user://resource_packs/<name>/     (drop your own here)
##   res://resource_packs/<name>/      (bundled with the project)
##
## We ship NO third-party textures. The game's default look is the procedural
## atlas; a pack lets you substitute textures you legally own. On first run a
## "_template" pack is written to user:// with every tile at its correct
## filename so you have a starting point (block_library._dump_template_pack).

const ROOT_USER := "user://resource_packs"
const ROOT_RES := "res://resource_packs"


## "None" plus every discovered pack folder (underscore-prefixed folders like
## _template are hidden from the picker but still loadable by name).
static func list() -> Array[String]:
	var out: Array[String] = ["None"]
	for root: String in [ROOT_USER, ROOT_RES]:
		if not DirAccess.dir_exists_absolute(root):
			continue
		for d: String in DirAccess.get_directories_at(root):
			if d.begins_with("_") or d.begins_with("."):
				continue
			if not out.has(d):
				out.append(d)
	return out


## Absolute directory for a pack name, or "" if it doesn't resolve.
static func pack_dir(pack_name: String) -> String:
	if pack_name == "" or pack_name == "None":
		return ""
	for root: String in [ROOT_USER, ROOT_RES]:
		var path := "%s/%s" % [root, pack_name]
		if DirAccess.dir_exists_absolute(path):
			return path
	return ""
