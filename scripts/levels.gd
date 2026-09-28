class_name Levels
extends RefCounted

## Definición de niveles como mapas de texto.
##   #  pared
##   .  vacío
##   P  posición inicial del cubo
##   E  salida
##   ^  pinchos (reinician el nivel); se clavan en la pared vecina
##   =  láser horizontal
##   |  láser vertical
##
## La gravedad empieza siempre hacia abajo.

const DATA := [
	{
		"name": "Primeros pasos",
		"hint": "Desliza el dedo para cambiar la gravedad",
		"map": [
			"#########",
			"#P......#",
			"#######.#",
			"#E......#",
			"#########",
		],
	},
	{
		"name": "Cuatro direcciones",
		"hint": "La gravedad también puede ir hacia arriba",
		"map": [
			"#########",
			"#.....#E#",
			"#.###.#.#",
			"#.#P..#.#",
			"#.#####.#",
			"#.......#",
			"#########",
		],
	},
	{
		"name": "Pinchos",
		"hint": "Los pinchos te devuelven al inicio",
		"map": [
			"#########",
			"#P.#...^#",
			"#..#.####",
			"#..#....#",
			"#.....#E#",
			"#########",
		],
	},
	{
		"name": "Laberinto",
		"hint": "",
		"map": [
			"###########",
			"#P#.....#E#",
			"#.#.###.#.#",
			"#...#^#...#",
			"###.#.#.#.#",
			"#^..#.....#",
			"#.###.###.#",
			"#.........#",
			"###########",
		],
	},
	{
		"name": "Láseres",
		"hint": "Los láseres también son peligrosos",
		"map": [
			"###########",
			"#P..|.....#",
			"#.###.###.#",
			"#...#...#E#",
			"###.#=#.#.#",
			"#.........#",
			"###########",
		],
	},
	{
		"name": "Descenso",
		"hint": "",
		"map": [
			"###########",
			"#E....#..^#",
			"####..#...#",
			"#^.......##",
			"#.###.#...#",
			"#...#.#.#.#",
			"#.#.#...#.#",
			"#.#.#####.#",
			"#...^....P#",
			"###########",
		],
	},
]
