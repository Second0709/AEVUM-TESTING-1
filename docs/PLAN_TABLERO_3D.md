# AEVUM · Plan del Tablero 3D (documento de traspaso)

Este documento resume todo lo acordado para migrar el tablero 2D (GUI) de AEVUM a 3D.
Sirve para retomar el trabajo en un chat nuevo sin perder contexto.

---

## 0. Prompt para retomar en un chat nuevo

> Estoy migrando el tablero de mi juego de cartas AEVUM (Roblox, Rojo) de GUI 2D a 3D.
> Repo público: https://github.com/Second0709/AEVUM-TESTING-1 (clónalo con git, la web de GitHub bloquea lectura directa).
> Lee `docs/PLAN_TABLERO_3D.md` del repo: contiene las decisiones, la arquitectura y las fases.
> Estamos en la **Fase N**. Continúa desde ahí y respeta las convenciones del repo.

---

## 1. Hechos verificados del repo

- **Servidor autoritativo.** `Match.luau` decide todo. El cliente solo dibuja el `view` que recibe por `Remotes.State` y envía acciones por `Remotes.Action`.
- **El `view` ya viene filtrado por jugador:** `view.me` (completo) y `view.opp` (banca boca abajo: `{uid, faceDown=true}`, combate con `cardId`).
- **Casillas vacías = `false`**, no `nil`.
- **Banca = cartas boca abajo** (criaturas y hechizos). `PlayCard` las coloca ahí; el `slot` es opcional (si no se manda, el servidor usa la primera libre). La UI actual **no** envía slot.
- **Combate = cartas reveladas.** Una criatura de Banca pasa a Combate cuando se declara el ataque (`DeclareAttack`), y en ese momento se revela. Los hechizos se activan desde la Banca (`ActivateSlow` / `ActivateFast`).
- **Evolución:** `Evolve { form, target }`, la carta de evolución sale de la mano y apunta a una criatura propia en Combate.
- **Objetivos válidos** vienen de `view.activatable[].targets` con `{side, zone, slot}`; zonas: `Avatar | Combat | Bench | Hand`.
- **Estados de espera** (`view.waiting.kind`): `Actions`, `Response`, `AttackResponse`, `FastWindow`, `AttackDeclare`, `AttackEvolve`, `Block`, `Discard` (verificar si hay más).
- **Ataque en curso:** `view.attack = { attackers, blocks, mode }`.
- **Eventos:** `view.events = { {id, kind} }` (hoy se usan `BlockKill` y `Overkill`). No traen uid/zona/slot.
- **Reglas (Config.Match):** 20 de vida, mazo 40, 5 casillas de Banca, 5 de Combate, mano máx. 8, energía máx. 6, reserva máx. 2, acción 30 s.
- **Las 20 cartas comparten el mismo `art`** (`rbxassetid://125379581550088`).
- **UI actual:** oscura/espacial (`UI/Theme.luau`), diseño horizontal (panel izquierdo 13%, tablero 68%, panel derecho 15%, mano abajo).
- **Lobby:** "Jugar contra el Bot" y "Buscar rival (2 jugadores)". El bot se activa con `ServerConfig.Bot.Enabled`.

---

## 2. Decisiones tomadas

