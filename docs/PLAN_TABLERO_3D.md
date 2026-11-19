# AEVUM · Plan del Tablero 3D (documento de traspaso · v2)

Resume todo lo acordado para migrar el tablero 2D de AEVUM a 3D, el estado real de la rama y lo que sigue.
Sirve para retomar el trabajo en un chat nuevo sin perder contexto. **Sustituye a la versión anterior del documento.**

---

## 0. Prompt para retomar en un chat nuevo

> Estoy migrando el tablero de mi juego de cartas AEVUM (Roblox, Rojo) de GUI 2D a 3D.
> Repo público: https://github.com/Second0709/AEVUM-TESTING-1 — rama de trabajo **`3D-implement`** (clónala con git; la web de GitHub bloquea la lectura directa).
> Lee `docs/PLAN_TABLERO_3D.md` completo y abre `docs/referencia/aevum_tablero_v2.html` (es la referencia visual aprobada: "mucho mejor").
> Estamos en el **Parche 1** (sección 8). Antes de escribir código, repasa la sección 9 (errores ya cometidos) y respeta las convenciones de la sección 10.
> Entrega los cambios como parche de git (`git format-patch`) y comprueba que aplica sobre la rama.

---

## 1. Estado real de la rama `3D-implement`

Commits sobre `main`: Fase 1 (templo estático, cámara adaptable) · cartas 3D + animaciones + entrada táctil · archivos de prueba.
Código en `src/StarterPlayerScripts/AEVUM/UI3D/`:

| Módulo | Qué hace hoy |
|---|---|
| `Layout.luau` | Posiciones puras (casillas, cristales, mazos, cementerios, orbe) y `cameraFit`. Probado en `tests/Layout.spec.luau`. |
| `Motion.luau` | Pistas de animación **puras** (estado `{x,y,z,flip,tilt,scale}`, tramos con `to` fijo o "vivo", arco, easing, `delay`, `onEnd`). Probado en `tests/Motion.spec.luau`. |
| `BoardBuilder.luau` | Construye el templo (233 partes, 7 luces, 17 neones que pulsan), zonas táctiles invisibles por casilla, marcadores de casilla y la iluminación local. |
| `CameraRig.luau` | Cámara `Scriptable` (FOV 45°, inclinación 58°) que ajusta la distancia a la proporción de pantalla. |
| `CardView.luau` | Modelo 3D de carta con pool (40 instancias por carta): cuerpo de oro, `SurfaceGui` frontal y reverso, anillo `SelectionBox`. |
| `Input3D.luau` | Toque/clic con raycast (tolerancia de arrastre 14 px; la GUI 2D tiene prioridad). |
| `Board3D.luau` | Reconciliador **por uid** que compara el `view` nuevo con el anterior y lanza las animaciones. Devuelve `render, show, hide, api`. |

Cambios fuera de `UI3D/`: `Config.Client = { Board3D, Quality }`, `Main.server` (`CharacterAutoLoads = false` si hay 3D), `AevumClient` (fondo transparente, cableado mano 2D ↔ 3D, tocar casilla vacía para colocar), `Hand.luau` (registra botones y deja hueco mientras la carta 3D aterriza), `RightPanel.luau` (atacantes en orden fijo: Banca de izquierda a derecha, luego Combate).

### Animaciones ya implementadas (11 flujos, detectadas por uid, sin usar `events`)
Mano → Banca · Banca → Combate (con volteo si se revela) · volteo en sitio · deslizar de casilla · evolución (bump + la carta de la mano se funde con la criatura) · robar del mazo a la mano · robo del rival (del mazo a su borde) · tablero → mano · tablero → cementerio · carta de mano → cementerio (descarte/evolución fallida) · desaparecer.
**Nota:** ninguna regla actual devuelve una carta del tablero a la mano; esa animación existe pero hoy no la dispara nada.

### Lo que todavía NO existe
Disco de turno · barreras · divisor central · entorno (torres, pozos, pedestales) · ataque directo · bloqueo (choque) · vida diferida hasta el impacto · efecto de muerte · hechizo activado · pila y carrusel del cementerio · detalle grande de carta al tocar · skins de arena.

---

## 2. Hechos verificados del repo (servidor autoritativo)

