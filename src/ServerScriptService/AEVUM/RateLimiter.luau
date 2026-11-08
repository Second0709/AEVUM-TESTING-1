--!nonstrict
-- AEVUM · Limitador de peticiones (v1.3.0).

local ServerConfig = require(script.Parent.ServerConfig)
local RateLimiter = {}
local buckets = {}

function RateLimiter.check(player)
	local cfg = ServerConfig.RateLimit
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = cfg.Burst, last = now, strikes = 0, lastStrike = 0 }
		buckets[player] = b
	end
	b.tokens = math.min(cfg.Burst, b.tokens + (now - b.last) * cfg.PerSecond)
	b.last = now
	if b.tokens < 1 then
		if now - b.lastStrike > cfg.StrikeResetSeconds then b.strikes = 0 end
		b.strikes += 1
		b.lastStrike = now
		return false, b.strikes >= cfg.StrikesToKick
	end
	b.tokens -= 1
	return true, false
end

function RateLimiter.forget(player) buckets[player] = nil end

return RateLimiter