| Tema | Decisión |
|---|---|
| Estilo visual | Mezcla de **templo antiguo (Yu-Gi-Oh! Master Duel)** y **tecnología antigua**: piedra oscura, oro/bronce envejecido, surcos tipo circuito, glifos de neón. |
| Colores de bando | Los del `Theme` actual: cian = jugador, rosa/magenta = rival. Piedra y oro son neutros. |
| Personaje de Roblox | **Oculto.** Solo tablero y cartas. |
| Plataformas | **Móvil y PC por igual.** |
| Dónde se construye | **En el cliente.** Cada jugador se ve siempre en +Z, el rival en -Z. |
| Interfaz 2D | `Hand`, `LeftPanel`, `RightPanel`, banners y toasts se mantienen en 2D por ahora. |
| Tablero 2D actual | Se conserva como alternativa conmutable (bandera en Config). |
| Jugar carta | Se selecciona desde la mano (referencia: **MTG Arena**). La carta va a la Banca; casilla automática por defecto. |
| Avatar | Un **cristal** a cada lado del tablero: muestra la vida y recibe el toque (objetivo `Avatar`). |
| Mano | **2D** mientras se elige; la carta pasa a **3D** al colocarse en la mesa. |
| Arte | **Arte por carta** (lo produce el equipo, necesita tiempo). Mientras tanto, imagen provisional. |
| Calidad gráfica | **Opción manual** para dispositivos de bajo rendimiento. |
| Sonido y partículas | **Sí**, referencias: Yu-Gi-Oh! Duel Links, MTG Arena y Legends of Runeterra. |
| Banca propia vs rival | Tus cartas de Banca se ven **boca arriba para ti**; las del rival, **boca abajo** hasta que atacan (se voltean al avanzar a Combate). |
| Animaciones de carta | mano → Banca · Banca → Combate (con volteo si se revela) · evolución (la carta de la mano se funde con la criatura) · robar del mazo a la mano · tablero → mano · tablero/mano → cementerio. Se deducen comparando el `view` por `uid`; no usan `events`. |
| Entrada 3D | Tocar/clic en cartas, casillas vacías y cristales (raycast). Con una carta de la mano seleccionada se iluminan las casillas libres de Banca y tocar una la coloca ahí (`PlayCard` con `slot`). Al declarar ataque se marcan las casillas de Combate donde entrarán los atacantes (izquierda → derecha). |
| Primer paso técnico | Construir con `Parts` y materiales de Roblox. Mallas de Blender solo si hace falta más adelante. |

---

## 3. Detalles aún abiertos (no bloquean la Fase 1)

1. **Confirmación al jugar:** ¿un toque sobre la carta seleccionada la juega, o se mantiene un botón de confirmar? *Propuesta:* seleccionar → las casillas libres de Banca se iluminan → tocar la casilla (o tocar de nuevo la carta para casilla automática).
2. **Especificación del arte:** *Propuesta:* ilustración sin texto, relación 4:3, 1024×768 px, PNG. El nombre, ATK, VIDA y costo los dibuja el juego. Mientras no esté el arte, `CardDatabase.art` sigue con la imagen provisional.
3. **Origen de los sonidos:** los audios de Roblox deben subirse o usar los autorizados. Hay que definir qué eventos llevan sonido (jugar, revelar, ataque, daño, muerte, curación, escudo, turno).
4. **Menú de ajustes:** calidad gráfica manual y volumen. *Propuesta:* un botón de engranaje 2D en la partida y en el lobby. Guardar la preferencia en el cliente primero; en `PlayerDataService` más adelante.
5. **Qué cambia en calidad baja:** *Propuesta:* sin partículas pesadas, sin luces dinámicas extra, sin sombras, glifos sin brillo animado.
6. **Mano del rival:** `view.opp.hand` es solo un número. *Propuesta:* mostrar reversos de carta en el borde del rival.
7. **Cementerio:** `graveyard` es una lista. *Propuesta:* tocar el montón abre una lista 2D para verlo.
8. **Flechas de objetivo** (como Arena o Runeterra) al elegir objetivo de hechizo o bloqueo: *Propuesta:* dejarlas para la Fase 5.
9. **Fin de partida y banners:** se mantienen en 2D (`Overlay`, `Banner`).

---

> **Estado:** Fase 1 hecha. Cartas 3D, animaciones y `Input3D` (adelanto de las Fases 2, 3 y parte de la 4) en el segundo commit.
> **Nota:** ninguna regla actual devuelve una carta del tablero a la mano; la animación existe y se dispara sola si un uid de tu Banca/Combate aparece en tu mano, pero hoy no la provoca ninguna carta.
> **Pendiente:** arena más clara y detallada (parche aparte), flechas de objetivo, cementerio navegable, reversos de la mano rival, sonidos y partículas.

## 4. Arquitectura propuesta

Carpeta nueva: `src/StarterPlayerScripts/AEVUM/UI3D/`

