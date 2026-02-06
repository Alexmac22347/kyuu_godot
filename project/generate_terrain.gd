## heightmaps come from https://manticorp.github.io/unrealheightmap.
## absolutely no texturing is done here in order to preserve vram.
## thats because the same texture can be used for multiple chunks.
extends Node

const HEIGHTMAP_PATH: String = "res://assets/heightmaps/vancouver/"
const OUTPUT_FOLDER: String = "res://assets/terrain/vancouver/"
const HEIGHT_SCALE: float = 1.0
const AREA_SCALE: float = 50.0
const WATER_CUTOFF: float = -10

## the size of a single chunk in meters.
## each meter of the heighmap is 1 pixel
const SMALLEST_CHUNK_SIZE: int = 256
## the number of pixels to skip when generating a chunk.
## higher number means lower detail.
const LOD_DIVIDERS: Array[int] = [1,2,4,8,16]


func _ready():
	generate_heightmap()

func generate_heightmap() -> void:
	## TODO: optimize away flat areas.

	## First step is to create a big ass array
	## of heights using the exr heightmap files.
	## from there we can generate the meshes.
	var raw_pixel_values: Array = generate_pixel_values_from_heightmap_folder(HEIGHTMAP_PATH)

	var height: int = raw_pixel_values.size()
	var width: int = raw_pixel_values[0].size()

	for lod_divider in LOD_DIVIDERS:
		var lod_size: int = lod_divider * SMALLEST_CHUNK_SIZE
		for chunk_x in range(0, width, lod_size):
			for chunk_y in range(0, height, lod_size):
				if (chunk_x+lod_size >= width ) || (chunk_y+lod_size >= height):
					continue
				generate_chunk(raw_pixel_values, chunk_x, chunk_y, lod_divider, lod_size)

func generate_pixel_values_from_heightmap_folder(heightmap_folder: String) -> Array:
	## turn all those exr files into one big 2D array of heights
	var dir: DirAccess = DirAccess.open(heightmap_folder)
	if !dir:
		return []

	var regex = RegEx.new()
	regex.compile("bit_tile_(\\d+)_(\\d+)\\.exr$")

	## first just get the size of a single .exr image and how many images
	## there are in the x and y direction.
	dir.list_dir_begin()
	var tile_width_pixels: int = 0
	var tile_height_pixels: int = 0
	var max_tile_y_offset: int = 0
	var max_tile_x_offset: int = 0
	var file_name = dir.get_next()
	while file_name != "":
		if !file_name.ends_with(".exr"):
			file_name = dir.get_next()
			continue
		if tile_width_pixels == 0 && tile_height_pixels == 0:
			var img: Image = Image.new()
			img.load(heightmap_folder+file_name)
			tile_width_pixels = img.get_width()
			tile_height_pixels = img.get_height()
		var regex_result = regex.search(file_name)
		var tile_y_offset: int = regex_result.get_string(1).to_int()
		var tile_x_offset: int = regex_result.get_string(2).to_int()
		if tile_y_offset > max_tile_y_offset:
			max_tile_y_offset = tile_y_offset
		if tile_x_offset > max_tile_x_offset:
			max_tile_x_offset = tile_x_offset
		file_name = dir.get_next()
	dir.list_dir_end()

	## initialize the array
	var pixel_array: Array[Array]
	pixel_array.resize(tile_height_pixels*max_tile_y_offset)
	for i in range(pixel_array.size()):
		pixel_array[i] = []
		pixel_array[i].resize(tile_width_pixels*max_tile_x_offset)

	print("initialized pixel array with size ", pixel_array.size(), " x ", pixel_array[1111].size())

	dir.list_dir_begin()
	file_name = dir.get_next()
	while file_name != "":
		if !file_name.ends_with(".exr"):
			file_name = dir.get_next()
			continue

		var regex_result = regex.search(file_name)
		## the files use 1 based indexing, need to subtract 1 to convert to 0 based.
		var tile_y_offset: int = regex_result.get_string(1).to_int() - 1
		var tile_x_offset: int = regex_result.get_string(2).to_int() - 1

		var img: Image = Image.new()
		img.load(heightmap_folder+file_name)
		print("loaded image: ", file_name)

		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var true_y: int = (tile_y_offset*tile_height_pixels) + y
				var true_x: int = (tile_x_offset*tile_width_pixels) + x
				var pixel: Color = img.get_pixel(x,y)
				pixel_array[true_y][true_x] = pixel.r
		file_name = dir.get_next()

	dir.list_dir_end()
	return pixel_array

func generate_chunk(pixel_values: Array[Array], x: int, y: int, lod_divider: int, lod_size: int) -> void:
	var chunk_index_denominator = lod_divider*SMALLEST_CHUNK_SIZE
	@warning_ignore("integer_division")
	var chunk_id: String = "%d_%d_lod%d" % [x/chunk_index_denominator, y/chunk_index_denominator, lod_divider]
	print("preparing chunk: ", chunk_id)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# for each chunk
	# create a mesh using the image,
	# and skip over lod_divider vertices
	# make sure the mesh has its top left corner at 0,0
	for pixel_x in range(x, x+lod_size, lod_divider):
		for pixel_y in range(y, y+lod_size, lod_divider):
			var h00: float = pixel_values[pixel_y][pixel_x] * HEIGHT_SCALE
			var h10: float = pixel_values[pixel_y + lod_divider][pixel_x] * HEIGHT_SCALE
			var h01: float = pixel_values[pixel_y][pixel_x + lod_divider] * HEIGHT_SCALE
			var h11: float = pixel_values[pixel_y + lod_divider][pixel_x + lod_divider] * HEIGHT_SCALE

			if (h00 <= WATER_CUTOFF
				and h10 <= WATER_CUTOFF
				and h01 <= WATER_CUTOFF
				and h11 <= WATER_CUTOFF):
				continue;

			# reset chunk position back to (0,0).
			var triangle_width: float = AREA_SCALE * lod_divider
			@warning_ignore("narrowing_conversion")
			var x0: int = (pixel_x * triangle_width) - x
			@warning_ignore("narrowing_conversion")
			var y0: int = (pixel_y * triangle_width) - y

			# uv coordinates, just one for each corner of the
			var uv00: Vector2 = Vector2(x0, y0)
			var uv10: Vector2 = Vector2(x0+triangle_width, y0)
			var uv01: Vector2 = Vector2(x0, y0+triangle_width)
			var uv11: Vector2 = Vector2(x0+triangle_width, y0+triangle_width)

			## Two triangles per cell
			st.set_uv(uv00)
			st.add_vertex(Vector3(x0, h00, y0))
			st.set_uv(uv01)
			st.add_vertex(Vector3(x0 + triangle_width, h10, y0))
			st.set_uv(uv10)
			st.add_vertex(Vector3(x0, h01, y0 + triangle_width))

			st.set_uv(uv10)
			st.add_vertex(Vector3(x0 + triangle_width, h10, y0))
			st.set_uv(uv11)
			st.add_vertex(Vector3(x0 + triangle_width, h11, y0 + triangle_width))
			st.set_uv(uv01)
			st.add_vertex(Vector3(x0, h01, y0 + triangle_width))

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var filename_resource: String = "%s.res" % chunk_id
	var output_path: String = OUTPUT_FOLDER.path_join(filename_resource)
	ResourceSaver.save(mesh, output_path)
	return
