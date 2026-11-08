extends Node2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var skeleton: Skeleton2D = $Skeleton2D

func _ready() -> void:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_NONE

	for i in range(1, 7):
		var bone_name := "spike%d" % i
		var bone: Bone2D = skeleton.get_node(bone_name)
		var original_pos := bone.position

		# 使用 position 平移
		var track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath("Skeleton2D/%s:position" % bone_name))
		var delay := (i - 1) * 0.03
		anim.track_insert_key(track, delay + 0.0, original_pos)
		anim.track_insert_key(track, delay + 0.15, original_pos + Vector2(0, -100))
		anim.track_insert_key(track, delay + 0.3, original_pos)

		# 如果要用 scale，改成：
		# anim.track_set_path(track, NodePath("Skeleton2D/%s:scale" % bone_name))
		# anim.track_insert_key(track, delay + 0.0, Vector2(1, 0))
		# anim.track_insert_key(track, delay + 0.15, Vector2(1, 1))
		# anim.track_insert_key(track, delay + 0.3, Vector2(1, 0))

	anim_player.add_animation("spike_attack", anim)
	anim_player.play("spike_attack")