| Módulo | Responsabilidad |
|---|---|
| `Layout.luau` | Funciones puras con las posiciones de casillas, vitales, mazos, etc. Sin instancias, así se puede probar con `luau` CLI. |
| `BoardBuilder.luau` | Construye una sola vez el templo estático (base, nichos, glifos, orbe, luces). |
| `CardView.luau` | Fábrica y reutilización (pool) de cartas 3D: frente, reverso, ATK/VIDA/costo, estados (escudo, aturdida, reflejo). |
| `Board3D.luau` | **Reconciliador:** compara el `view` nuevo con lo que hay en escena (por `uid`) y crea, mueve o elimina cartas. Misma forma que `Board.luau`: `Board3D.create(ctx)` devuelve la función de render. |
| `CameraRig.luau` | Cámara `Scriptable` adaptable a la proporción de pantalla (móvil/PC). |
| `Input3D.luau` | Un solo sistema para toque y ratón (raycast), con zonas de toque generosas. Llama a los callbacks existentes: `onMyCombat`, `onMyBench`, `onOppCombat`, `onOppBench`. |
| `Fx.luau` (Fase 4+) | Animaciones y partículas a partir de eventos. |

Cambios fuera de `UI3D/`:
- `Main.server.luau`: `Players.CharacterAutoLoads = false`.
- `Config.luau`: bandera `Config.Client = { Board3D = true }` (o similar).
- `AevumClient.client.luau`: elegir entre `BoardUI` y `Board3D`; hacer transparente el fondo de `gameFrame` cuando el 3D está activo.
- `Match.luau` (`emit`): añadir `uid`, zona y slot a los eventos (Fase 4).

---

## 5. Fases

1. **Base:** ocultar personaje, cámara adaptable, tablero estático del templo (piedra, oro, glifos, orbe). Sin lógica.
2. **Conexión al `view`:** cartas en Banca/Combate, rival boca abajo, vitales, mazos, cementerios, orbe según `attackerIdx`. Render por `uid`.
3. **Interacción:** toque/clic en casillas y avatares, resaltado de objetivos, atacantes y bloqueos, usando los callbacks existentes.
4. **Eventos y animaciones:** ampliar `emit()` y animar jugar, revelar al atacar, bloquear, daño, muerte, curación, escudo.
5. **Efectos y pulido:** partículas por tipo de efecto, sonidos, arte por carta, niveles de calidad.

Criterio de "terminado" de cada fase: se puede jugar una partida completa contra el bot sin errores en la consola.

---

## 6. Convenciones del repo (respetar)

- Cabecera `--!nonstrict` y comentario `-- AEVUM · <descripción> (vX.Y.Z)`.
- Indentación con **tabs**.
- Comentarios en español.
- Los datos compartidos (cartas, reglas) viven en `ReplicatedStorage/AEVUM`; lo exclusivo del servidor en `ServerScriptService/AEVUM`.
- Cada módulo nuevo necesita su `.meta.json` solo si el repo lo usa para ese tipo de archivo (los `.luau` de UI actuales no lo tienen).
- Mantener los nombres de acciones y la validación de `Validator.luau`: no inventar acciones nuevas sin pasar por ahí.

---

## 7. Flujo de trabajo y pruebas

- **Rama de trabajo: `feature/tablero-3d`.** Nada de esto se sube a `main`. Todo el trabajo del tablero 3D va en esa rama y se fusiona a `main` solo cuando esté probado.
- Claude **no puede ejecutar Roblox Studio ni subir al repo.** Entrega cada fase como un parche de git (`git format-patch`) que se aplica en la rama con `git am`, o como archivos con la misma estructura de carpetas del repo. Rojo (`rojo serve`) sincroniza con Studio.
- Se prueba en Studio contra el bot (`ServerConfig.Bot.Enabled = true`).
- Ante un fallo, enviar el **mensaje de error completo de la Output** (con la línea) y, si es visual, una captura.
- La lógica pura (`Layout.luau`) se puede cubrir con pruebas en `tests/`, como `Match.spec.luau`.

---

## 8. Riesgos

- **Rendimiento en móvil:** muchas partes, luces y partículas. Mitigación: pool de cartas, pocas luces, niveles de calidad.
- **Texto ilegible en cartas 3D pequeñas:** mostrar solo lo esencial en la carta y dejar el detalle en el panel de inspección.
- **Conflicto de toques** entre GUI 2D y raycast 3D: la GUI debe consumir el toque primero (`GuiService`/`gameProcessed`).
- **Reconstrucción total del `render`:** el 2D borra y recrea todo en cada estado; el 3D no puede hacerlo o no habrá animaciones.
- **Eventos sin datos** (`id` y `kind` solamente): hasta ampliarlos, no se puede animar sobre una carta concreta.