- `Match.luau` decide todo. El cliente dibuja el `view` (por `Remotes.State`) y envía acciones por `Remotes.Action`.
- `view.me` completo; `view.opp`: Banca `{uid, faceDown=true}`, Combate con `cardId`. Mano rival = solo un número. Casillas vacías = `false`.
- **Banca = cartas boca abajo para el rival**; la propia se ve (`cardId` en tu Banca). **Combate = reveladas.** `DeclareAttack` mueve de Banca a Combate al instante (primera casilla libre, en el orden de la lista de atacantes). Hechizos: se activan desde la Banca (`ActivateSlow`/`ActivateFast`).
- `PlayCard { uid, slot? }`: el `Validator` **ya acepta `slot`** (1..BenchSlots, libre). Sin `slot`, el servidor usa la primera libre.
- **Evolución**: `Evolve { form, target }` conserva el **mismo uid** y solo cambia `cardId` (la carta de la mano desaparece de la mano).
- **Cementerio** (`graveyard`) = lista de **`cardId`**, no de instancias. Descartes de mano y evoluciones fallidas también van ahí.
- Objetivos válidos: `view.activatable[].targets` `{side, zone, slot}`; zonas `Avatar | Combat | Bench | Hand`. El avatar se apunta con `tryTarget(side, "Avatar", 0, nil)`.
- Estados de espera (`view.waiting.kind`): `Actions, Response, AttackResponse, FastWindow, AttackDeclare, AttackEvolve, Block, Discard`.
- `view.attack = { attackers, blocks, mode }`; `view.attackerIdx` = quién tiene el derecho de ataque (el cliente 3D **aún no lo lee**).
- `view.events = { {id, kind} }` (hoy `BlockKill`, `Overkill`): **sin uid, zona ni slot** → no sirven para animar sobre una carta concreta hasta ampliarlos.
- Reglas (`Config.Match`): 20 de vida, mazo 40, 5 casillas de Banca y 5 de Combate, mano máx. 8, energía máx. 6, reserva máx. 2, acción 30 s.
- Las 20 cartas comparten el mismo `art` (`rbxassetid://125379581550088`); cada carta tiene `text` (descripción), `type`, `cost`, `atk`, `hp`, `speed`, `evolveFrom`.
- La UI 2D (`Hand`, `LeftPanel`, `RightPanel`, banners, toasts) se mantiene; el tablero 2D se conserva con `Config.Client.Board3D = false`.

---

## 3. Decisiones tomadas

| Tema | Decisión |
|---|---|
| Colores de bando | **Rojo/coral = rival, azul = jugador** (como el disco original). Sustituye al cian/rosa de la Fase 1. |
| Personaje de Roblox | Oculto. Solo tablero y cartas. |
| Plataformas | Móvil y PC por igual. |
| Dónde se construye | En el cliente. El jugador local siempre en +Z, el rival en -Z. El índice de casilla 1 queda a la izquierda para ambos. |
| Cristales | **Se quedan en la columna lateral izquierda**, entre Combate y Banca (se descartó ponerlos en los extremos centrales: demasiado arriesgado para la visualización). |
| Mazo y cementerio | Columna derecha. Mazo a la altura de la Banca, cementerio a la de Combate. |
| Banca propia / rival | La tuya se ve **boca arriba** para ti; la del rival **boca abajo** hasta que ataca. Las cartas reveladas del rival se ven **derechas hacia ti**. |
| Disco central | Copia el `.orbe` de la referencia original: círculo partido por una línea horizontal, **mitad superior roja (rival), inferior azul (tú)**, línea blanca y punto blanco. La mitad de quien tiene el derecho de ataque **brilla y pulsa**; la otra baja a ~45 % de brillo. No lleva manecilla. Se alimenta de `view.attackerIdx`. |
| Barreras | Una por bando, **detrás de la Banca**, bajas (~1 stud) y translúcidas para no tapar la Banca propia. Caben sin alargar la mesa (Banca llega a ~15.6, marco a ~18.5; barrera a ~17). |
| Ataque directo | La carta **vuela en línea recta por su columna** contra la barrera rival, que se ilumina con efecto de **cristal quebrado**; desde el impacto **fluyen pulsos** por los surcos hasta el cristal rival (destello, temblor, número de daño). La carta vuelve a su casilla. Pulso proporcional al ATK. |
| Bloqueo | La carta embiste a su bloqueador y chocan (mismo sistema; después). |
| Cartas | Cara **mínima**: arte a todo el alto + **ATK (abajo izq.) y VIDA (abajo der.) en grande** + etiqueta corta de estado ("ATACA", "BLOQUEA", "[lista]", "[en preparación]"). Sin nombre, costo ni descripción en la carta. |
| Detalle | Al tocar **cualquier carta visible** (propia o rival revelada) se muestra una **carta grande vertical** con nombre, costo, arte, ATK/VIDA y `text`. Tocar sigue seleccionando/apuntando como hoy. Las boca abajo del rival no muestran detalle. Propuesta: panel fijo junto al tablero (no tapa nada al elegir objetivos). |
| Mano | 2D mientras se elige; la carta pasa a 3D al colocarse. Robar y devolver vuelan hacia/desde la posición del botón de la mano. |
| Cementerio | **Pila de cartas que crece**; al tocarla abre un **carrusel 2D** (más legible). Después: poder devolver cartas al campo/mano (ver sección 7). |
| Interacción | Con una carta de la mano seleccionada se iluminan las casillas libres de Banca; tocarla coloca (`PlayCard` con `slot`). Al declarar ataque se marcan las casillas de Combate donde entrarán los atacantes. Tocar el vacío cancela. |
| Estilo | Detalle en el **entorno** que rodea el campo (torres, pozos, pedestales), campo de poco contraste, baldosas grabadas, divisor central con identidad propia. Ver sección 4. |
| Calidad | Opción manual. Baja = sin brillos animados, sin luces, sin sombras, sin partículas. |
| Técnica | Todo con `Part`s y materiales de Roblox. Mallas de Blender solo si hace falta (ver sección 11). |

