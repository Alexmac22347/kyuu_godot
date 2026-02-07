## heightmaps come from https://manticorp.github.io/unrealheightmap.
## DO NOT ASSUME ALL IMAGE SAME DIMENSIONS
## absolutely no texturing is done here in order to preserve vram.
## thats because the same texture can be used for multiple chunks.
## EXR format:
## Pixel space is a 2D coordinate system with x increasing from left to right
## and y increasing from top to bottom.
## pixels are data samples, taken at integer coordinate locations in pixel space.
## (https://download.nvidia.com/developer/GPU_Gems/CD_Image/Image_Processing/OpenEXR/OpenEXR-1.0.6/doc/)
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
#const LOD_DIVIDERS: Array[int] = [1,2,4,8,16]
const LOD_DIVIDERS: Array[int] = [1,4,16]


func _ready():
	generate_heightmap()

func generate_heightmap() -> void:
	## TODO: optimize away flat areas.

	## First step is to create a big ass array
	## of heights using the exr heightmap files.
	## from there we can generate the meshes.
	var raw_pixel_values: Array = generate_pixel_values_from_heightmap_folder(HEIGHTMAP_PATH)

	var width: int = raw_pixel_values.size()
	var height: int = raw_pixel_values[0].size()

	for lod_divider in LOD_DIVIDERS:
		var lod_size: int = lod_divider * SMALLEST_CHUNK_SIZE
		for chunk_x in range(0, width, lod_size):
			for chunk_y in range(0, height, lod_size):
				if (chunk_x+lod_size >= width ) || (chunk_y+lod_size >= height):
					continue
				generate_chunk(raw_pixel_values, chunk_x, chunk_y, lod_divider, lod_size)

## returns 2D array of pixel values
## retval[row][column]. 0,0 is the upper left corner.
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
	var file_width_pixels: int = 0
	var file_height_pixels: int = 0
	var num_files_x: int = 0
	var num_files_y: int = 0
	var file_name = dir.get_next()
	while file_name != "":
		if !file_name.ends_with(".exr"):
			file_name = dir.get_next()
			continue
		if file_width_pixels == 0 && file_height_pixels == 0:
			var img: Image = Image.new()
			img.load(heightmap_folder+file_name)
			file_width_pixels = img.get_width()
			file_height_pixels = img.get_height()
		var regex_result = regex.search(file_name)
		## the second coord is left/right/width on the file names
		## i know this because the falklands heightmap is a lot wider than it is tall,
		## and the second coord goes up to 20 (as opposed to 10)
		var file_x_offset_1based: int = regex_result.get_string(2).to_int()
		var file_y_offset_1based: int = regex_result.get_string(1).to_int()
		if file_x_offset_1based > num_files_x:
			num_files_x = file_x_offset_1based
		if file_y_offset_1based > num_files_y:
			num_files_y = file_y_offset_1based
		file_name = dir.get_next()
	dir.list_dir_end()

	## initialize the array
	var pixel_array: Array[Array]
	pixel_array.resize(file_width_pixels*num_files_x)
	for i in range(pixel_array.size()):
		pixel_array[i] = []
		pixel_array[i].resize(file_height_pixels*num_files_y)

	print("pixel array width: ", pixel_array.size(), " height: ", pixel_array[0].size())

	dir.list_dir_begin()
	file_name = dir.get_next()
	while file_name != "":
		if !file_name.ends_with(".exr"):
			file_name = dir.get_next()
			continue

		var regex_result = regex.search(file_name)
		## the files use 1 based indexing, need to subtract 1 to convert to 0 based.
		var file_y_offset: int = regex_result.get_string(1).to_int() - 1
		var file_x_offset: int = regex_result.get_string(2).to_int() - 1

		var img: Image = Image.new()
		img.load(heightmap_folder+file_name)

		if file_x_offset == 9 and file_y_offset == 0:
			var alex = true

		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var true_x: int = (file_x_offset*file_width_pixels) + x
				var true_y: int = (file_y_offset*file_height_pixels) + y
				if true_x == 2048:
					var bob = true

				var pixel: Color = img.get_pixel(x,y)

				pixel_array[true_x][true_y] = pixel.r
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
			var h00: float = pixel_values[pixel_x][pixel_y] * HEIGHT_SCALE
			var h10: float = pixel_values[pixel_x + lod_divider][pixel_y] * HEIGHT_SCALE
			var h01: float = pixel_values[pixel_x][pixel_y + lod_divider] * HEIGHT_SCALE
			var h11: float = pixel_values[pixel_x + lod_divider][pixel_y + lod_divider] * HEIGHT_SCALE

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

	## this is for debugging, i should not apply materials to the mesh.
	var material = StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/textures/grass_81/grass_81_128.png")
	material.roughness = 0.8
	material.metallic = 0.0

	mesh.surface_set_material(0, material)

	var filename_resource: String = "%s.res" % chunk_id
	var output_path: String = OUTPUT_FOLDER.path_join(filename_resource)
	ResourceSaver.save(mesh, output_path)
	return
