extends Node2D

@onready var tiles = $Tiles
@onready var tile_scene = preload("res://scenes/tile.tscn")
@onready var puzzleManager = $PuzzleManager
var main_menu_scene = preload("res://ui/MainMenu.tscn")
var settings_scene = preload("res://ui/SettingsMenu.tscn")
var win_screen_scene = preload("res://ui/win_screen.tscn")

func _ready():
	puzzleManager.tile_root = $Tiles
	puzzleManager.request_main_menu.connect(_show_main_menu)
	puzzleManager.puzzle_solved.connect(_show_win_screen)
	_show_main_menu()

func _show_main_menu():
	clear_all_ui()
	
	var menu = main_menu_scene.instantiate()
	menu.name = "MainMenu"
	add_child(menu)
	
	menu.author_pressed.connect(_on_author_pressed)
	menu.play_pressed.connect(_on_play_pressed)
	menu.settings_pressed.connect(_on_settings_pressed)

func _show_win_screen():
	clear_all_ui()
	spawn_confetti()
	
	await get_tree().create_timer(0.4).timeout
	
	var win = win_screen_scene.instantiate()
	win.name = "WinScreen"
	add_child(win)
	
	win.back_pressed.connect(_show_main_menu)
	
	# get the root Control node inside the CanvasLayer
	var win_root = win.get_child(0)
	win_root.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(win_root, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)

func spawn_confetti():
	var particles = CPUParticles2D.new()
	get_tree().root.add_child(particles)
	
	particles.global_position = get_viewport().get_visible_rect().size / 2
	particles.z_index = 100
	
	# emission
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8  # burst vs stream, 1.0 = all at once
	particles.amount = 200
	particles.lifetime = 3.0
	
	# spread
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(get_viewport().get_visible_rect().size.x / 2, 10)
	particles.direction = Vector2(0, 1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	
	# spin
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	
	# appearance
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color_ramp = _make_confetti_gradient()
	
	# clean up after done
	await get_tree().create_timer(particles.lifetime + 1.0).timeout
	particles.queue_free()

func _make_confetti_gradient() -> Gradient:
	var g = Gradient.new()
	g.colors = [Color.RED, Color.YELLOW, Color.CYAN, Color.GREEN, Color.MAGENTA, Color.ORANGE]
	g.offsets = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
	return g

func _on_author_pressed():
	clear_all_ui()
	puzzleManager.author_mode()

func _on_play_pressed():
	clear_all_ui()
	puzzleManager.play_mode()

func _on_settings_pressed():
	clear_all_ui()
	show_settings()

func clear_all_ui():
	for child in get_children():
		if child is CanvasLayer:
			child.queue_free()

func show_settings():
	clear_all_ui()
	var settings = settings_scene.instantiate()
	settings.name = "SettingsUI"
	add_child(settings)
	settings.back_pressed.connect(_show_main_menu)
	
