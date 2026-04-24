extends CanvasLayer
signal back_pressed

func _ready():
	%BackButton.pressed.connect(back_pressed.emit)
	load_settings()
	_update_button_visuals()

func _update_button_visuals():
	%DefaultPaletteButton.button_pressed = ColourPalette.current_palette == ColourPalette.Palette.DEFAULT
	%DeuPaletteButton.button_pressed = ColourPalette.current_palette == ColourPalette.Palette.DEUTERANOPIA
	%ProPaletteButton.button_pressed = ColourPalette.current_palette == ColourPalette.Palette.PROTANOPIA
	%TriPaletteButton.button_pressed = ColourPalette.current_palette == ColourPalette.Palette.TRITANOPIA
	%ContrastPaletteButton.button_pressed = ColourPalette.current_palette == ColourPalette.Palette.HIGH_CONTRAST

func _on_default_palette_button_pressed():
	_on_palette_selected(ColourPalette.Palette.DEFAULT)

func _on_pro_palette_button_pressed():
	_on_palette_selected(ColourPalette.Palette.PROTANOPIA)

func _on_deu_palette_button_pressed():
	_on_palette_selected(ColourPalette.Palette.DEUTERANOPIA)

func _on_tri_palette_button_pressed():
	_on_palette_selected(ColourPalette.Palette.TRITANOPIA)

func _on_contrast_palette_button_pressed():
	_on_palette_selected(ColourPalette.Palette.HIGH_CONTRAST)

func _on_palette_selected(palette):
	ColourPalette.set_palette(palette)
	save_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("accessibility", "palette", ColourPalette.current_palette)
	config.save("user://settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var palette = config.get_value("accessibility", "palette", 0)
		ColourPalette.set_palette(palette)
