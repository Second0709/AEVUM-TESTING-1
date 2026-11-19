#!/usr/bin/env python3
"""Prueba de humo de Board3D sin Roblox Studio.

El CLI de `luau` no trae la API de Roblox y sus globales son de solo lectura, así que este script:
  1) copia los módulos de UI3D a una carpeta temporal,
  2) les inyecta como variables locales las simulaciones de _stubs.luau (Instance, Vector3, game, workspace...),
  3) ejecuta smoke.luau, que reproduce los escenarios reales: jugar, robar, avanzar con volteo,
     cementerio, devolver a la mano, evolución y partida nueva.
Uso:  python3 tests/smoke/run.py [ruta al ejecutable de luau]   (por defecto `luau`)
Si cambias la API de Roblox que usa UI3D, amplía _stubs.luau.
"""
import os, shutil, subprocess, sys, tempfile

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ui3d = os.path.join(root, "src", "StarterPlayerScripts", "AEVUM", "UI3D")
luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
mods = [f[:-5] for f in os.listdir(ui3d) if f.endswith(".luau")]
inj = (
    'local realRequire = require\n'
    'local S = realRequire("./_stubs")\n'
    'local function require(m) if type(m) == "table" then return m end return realRequire(m) end\n'
    'local Vector3, Vector2, CFrame, Color3, UDim2, UDim, TweenInfo, Enum, RaycastParams, Instance, workspace, game, task, script = '
    'S.Vector3, S.Vector2, S.CFrame, S.Color3, S.UDim2, S.UDim, S.TweenInfo, S.Enum, S.RaycastParams, S.Instance, S.workspace, S.game, S.task, S.script\n'
)
tmp = tempfile.mkdtemp()
try:
    for m in mods:
        src = open(os.path.join(ui3d, m + ".luau"), encoding="utf-8").read()
        open(os.path.join(tmp, m + ".luau"), "w", encoding="utf-8").write(src.replace("--!nonstrict\n", "--!nonstrict\n" + inj, 1))
    shutil.copy(os.path.join(root, "src", "ReplicatedStorage", "AEVUM", "CardDatabase.luau"), tmp)
    for f in ("_stubs.luau", "smoke.luau"):
        shutil.copy(os.path.join(os.path.dirname(__file__), f), tmp)
    sys.exit(subprocess.call([luau, "smoke.luau"], cwd=tmp))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