---

## 4. Diseño objetivo de la arena (referencia: `docs/referencia/aevum_tablero_v2.html`)

Abre ese HTML: es la maqueta aprobada. Traducción a Roblox:

- **Skins como paletas intercambiables** (MTG Arena tiene arenas temáticas): `Ruinas` (crema/verde, **recomendada como base**: la queja principal fue lo oscuro), `Circuito` (cian con rejilla) y `Templo` (violeta/oro). Una tabla `Palette` por skin (suelo, baldosa, borde, resplandor, marco, color del divisor, rojo/azul de bando) en `Config.Client.Skin`. **Decisión pendiente del usuario: con cuál skin empezar.**
- **Entorno > campo.** El suelo de juego es liso y de poco contraste para que las cartas destaquen. El detalle va en los bordes: 4 torres hexagonales bajas en las esquinas (una sola luz cada una), pozos y pedestales, luciérnagas (solo calidad alta).
- **Baldosas grabadas, 1 pieza por casilla.** El grabado (octógono en Banca, círculo en Combate, línea del color del bando) se dibuja en un `SurfaceGui` sobre la placa. Hoy cada casilla cuesta 6 partes; objetivo: ≤ ~130 partes en total (hoy 233).
- **Divisor central**: "río de luz" animado a lo ancho (en las referencias: lava, río, puente, línea de luz), con el **disco de turno** encima.
- **Cristales**: facetados (no cubos), sobre plinto, con medallón de vida pequeño (número ~20) en lugar del letrero gigante. Contadores de mazo/cementerio discretos sobre las pilas.
- **Mazo** = pedestal con cartas apiladas y resplandor del color del bando. **Cementerio** = pozo con remolino y pila de cartas encima.
- **Barreras** = panel bajo con franjas verticales y glifos, en el color del bando; el panel de la barrera aloja el `SurfaceGui` de grietas.
- **Iluminación más clara**: ambiente más alto, sol alto (no rasante), bloom suave, atmósfera ligera. Quitar el suelo de roca de 600×600 (textura Basalt) por una superficie lisa.
- **Mano del rival**: abanico de reversos asomando por el borde superior (como MTG Arena); su mano es solo un número.

Constantes actuales de `Layout`: carta 4×5.6; `SLOT_PITCH` 5; `ROW_COMBAT` 5.6; `ROW_BENCH` 12.8; `SIDE_X` 17.5; `CARD_Y` 0.6; `SEL_LIFT` 0.9; `HOVER_Y` 2.8; `PILE_Y` 0.95; `ORB_Y` 4. Origen de la mesa en el Workspace: `(0, 500, 0)`. Región de pantalla libre para el tablero: x 0.15–0.83, y 0.08–0.76.

### Legibilidad (el reto más difícil)
A 1080p una carta mide ~72 px de ancho. Con la mesa entera en pantalla, esperar 80–90 px como mucho. La legibilidad la dan los **números gigantes de ATK/VIDA (~30 px de alto)** y el **detalle al tocar**, no el tamaño. Ayudas: bajar la inclinación de cámara de 58° a ~46° y apretar espacios para ganar tamaño (recalcular `cameraFit`).

---

## 5. Cartas 3D: especificación del Parche 1

