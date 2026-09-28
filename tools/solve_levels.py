"""Comprueba que los niveles de scripts/levels.gd tienen solución.

Modelo simplificado de la física: al cambiar la gravedad, el cubo se desliza
casilla a casilla hasta chocar con una pared. Si pasa por la salida gana;
si pasa por un peligro (pinchos o láser) muere.

Uso: python tools/solve_levels.py
"""

import re
from collections import deque
from pathlib import Path

LEVELS_FILE = Path(__file__).resolve().parent.parent / "scripts" / "levels.gd"
HAZARDS = {"^", "=", "|"}
DIRS = {"arriba": (0, -1), "abajo": (0, 1), "izquierda": (-1, 0), "derecha": (1, 0)}


def parse_levels(text):
    levels = []
    for block in re.findall(r'"name":\s*"([^"]*)".*?"map":\s*\[(.*?)\]', text, re.S):
        name, body = block
        levels.append((name, re.findall(r'"([^"]*)"', body)))
    return levels


def slide(grid, pos, d):
    """Devuelve (posición final, resultado) con resultado en {None, 'win', 'dead'}."""
    x, y = pos
    while True:
        nx, ny = x + d[0], y + d[1]
        cell = grid[ny][nx]
        if cell == "#":
            return (x, y), None
        x, y = nx, ny
        if cell == "E":
            return (x, y), "win"
        if cell in HAZARDS:
            return (x, y), "dead"


def solve(grid):
    start = next((x, y) for y, row in enumerate(grid) for x, c in enumerate(row) if c == "P")
    start, result = slide(grid, start, DIRS["abajo"])
    if result:
        return result, [], 0
    queue = deque([(start, [])])
    seen = {start}
    deaths = 0
    while queue:
        pos, path = queue.popleft()
        for name, d in DIRS.items():
            new_pos, result = slide(grid, pos, d)
            if result == "win":
                return "win", path + [name], len(seen)
            if result == "dead":
                deaths += 1
                continue
            if new_pos not in seen:
                seen.add(new_pos)
                queue.append((new_pos, path + [name]))
    return "unsolvable", [], len(seen)


def main():
    ok = True
    for i, (name, grid) in enumerate(parse_levels(LEVELS_FILE.read_text(encoding="utf-8")), 1):
        widths = {len(row) for row in grid}
        if len(widths) != 1:
            print(f"{i}. {name}: ERROR filas de distinto ancho {widths}")
            ok = False
            continue
        border = grid[0] + grid[-1] + "".join(row[0] + row[-1] for row in grid)
        if set(border) != {"#"}:
            print(f"{i}. {name}: ERROR el borde del mapa no está cerrado")
            ok = False
            continue
        result, path, states = solve(grid)
        if result == "win":
            print(f"{i}. {name}: {len(path)} movimientos -> {', '.join(path)}  ({states} posiciones)")
        else:
            print(f"{i}. {name}: SIN SOLUCION ({result})")
            ok = False
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
