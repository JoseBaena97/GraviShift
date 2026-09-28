# GraviShift

Juego de puzles en 2D para Android hecho con **Godot 4**. Tienes que llevar un cubo de energía hasta la salida, pero no lo mueves tú: cambias la dirección de la gravedad. Hay dos formas de hacerlo:

- **Deslizar:** desliza el dedo y la gravedad gira hacia esa dirección (arriba, abajo, izquierda o derecha).
- **Inclinar:** la gravedad sigue la inclinación real del móvil, usando el acelerómetro.

## Cómo ejecutarlo

1. Instala [Godot 4](https://godotengine.org/download) (versión estándar, no la de .NET).
2. Abre Godot, pulsa **Importar** y selecciona `project.godot`.
3. Pulsa **F5** para jugar en el PC.

### Controles en el PC

| Tecla | Acción |
|---|---|
| Flechas / WASD | Cambiar la gravedad |
| Arrastrar con el ratón | Deslizar (simula el dedo) |
| R | Reiniciar el nivel |
| T | Cambiar entre deslizar e inclinar |
| Esc | Pausa |

## Estructura

```
scenes/
  menu.tscn          Menú principal y selector de niveles
  main.tscn          Partida: nivel, cubo, cámara, HUD y pausa
  cube.tscn          El cubo (RigidBody2D)
  background.tscn    Fondo con degradado compartido
scripts/
  game.gd            Autoload: progreso guardado, opciones, cambio de escena
  audio.gd           Autoload: buses de audio, efectos y zumbido de láseres
  sfx_synth.gd       Sintetizador: genera los efectos de sonido por código
  menu.gd            Menú y fondo animado
  main.gd            Bucle de juego, entrada, gravedad, HUD y pausa
  level.gd           Construye y dibuja un nivel a partir de un mapa de texto
  levels.gd          Datos de los niveles
  cube.gd            Cubo: estela, deformación y teletransporte seguro
  pause_button.gd    Icono de pausa dibujado por código
ui/
  theme.tres         Tema visual de los botones
tools/
  solve_levels.py    Comprueba que todos los niveles tienen solución
```

## Cómo funciona

- **Gravedad global:** en lugar de empujar el cubo, se cambia la gravedad de todo el espacio físico con `PhysicsServer2D.area_set_param(..., AREA_PARAM_GRAVITY_VECTOR, dir)`. Así, cualquier objeto físico que se añada después (por ejemplo, partículas de fluido) la seguirá sin código extra.
- **Niveles como texto:** cada nivel es un mapa ASCII (`#` pared, `P` inicio, `E` salida, `^` pinchos, `=` y `|` láseres). Las paredes contiguas se fusionan en rectángulos grandes para reducir el número de colisiones y que el cubo no se enganche en las juntas.
- **Validación de niveles:** `python tools/solve_levels.py` simula el juego sobre una cuadrícula y hace una búsqueda en anchura (BFS) para asegurar que cada nivel tiene solución. También muestra la solución más corta.
- **Sonido sintetizado:** los efectos no son archivos: `SfxSynth` genera las ondas al arrancar (osciladores, barridos de frecuencia exponenciales, envolventes y ruido filtrado) y las convierte en `AudioStreamWAV`. Cada efecto se reproduce con una ligera variación de tono, el golpe suena más fuerte cuanto más rápido choca el cubo y el zumbido de los láseres aumenta al acercarse.
- **Inclinación suavizada:** la lectura del acelerómetro pasa por un filtro exponencial que no depende de los FPS, y una zona muerta ignora el sensor cuando el móvil está casi en horizontal.

## Hoja de ruta

- [x] Prototipo: cubo, paredes, salida, pinchos y 5 niveles
- [x] Control por deslizamiento, inclinación y teclado
- [x] Exportación y pruebas en un móvil Android
- [x] Menú principal, selector de niveles y guardado del progreso
- [x] Estilo neón: estela de partículas, deformación del cubo, láseres, portal animado
- [x] HUD con contador de giros (shifts), tiempo y pausa
- [x] Efectos de sonido sintetizados por código
- [ ] Música
- [ ] Más mecánicas: interruptores, bloques móviles, portales
- [ ] Fluido de energía con partículas y shader de *metaballs*
- [ ] Publicación en itch.io o Google Play