1. **Orientación determinista.** Hoy el `SurfaceGui` va en la cara `Top` suponiendo hacia dónde apunta el "arriba" del texto; el usuario reporta caras **horizontales y estiradas**. Corregir usando una cara cuya orientación es conocida: una pieza fina cuya cara `Front` (normal −Z) apunta a +Y y cuyo "arriba" apunta a −Z (lo que lee la cámara en +Z). Rotación propuesta: `CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.pi / 2, 0, 0)`. **Verificar en Studio** y dejar una constante para corregirla si saliera al revés. El canvas debe tener la misma proporción que la cara física.
2. **Cara mínima** (arte + ATK + VIDA + etiqueta corta). Menos instancias por carta (hoy 40).
3. **Reveladas del rival derechas hacia el jugador.**
4. **Detalle al tocar** con carta grande (panel 2D fijo; reutilizar el render de carta 2D si ayuda).
5. El reverso mantiene el rombo del color del bando (rojo/azul).

---

## 6. Animaciones y combate (Parche 4)

- **Ataque directo** (decisión de la sección 3). Requiere en `Match.luau`: evento `DirectHit { uid atacante, side, damage, absorbed }` (ver sección 7).
- **La vida debe retrasarse**: el `view` llega con el resultado ya aplicado; el número de vida y la barra del cristal se actualizan al llegar el pulso, no antes.
- **Pulsos**: salen del punto de impacto, recorren la base de la barrera hasta la columna lateral y suben al cristal. Hay que **añadir un surco** barrera → cristal (hoy no existe). Pulso en cadena si atacan varias cartas (orden de declaración).
- **Cristal de grietas**: líneas procedurales en un `SurfaceGui` sobre el panel de la barrera (barato en móvil); se desvanecen en ~1 s. En calidad baja, solo destello. Idea opcional (no incluida): acumular grietas según la vida.
- **Bloqueo**: embestida al bloqueador + choque.
- **Muerte con efecto**, **hechizo activado**, **evolución más vistosa**.
- Camino largo: columna 5 → cristal izquierdo ≈ 35 studs, ~0.5–0.6 s con pulso.

---

## 7. Cambios de servidor y reglas pendientes (pasar por `Validator.luau`, con pruebas en `Match.spec.luau`)

1. **Evento `DirectHit`** en `emit()` (uid del atacante, bando, daño, escudo absorbido). Los eventos actuales no traen uid.
2. **Revivir desde el cementerio** (Parche 5): el cementerio guarda `cardId`, así que revivir **crea una instancia nueva con uid nuevo**. Propuesta de efecto: `{ kind = "Revive", to = "Bench" | "Combat" | "Hand", count = 1, filter? }`, con objetivo en zona `Graveyard` (slot = índice). El carrusel del cementerio sirve de selector. Decidir reglas: ¿entra "preparada"? ¿coste? Primer caso real que dispara la animación "tablero → mano" y "cementerio → casilla".
3. No inventar acciones nuevas sin pasar por `Validator`.

---

## 8. Plan de parches (criterio de terminado de cada uno: partida completa contra el bot sin errores en Output)

1. **Parche 1 — Cartas y arena limpia**
   a) Bugs: discos con `Shape = Cylinder`, cristal facetado, orientación de cara, zonas táctiles sin estorbar.
   b) Cartas: cara mínima + detalle al tocar + reveladas del rival derechas.
   c) Arena: paleta por skin, baldosas de 1 pieza con `SurfaceGui`, quitar letreros gigantes/franjas de neón/suelo de roca, iluminación clara, torres, divisor, pedestal de mazo y pozo de cementerio.
   d) Disco de turno (mitades roja/azul) alimentado por `view.attackerIdx`.
   e) Barreras estáticas + surco barrera → cristal.
   f) Reencuadre de cámara (pitch ~46°, espacios más justos).
   Dos commits: (b) y (c–f), porque comparten el cálculo de cámara.
2. **Parche 2 — Pila y carrusel del cementerio** (solo cliente).
3. **Parche 3 — Ataque directo y combate** (evento `DirectHit`, vida diferida, pulsos, grietas, bloqueo).
4. **Parche 4 — Revivir desde el cementerio** (regla de servidor + animaciones).
5. **Parche 5 — Pulido**: sonidos (jugar, revelar, ataque, daño, muerte, curación, escudo, turno), partículas por tipo de efecto, arte por carta (el equipo lo produce: ilustración sin texto 4:3, 1024×768 PNG, mientras tanto la imagen provisional), calidad baja, menú de ajustes (volumen y calidad; guardar en cliente primero).

---

## 9. Errores ya cometidos (no repetir)

