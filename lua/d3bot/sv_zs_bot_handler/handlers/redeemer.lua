D3bot.Handlers.Redeemer = D3bot.Handlers.Redeemer or {}
local HANDLER = D3bot.Handlers.Redeemer

HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	if not TEAM_REDEEMER then return end
	return team == TEAM_REDEEMER
end

function HANDLER.UpdateBotCmdFunction(bot, cmd)
	return D3bot.Handlers.Survivor_Fallback.UpdateBotCmdFunction(bot, cmd)
end

function HANDLER.ThinkFunction(bot)
	return D3bot.Handlers.Survivor_Fallback.ThinkFunction(bot)
end

function HANDLER.OnTakeDamageFunction(bot, dmg)
	return D3bot.Handlers.Survivor_Fallback.OnTakeDamageFunction(bot, dmg)
end

function HANDLER.OnDoDamageFunction(bot, dmg)
	return D3bot.Handlers.Survivor_Fallback.OnDoDamageFunction(bot, dmg)
end

function HANDLER.OnDeathFunction(bot)
	return D3bot.Handlers.Survivor_Fallback.OnDeathFunction(bot)
end

-----------------------------------
-- Custom functions and settings --
-----------------------------------
