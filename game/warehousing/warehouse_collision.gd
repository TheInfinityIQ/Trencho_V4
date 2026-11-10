extends RefCounted
## Exact Artist collider proxies, converted Blender(x,y,z) -> Godot(x,z,-y).
## delivery_manifest_v01.json shell_dimensions; render meshes exclude proxies.
const BOXES: Array[Dictionary] = [
	{"group":"Floor","position":Vector3(0.000000,-0.100000,-0.000000),"size":Vector3(12.000000,0.200000,16.000000)},
	{"group":"Shared_Frame","position":Vector3(-5.850000,2.450000,7.850000),"size":Vector3(0.300000,4.900000,0.300000)},
	{"group":"Shared_Frame","position":Vector3(-5.850000,2.450000,-7.850000),"size":Vector3(0.300000,4.900000,0.300000)},
	{"group":"Shared_Frame","position":Vector3(5.850000,2.450000,7.850000),"size":Vector3(0.300000,4.900000,0.300000)},
	{"group":"Shared_Frame","position":Vector3(5.850000,2.450000,-7.850000),"size":Vector3(0.300000,4.900000,0.300000)},
	{"group":"Boundary_Back","position":Vector3(0.000000,2.450000,7.900000),"size":Vector3(11.400000,4.900000,0.200000)},
	{"group":"Boundary_Right","position":Vector3(5.900000,2.450000,-0.000000),"size":Vector3(0.200000,4.900000,15.400000)},
	{"group":"Boundary_Left","position":Vector3(-5.900000,2.450000,-0.000000),"size":Vector3(0.200000,4.900000,15.400000)},
	{"group":"Boundary_Front","position":Vector3(-3.975000,2.450000,-7.900000),"size":Vector3(3.450000,4.900000,0.200000)},
	{"group":"Boundary_Front","position":Vector3(-2.125000,2.000000,-7.850000),"size":Vector3(0.250000,4.000000,0.300000)},
	{"group":"Boundary_Front","position":Vector3(3.975000,2.450000,-7.900000),"size":Vector3(3.450000,4.900000,0.200000)},
	{"group":"Boundary_Front","position":Vector3(2.125000,2.000000,-7.850000),"size":Vector3(0.250000,4.000000,0.300000)},
	{"group":"Boundary_Front","position":Vector3(0.000000,4.450000,-7.850000),"size":Vector3(4.500000,0.900000,0.300000)},
	{"group":"Roof","position":Vector3(-4.150000,5.260000,-0.000000),"size":Vector3(3.700000,0.880000,15.960000)},
	{"group":"Roof","position":Vector3(-2.150000,4.860000,-0.000000),"size":Vector3(0.300000,0.080000,15.960000)},
	{"group":"Roof","position":Vector3(-0.150000,5.260000,-0.000000),"size":Vector3(3.700000,0.880000,15.960000)},
	{"group":"Roof","position":Vector3(1.850000,4.860000,-0.000000),"size":Vector3(0.300000,0.080000,15.960000)},
	{"group":"Roof","position":Vector3(3.850000,5.260000,-0.000000),"size":Vector3(3.700000,0.880000,15.960000)},
	{"group":"Roof","position":Vector3(5.850000,4.860000,-0.000000),"size":Vector3(0.300000,0.080000,15.960000)},
]
