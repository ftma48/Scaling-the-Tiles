extends Area2D

@export var sideColours = {
	"north" = ["red"],
	"east" = ["blue"],
	"south" = ["green"],
	"west" = ["yellow"]
}

#func _ready():

func _ready():
	var northColour = sideColours["north"] 
	var eastColour = sideColours["east"]
	var southColour = sideColours["south"]
	var westColour = sideColours["west"]
