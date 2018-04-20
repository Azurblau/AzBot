local roundStartTime = CurTime()
local nodeZombiesCountAddition = nil
hook.Add("PreRestartRound", D3bot.BotHooksId.."PreRestartRound", function() roundStartTime, D3bot.nodeZombiesCountAddition = CurTime(), nil end)

function D3bot.GetDesiredBotCount()
	local wave = math.max(1, GAMEMODE:GetWave())
	local minutes = (CurTime() - roundStartTime) / 60
	local allowedTotal = game.MaxPlayers() - #player.GetAll() - 2
	local mapParams = D3bot.MapNavMesh.Params
	local zombieFormula = ((mapParams.ZPP or D3bot.ZombiesPerPlayer) + (mapParams.ZPPW or D3bot.ZombiesPerPlayerWave) * wave) * #player.GetHumans() + (mapParams.ZPM or D3bot.ZombiesPerMinute) * minutes + (mapParams.ZPW or D3bot.ZombiesPerWave) * wave
	local zombiesCount = math.Clamp(
		math.ceil(math.min(zombieFormula, (mapParams.ZPPM or D3bot.ZombiesPerPlayerMax) * #player.GetHumans()) + D3bot.ZombiesCountAddition + (D3bot.MapNavMesh.Params.BotMod or 0) + (D3bot.nodeZombiesCountAddition or 0)),
		0,
		allowedTotal)
	local survivorFormula = (mapParams.SPP or D3bot.SurvivorsPerPlayer) * #player.GetHumans()
	local survivorsCount = math.Clamp(
		math.ceil(survivorFormula + D3bot.SurvivorCountAddition),
		0,
		math.max(allowedTotal - zombiesCount, 0))
	return zombiesCount, GAMEMODE.ZombieEscape and 0 or survivorsCount
end

function D3bot.MaintainBotRoles()
	if #player.GetHumans() == 0 then return end
	local desiredCountByTeam = {}
	desiredCountByTeam[TEAM_UNDEAD], desiredCountByTeam[TEAM_SURVIVOR] = D3bot.GetDesiredBotCount()
	local totalDesiredCount = desiredCountByTeam[TEAM_UNDEAD] + desiredCountByTeam[TEAM_SURVIVOR]
	local bots = player.GetBots()
	local botsByTeam = {}
	for k, v in ipairs(bots) do
		local team = v:Team()
		botsByTeam[team] = botsByTeam[team] or {}
		table.insert(botsByTeam[team], v)
	end
	
	-- Sort by frags and being boss zombie
	if botsByTeam[TEAM_UNDEAD] then
		table.sort(botsByTeam[TEAM_UNDEAD], function(a, b) return (a:GetZombieClassTable().Boss and 1 or 0) < (b:GetZombieClassTable().Boss and 1 or 0) end)
	end
	for team, botByTeam in pairs(botsByTeam) do
		table.sort(botByTeam, function(a, b) return a:Frags() < b:Frags() end)
	end
	
	if GAMEMODE:GetWave() <= 0 then
		-- Pre round logic
		if #bots < totalDesiredCount then
			RunConsoleCommand("bot")
			--local bot = player.CreateNextBot("Test")
			return
		elseif #bots > totalDesiredCount then
			local randomBot = table.Random(bots)
			return randomBot and randomBot:Kick(D3bot.BotKickReason)
		end
	else
		-- Add bots out of managed teams to maintain desired counts
		if #(botsByTeam[TEAM_UNDEAD] or {}) < desiredCountByTeam[TEAM_UNDEAD] then
			RunConsoleCommand("bot")
			return
		end
		-- Remove bots out of managed teams to maintain desired counts
		for team, desiredCount in pairs(desiredCountByTeam) do
			if #(botsByTeam[team] or {}) > desiredCount then
				local randomBot = table.remove(botsByTeam[team], 1)
				return randomBot and randomBot:Kick(D3bot.BotKickReason)
			end
		end
		-- Remove bots out of non managed teams if the server is getting too full
		local allowedTotal = game.MaxPlayers() - 2
		if player.GetCount() > allowedTotal then
			for team, desiredCount in pairs(desiredCountByTeam) do
				if not desiredCountByTeam[team] then
					local randomBot = table.remove(botsByTeam[team], 1)
					return randomBot and randomBot:Kick(D3bot.BotKickReason)
				end
			end
		end
	end
end

local NextMaintainBotRoles = CurTime()
function D3bot.SupervisorThinkFunction()
	if NextMaintainBotRoles < CurTime() then
		NextMaintainBotRoles = CurTime() + 1
		D3bot.MaintainBotRoles()
	end
end

-- TODO: Detect situations and coordinate bots accordingly (Attacking cades, hunt down runners, spawncamping prevention)
-- TODO: If needed force one bot to flesh creeper and let him build a nest at a good place