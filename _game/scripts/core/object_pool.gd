## Purpose: Generic object pool — reuse nodes to avoid per-bullet/enemy instantiate and queue_free.
extends RefCounted
class_name ObjectPool

var _scene: PackedScene
var _parent: Node
var _pool: Array[Node] = []

func setup(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
	_scene = scene
	_parent = parent
	for i: int in prewarm:
		var obj: Node = _create()
		obj.visible = false
		_pool.append(obj)

func acquire() -> Node:
	for obj: Node in _pool:
		if not obj.visible:
			obj.visible = true
			return obj
	return _create()

func release(obj: Node) -> void:
	obj.visible = false
	if not _pool.has(obj):
		_pool.append(obj)

func _create() -> Node:
	var obj: Node = _scene.instantiate()
	_parent.add_child(obj)
	return obj

func active_count() -> int:
	var count: int = 0
	for obj: Node in _pool:
		if obj.visible:
			count += 1
	return count

func pool_size() -> int:
	return _pool.size()
