extends AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 已有的导入缓存尚未刷新时，也保证背景音乐循环播放。
	if stream is AudioStreamMP3:
		stream.loop = true

func _exit_tree() -> void:
	stop()
	stream = null
