--!nonstrict
-- AEVUM · Configuración SOLO DEL SERVIDOR (v1.0).

return {
	TestMode = false,

	Bot = { Enabled = true, ThinkTime = 0.7 },

	RateLimit = { PerSecond = 10, Burst = 20, StrikesToKick = 8, StrikeResetSeconds = 10 },

	KillSwitches = { Matches = true, Queue = true },
	KillSwitchPollSeconds = 30,
	KillSwitchDataStore = "AevumKillSwitches",

	PrintLogs = true,
	ResultLingerSeconds = 600,

	-- Debug: expone un botón "PAUSAR / REANUDAR" en el cliente.
	-- Ponelo en true para testear. El pause congela el reloj de la partida
	-- (isExpired/isStale no disparan), detiene al bot y bloquea acciones del
	-- jugador. NO detiene el proceso del servidor ni el wall-clock real.
	DebugPause = false,
}