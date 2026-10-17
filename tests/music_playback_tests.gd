extends Node

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var track := Music.stream as AudioStreamMP3
	check(is_instance_valid(track) and track.loop, "background music has looping enabled")
	var duration := track.get_length()
	print("Track duration: %.2f seconds" % duration)
	check(duration > 0, "background music resource is playable")
	# Seek near the end instead of waiting for the whole song to finish.
	Music.play(maxf(0, duration - 0.1))
	await get_tree().create_timer(0.45).timeout
	check(Music.playing, "music continues playing after the end of the song")
	check(Music.playing and Music.get_playback_position() < duration - 0.1, "music wraps playback to the beginning")
	get_tree().paused = true
	await get_tree().create_timer(0.15).timeout
	check(Music.can_process() and Music.playing, "music keeps playing while result screen pauses game")
	get_tree().paused = false
	var bus := AudioServer.get_bus_index("Music")
	var previous_mute := AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, true)
	await get_tree().create_timer(0.1).timeout
	check(AudioServer.is_bus_mute(bus), "music setting can mute looping background music")
	AudioServer.set_bus_mute(bus, previous_mute)
	print("RESULT: %d/%d music checks passed" % [checks - failures, checks])
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
