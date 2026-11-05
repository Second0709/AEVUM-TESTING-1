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
}
