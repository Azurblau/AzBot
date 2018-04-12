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
	return zombiesCount, survivorsCount
end

function D3bot.MaintainBotRoles()
	if #player.GetHumans() == 0 then return end
	local desiredZombiesCount, desiredSurvivorsCount = D3bot.GetDesiredBotCount()
	local zombiesCount, survivorsCount = #team.GetPlayers(TEAM_UNDEAD), #team.GetPlayers(TEAM_SURVIVOR)
	local zombieBotsDifference, survivorBotsDifference = desiredZombiesCount - zombiesCount, desiredSurvivorsCount - survivorsCount
	local totalDifference = zombieBotsDifference + survivorBotsDifference
	local count, desiredCount = zombiesCount + survivorsCount, desiredZombiesCount + desiredSurvivorsCount
	while totalDifference > 0 and (zombieBotsDifference > 0 or (survivorBotsDifference > 0 and GAMEMODE:GetWave() <= 0)) and not GAMEMODE.RoundEnded do
		RunConsoleCommand("bot")
		--local bot = player.CreateNextBot("Test")
		totalDifference = totalDifference - 1
		return -- Have to return for now, as i can't determine the team of the bot now
	end
	for _, bot in ipairs(player.GetBots()) do -- TODO: kick bosses and bots with more frags last
		if bot:Team() == TEAM_UNDEAD then
			if zombieBotsDifference < 0 then
				bot:Kick(D3bot.BotKickReason)
				zombieBotsDifference = zombieBotsDifference + 1
			end
		elseif bot:Team() == TEAM_SURVIVOR then
			if survivorBotsDifference < 0 and GAMEMODE:GetWave() > 0 then
				if zombieBotsDifference > 0 then
					bot:StripWeapons()
					bot:KillSilent()
					zombieBotsDifference = zombieBotsDifference - 1
					survivorBotsDifference = survivorBotsDifference + 1
				else
					bot:Kick(D3bot.BotKickReason)
					survivorBotsDifference = survivorBotsDifference + 1
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
