class_name SaveMath
extends RefCounted
## Helpers that turn vectors and transforms into compact JSON-friendly number
## lists, rounded so save files stay small and readable.


static func pack_floats(values: PackedFloat32Array, step: float) -> Array:
	var out: Array = []
	out.resize(values.size())
	for i in range(values.size()):
		out[i] = snappedf(values[i], step)
	return out


static func unpack_floats(values: Variant) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not values is Array:
		return out
	var list: Array = values
	out.resize(list.size())
	for i in range(list.size()):
		out[i] = float(list[i])
	return out


static func pack_vec3(values: PackedVector3Array, step: float) -> Array:
	var out: Array = []
	out.resize(values.size() * 3)
	for i in range(values.size()):
		var v: Vector3 = values[i]
		out[i * 3] = snappedf(v.x, step)
		out[i * 3 + 1] = snappedf(v.y, step)
		out[i * 3 + 2] = snappedf(v.z, step)
	return out


static func unpack_vec3(values: Variant) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not values is Array:
		return out
	var list: Array = values
	var count: int = list.size() / 3
	out.resize(count)
	for i in range(count):
		out[i] = Vector3(float(list[i * 3]), float(list[i * 3 + 1]), float(list[i * 3 + 2]))
	return out


## Basis columns then origin: 12 numbers.
static func pack_transform(t: Transform3D) -> Array:
	var out: Array = []
	for v in [t.basis.x, t.basis.y, t.basis.z, t.origin]:
		var vec: Vector3 = v
		out.append(snappedf(vec.x, 0.0001))
		out.append(snappedf(vec.y, 0.0001))
		out.append(snappedf(vec.z, 0.0001))
	return out


static func unpack_transform(values: Variant) -> Transform3D:
	if not values is Array or (values as Array).size() != 12:
		return Transform3D.IDENTITY
	var f: Array = values
	var bx := Vector3(float(f[0]), float(f[1]), float(f[2]))
	var by := Vector3(float(f[3]), float(f[4]), float(f[5]))
	var bz := Vector3(float(f[6]), float(f[7]), float(f[8]))
	var origin := Vector3(float(f[9]), float(f[10]), float(f[11]))
	return Transform3D(Basis(bx, by, bz), origin)
