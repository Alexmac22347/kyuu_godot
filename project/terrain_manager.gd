extends Node3D

@export var heightmap_path: String = "res://assets/heightmaps/falklands/-51_775_-59_436_12_13000_9000.png"
@export var output_folder: String = "res://assets/terrain/falklands/"
@export var height_scale: float = 10.0
@export var cell_size: float = 1.0

const SMALLEST_CHUNK_SIZE: int = 256
#const LOD_DIVIDERS: Array[int] = [1,2,4,8,16]
const LOD_DIVIDERS: Array[int] = [8]



func _ready():
	load_terrain_from_disk()
	return
	## generate_heightmap()

func load_terrain_from_disk() -> void:
	var lod_divider: int = 8
	for x in range(6):
		for y in range(4):
			var terrain_path: String = "res://assets/terrain/falklands"
			var mesh_id: String = "%d_%d_lod%d" % [x,y,lod_divider]
			var mesh_path: String = terrain_path.path_join(mesh_id) + ".res"
			if ResourceLoader.exists(mesh_path):
				var mesh_resource: ArrayMesh = load(mesh_path)
				var mesh_instance: MeshInstance3D = MeshInstance3D.new()
				mesh_instance.name = mesh_id
				mesh_instance.mesh = mesh_resource
				mesh_instance.position = Vector3(
					x*SMALLEST_CHUNK_SIZE*lod_divider,
					0,
					y*SMALLEST_CHUNK_SIZE*lod_divider)

## TODO: optimize away flat areas.
## TODO: remove ocean?
func generate_heightmap() -> void:
	var img: Image = Image.new()
	var err = img.load(heightmap_path)
	if err != OK:
		push_error("Failed to load heightmap: %s" % heightmap_path)
		return
	
	var width: int = img.get_width()
	var height: int = img.get_height()
	
	for lod_divider in LOD_DIVIDERS:
		var lod_size: int = lod_divider * SMALLEST_CHUNK_SIZE
		for chunk_x in range(0, width, lod_size):
			for chunk_y in range(0, height, lod_size):
				if (chunk_x+lod_size >= width ) || (chunk_y+lod_size >= height):
					continue
				
				var chunk_index_denominator = lod_divider*SMALLEST_CHUNK_SIZE
				var chunk_id: String = "%d_%d_lod%d" %[chunk_x/chunk_index_denominator, chunk_y/chunk_index_denominator, lod_divider]
				print("preparing chunk: ", chunk_id)
				var st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				
				# for each chunk	
				# create a mesh using the image,
				# and skip over lod_divider vertices
				# make sure the mesh has its top left corner at 0,0
				for pixel_x in range(chunk_x, chunk_x+lod_size, lod_divider):
					for pixel_y in range(chunk_y, chunk_y+lod_size, lod_divider):
					
						var h00: int = img.get_pixel(pixel_x, pixel_y).r * height_scale
						var h10: int = img.get_pixel(pixel_x + lod_divider, pixel_y).r * height_scale
						var h01: int = img.get_pixel(pixel_x, pixel_y + lod_divider).r * height_scale
						var h11: int = img.get_pixel(pixel_x + lod_divider, pixel_y + lod_divider).r * height_scale
						
						# reset chunk position back to (0,0).
						var triangle_width: float = cell_size * lod_divider
						var x0: int = (pixel_x * triangle_width) - chunk_x
						var y0: int = (pixel_y * triangle_width) - chunk_y
						
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
				var output_path: String = output_folder.path_join(filename_resource)
				ResourceSaver.save(mesh, output_path)
