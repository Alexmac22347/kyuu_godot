## heightmaps come from https://manticorp.github.io/unrealheightmap.
## pixel values range from 0 to 1. when creating a heightmap, it will say the min/max values.
## make sure to record this value in a text file or something because its different per height map.
extends Node

const HEIGHTMAP_PATH: String = "res://assets/heightmaps/vancouver_downtown/49_257_-123_183_15_4094_4094_16bit.png"
const OUTPUT_FOLDER: String = "res://assets/terrain/vancouver_downtown/"
const HEIGHT_SCALE: float = 130.0
const CELL_SIZE: float = 1.0

## the size of a single chunk in meters.
## each meter of the heighmap is 1 pixel
const SMALLEST_CHUNK_SIZE: int = 256
## the number of pixels to skip when generating a chunk.
## higher number means lower detail.
#const LOD_DIVIDERS: Array[int] = [1,2,4,8,16]
const LOD_DIVIDERS: Array[int] = [1,2]


func _ready():
	generate_heightmap()

## TODO: optimize away flat areas.
## TODO: remove ocean?
func generate_heightmap() -> void:
	var img: Image = Image.new()
	var err = img.load(HEIGHTMAP_PATH)
	if err != OK:
		push_error("Failed to load heightmap: %s" % HEIGHTMAP_PATH)
		return
	
	var width: int = img.get_width()
	var height: int = img.get_height()
	
	for lod_divider in LOD_DIVIDERS:
		var lod_size: int = lod_divider * SMALLEST_CHUNK_SIZE
		for chunk_x in range(0, width, lod_size):
			for chunk_y in range(0, height, lod_size):
				if (chunk_x+lod_size >= width ) || (chunk_y+lod_size >= height):
					continue
				generate_chunk(img, chunk_x, chunk_y, lod_divider, lod_size);


func generate_chunk(img: Image, x: int, y: int, lod_divider: int, lod_size: int) -> void:
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
			var h00 = img.get_pixel(pixel_x, pixel_y).r * HEIGHT_SCALE
			var h10 = img.get_pixel(pixel_x + lod_divider, pixel_y).r * HEIGHT_SCALE
			var h01 = img.get_pixel(pixel_x, pixel_y + lod_divider).r * HEIGHT_SCALE
			var h11 = img.get_pixel(pixel_x + lod_divider, pixel_y + lod_divider).r * HEIGHT_SCALE
			
			# lets skip oceans
			if (h00 == 0
				and h10 == 0 
				and h01 == 0 
				and h11 == 0):
				continue;
			
			# reset chunk position back to (0,0).
			var triangle_width: float = CELL_SIZE * lod_divider
			@warning_ignore("narrowing_conversion")
			var x0: int = (pixel_x * triangle_width) - x
			@warning_ignore("narrowing_conversion")
			var y0: int = (pixel_y * triangle_width) - y
			
			## Two triangles per cell
			st.add_vertex(Vector3(x0, h00, y0))
			st.add_vertex(Vector3(x0 + triangle_width, h10, y0))
			st.add_vertex(Vector3(x0, h01, y0 + triangle_width))

			st.add_vertex(Vector3(x0 + triangle_width, h10, y0))
			st.add_vertex(Vector3(x0 + triangle_width, h11, y0 + triangle_width))
			st.add_vertex(Vector3(x0, h01, y0 + triangle_width))
			
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var filename_resource: String = "%s.res" % chunk_id
	var output_path: String = OUTPUT_FOLDER.path_join(filename_resource)
	ResourceSaver.save(mesh, output_path)
	return