- **Discos que salían cuadrados**: se giró el cilindro (`CFrame.Angles(0,0,pi/2)`) pero **no se activó `Shape = Enum.PartType.Cylinder`**. Revisar toda pieza redonda.
- Suponer la orientación de un `SurfaceGui` sin verificarla → texto horizontal/estirado.
- Letreros `BillboardGui` enormes y `AlwaysOnTop` que se pisan con la mesa.
- Mucha geometría repetitiva por casilla (6 partes × 20) → ruido y coste.
- Paleta demasiado oscura/rústica frente a la referencia original (luminosa).
- Hacer `render` que borra y recrea todo: el 3D reconcilia por uid o no habrá animaciones.
- Mutar una tabla mientras se recorre con `pairs` dentro de callbacks de animación: usar `task.defer` para `requestRender`.
- `ctx.fn and ctx.fn(x)` trunca los retornos múltiples: llamar `a, b = ctx.fn(x)` explícitamente.
- Los resultados de `luau` CLI: las globales son de solo lectura (ver `tests/smoke`).

---

## 10. Convenciones del repo y flujo de trabajo

- Cabecera `--!nonstrict` y comentario `-- AEVUM · <descripción> (vX.Y.Z)` (versión actual de la rama: v1.3.0, sin subir hasta fusionar).
- Indentación con **tabs**. Comentarios en español.
- Datos compartidos en `ReplicatedStorage/AEVUM`; lo exclusivo del servidor en `ServerScriptService/AEVUM`.
- Los `.luau` de UI no llevan `.meta.json`.
- **Claude no puede ejecutar Roblox Studio ni subir al repo.** Entrega parches (`git format-patch`) que se aplican con `git am` en la rama, y comprueba que aplican limpio sobre ella. Rojo (`rojo serve`) sincroniza con Studio. Se prueba en Studio contra el bot (`ServerConfig.Bot.Enabled = true`).
- Ante un fallo, enviar el mensaje completo de Output con la línea y, si es visual, una captura.
- **Pruebas sin Studio** (ejecutar antes de entregar cualquier parche):
  - `luau tests/Match.spec.luau` · `luau tests/Layout.spec.luau` · `luau tests/Motion.spec.luau`
  - `python3 tests/smoke/run.py [ruta a luau]`: simula la API mínima de Roblox y ejecuta los escenarios de `Board3D` (jugar, robar, avanzar con volteo, cementerio, devolver, evolución, partida nueva). Si UI3D usa API nueva, ampliar `tests/smoke/_stubs.luau`.
  - Obtener `luau`: `curl -sL -o luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip && unzip luau.zip`.
- Mantener los nombres de acciones y la validación de `Validator.luau`.

---

## 11. Riesgos y decisiones abiertas

- **Skin con la que empezar** (recomendada: Ruinas). Pendiente de confirmar por el usuario.
- **Límite de `Part`s**: no se consigue una silueta de gema real; cristales y torres saldrán estilizados. Si se quiere la riqueza de los ejemplos de Master Duel, encargar modelos en Blender (cristal, torres, pedestales) más adelante.
- **Rendimiento en móvil**: ≤ ~130 partes, pocas luces, pool de cartas, calidad baja.
- **Texto ilegible en cartas pequeñas**: mitigado con cara mínima + detalle al tocar.
- **Conflicto de toques** GUI 2D / raycast 3D: la GUI consume el toque primero (`gameProcessed`).
- **Cristal cercano vs. mano 2D**: la mano ocupa la parte baja de la pantalla; todo el tablero debe quedar dentro de la región libre.
- **Eventos sin datos** hasta añadir `DirectHit`.

---

## 12. Referencias visuales

- **`docs/referencia/aevum_tablero_v2.html`** — maqueta interactiva aprobada (skins, disco, barrera, ataque directo en línea recta + pulso, carrusel del cementerio, tocar para ver detalle). Probar los botones de la cabecera.
- Original del usuario: `aevum_tablero_original` (HTML con el `.orbe` de dos mitades, paleta crema/oro/menta, coral y azul).
- 19 capturas de MTG Arena (arenas: lava, desierto, bosque con río, madera embrujada, trigal, filigrana dorada, mapa, aldea, sci-fi, laboratorio, plaza de piedra, místico, neón morado), Yu-Gi-Oh! Master Duel (ciudad nocturna, ruinas de selva, sci-fi con ventiladores) y Legends of Runeterra (Grieta del Invocador, tablero de Freljord/Noxus). Conclusiones: el detalle vive en el entorno que rodea el campo; el campo es de poco contraste; cada arena tiene un divisor propio; las casillas tienen identidad (baldosas grabadas); mazo y cementerio son objetos físicos (pedestales, pozos); en Runeterra el cristal con su número y la ficha de ataque en el divisor central son el centro de cada bando. (Si se quieren conservar, añadirlas a `docs/referencia/`.)
