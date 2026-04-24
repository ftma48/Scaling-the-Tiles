extends Node

enum Palette { DEFAULT, DEUTERANOPIA, PROTANOPIA, TRITANOPIA, HIGH_CONTRAST }

var current_palette := Palette.DEFAULT

var palettes := {
	Palette.DEFAULT: {
		"red":    Color("#FF6B6B"),
		"blue":   Color("#FFD93D"),
		"green":  Color("#6BCB77"),
		"yellow": Color("#4D96FF")
	},
	Palette.DEUTERANOPIA: {
		"red":    Color("#D55E00"),
		"blue":   Color("#F0E442"),
		"green":  Color("#009E73"),
		"yellow": Color("#0072B2")
	},
	Palette.PROTANOPIA: {
		"red":    Color("#FF7F50"),
		"blue":   Color("#FFE066"),
		"green":  Color("#2DB27D"),
		"yellow": Color("#1F77D0")
	},
	Palette.TRITANOPIA: {
		"red":    Color("#E4572E"),
		"blue":   Color("#F3A712"),
		"green":  Color("#59C3C3"),
		"yellow": Color("#3B4CC0")
	},
	Palette.HIGH_CONTRAST: {
		"red":    Color("#D7263D"),
		"blue":   Color("#F4D35E"),
		"green":  Color("#2EC4B6"),
		"yellow": Color("#3A86FF")
	}
}

func get_colour(name: String) -> Color:
	return palettes[current_palette].get(name, Color.WHITE)

func set_palette(palette: Palette):
	current_palette = palette
