
return function(lib)
	local from = lib.From
	
	lib.IsEnabled = engine.ActiveGamemode() == "zombiesurvival"
	lib.NextBotConfigUpdate = 0
	lib.BotPosMilestoneUpdateDelay = 25
	lib.BotZeroPosMilestoneUpdateDelay = 0.25
	lib.BotPosMilestoneDistMin = 200
	lib.BotTgtFixationDistMin = 250
	lib.BotTgtAreaRadius = 100
	lib.BotSeeTr = {
		mins = Vector(-15, -15, -15),
		maxs = Vector(15, 15, 15),
		mask = MASK_PLAYERSOLID }
	lib.NodeBlocking = {
		mins = Vector(-1, -1, -1),
		maxs = Vector(1, 1, 1),
		classes = {func_breakable = true, prop_physics = true, prop_dynamic = true, prop_door_rotating = true, func_door = true, func_physbox = true, func_physbox_multiplayer = true, func_movelinear = true} }
	lib.BotAttackDistMin = 100
	lib.PotBotTgtClss = { "prop_*turret", "prop_purifier", "prop_arsenalcrate", "prop_manhack*", "prop_relay" }
	lib.IsPotBotTgtClsOrNilByName = from(lib.PotBotTgtClss):VsSet().R
	lib.PotBotTgts = {}
	lib.LinkDeathCostRaise = 1000
	lib.DeathCostOrNilByLink = {}
	lib.BotConsideringDeathCostAntichance = 3
	lib.BotMinSpdFactor = 0.75
	lib.BotAngOffshoot = 45
	lib.BotAdditionalAngOffshoot = 30
	lib.BotAngLerpFactor = 0.25
	lib.BotAimPosVelocityOffshoot = 0.2
	lib.BotJumpAntichance = 25
	lib.ZombiesPerHuman = 0.3
	lib.ZombiesPerHumanMax = 1.2			-- Limits maximum amount of zombies to this zombie/human ratio. (ZombiesCountAddition is not calculated in)
	lib.ZombiesPerHumanWave = 0.10
	lib.ZombiesPerMinute = 0
	lib.ZombiesPerWave = 0.4
	lib.ZombiesCountAddition = 0			-- BotMod
	lib.HasMapNavMesh = table.Count(lib.MapNavMesh.ItemById) > 0
	lib.MaintainBotRolesAutomatically = lib.HasMapNavMesh
	lib.IsSelfRedeemEnabled = lib.HasMapNavMesh
	lib.IsBonusEnabled = lib.HasMapNavMesh
	lib.SelfRedeemWaveMax = 4
	lib.BotHooksId = tostring({})
	lib.BotClasses = {
		"Zombie", "Zombie", "Zombie",
		"Ghoul",
		"Wraith", "Wraith", "Wraith",
		"Bloated Zombie", "Bloated Zombie", "Bloated Zombie",
		"Fast Zombie", "Fast Zombie", "Fast Zombie", "Fast Zombie",
		"Poison Zombie", "Poison Zombie", "Poison Zombie",
		"Zombine", "Zombine", "Zombine", "Zombine", "Zombine" }
	lib.BotKickReason = "I did my job. :)"
	lib.SurvivorBotKickReason = "I'm not supposed to be a survivor. :O"
	
	function lib.DoNodeDamage()
		local players = lib.RemoveObsDeadTgts(player.GetAll())
		players = from(players):Where(function(k, v) return v:Team() ~= TEAM_ZOMBIE end).R
		local ents = table.Add(players, lib.GetEntsOfClss(lib.PotBotTgtClss))
		for i, ent in pairs(ents) do
			local nodeOrNil = lib.MapNavMesh:GetNearestNodeOrNil(ent:GetPos()) -- TODO: Don't call GetNearestNodeOrNil that often
			if nodeOrNil and type(nodeOrNil.Params.DMGPerSecond) == "number" and nodeOrNil.Params.DMGPerSecond > 0 then
				ent:TakeDamage(nodeOrNil.Params.DMGPerSecond*5, game.GetWorld(), game.GetWorld())
			end
		end
	end
	
	hook.Add("Think", lib.BotHooksId, function()
		if not lib.IsEnabled then return end
		if (lib.NextNodeDamage or 0) < CurTime() then
			lib.NextNodeDamage = CurTime() + 5
			lib.DoNodeDamage()
		end
		if lib.NextBotConfigUpdate > CurTime() then return end
		lib.NextBotConfigUpdate = CurTime() + 0.2
		lib.UpdateBotConfig()
	end)
	hook.Add("PlayerInitialSpawn", lib.BotHooksId, function(pl) if lib.IsEnabled and pl:IsBot() then pl:AzBot_Initialize() end end)
	local hadBonusByPl = {}
	hook.Add("PlayerSpawn", lib.BotHooksId, function(pl)
		if not lib.IsEnabled then return end
		if pl:IsBot() then pl:AzBot_SetUp() end
		if lib.IsBonusEnabled and pl:Team() == TEAM_HUMAN then
			local hadBonus = hadBonusByPl[pl]
			hadBonusByPl[pl] = true
			pl:SetPoints(hadBonus and 0 or 25)
		end
	end)
	local roundStartTime = CurTime()
	hook.Add("PlayerDeath", lib.BotHooksId, function(pl) if lib.IsEnabled and pl:IsBot() then lib.HandleBotDeath(pl) end end)
	hook.Add("PreRestartRound", lib.BotHooksId, function() hadBonusByPl, roundStartTime, lib.nodeZombiesCountAddition = {}, CurTime(), nil end)
	hook.Add("EntityTakeDamage", lib.BotHooksId, function(ent, dmg) if lib.IsEnabled and ent:IsPlayer() and ent:IsBot() then lib.HandleBotDamage(ent, dmg) end end)
	
	function lib.HandleBotDeath(bot)
		lib.RerollBotClass(bot)
		local mem = self.AzBot_Mem
		local nodeOrNil = mem.NodeOrNil
		local nextNodeOrNil = mem.NextNodeOrNil
		if not nodeOrNil or not nextNodeOrNil then return end
		local link = nodeOrNil.LinkByLinkedNode[nextNodeOrNil]
		if not link then return end
		lib.DeathCostOrNilByLink[link] = (lib.DeathCostOrNilByLink[link] or 0) + lib.LinkDeathCostRaise
	end
	
	function lib.HandleBotDamage(bot, dmg)
		local attacker = dmg:GetAttacker()
		if not lib.CanBeBotTgt(attacker) then return end
		local mem = self.AzBot_Mem
		if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():Distance(bot:GetPos()) <= lib.BotTgtFixationDistMin then return end
		mem.TgtOrNil = attacker
		bot:AzBot_ResetPosMilestone(bot)
	end
	
	function lib.GetDesiredZombiesCount()
		local wave = math.max(1, GAMEMODE:GetWave())
		local mapParams = lib.MapNavMesh.Params
		local formula = ((mapParams.ZPH or lib.ZombiesPerHuman) + (mapParams.ZPHW or lib.ZombiesPerHumanWave) * wave) * #player.GetHumans() + (mapParams.ZPM or lib.ZombiesPerMinute) * (CurTime() - roundStartTime) / 60 + (mapParams.ZPW or lib.ZombiesPerWave) * wave
		return math.Clamp(
			math.ceil(math.min(formula, (mapParams.ZPHM or lib.ZombiesPerHumanMax) * #player.GetHumans()) + lib.ZombiesCountAddition + (lib.MapNavMesh.Params.BotMod or 0) + (lib.nodeZombiesCountAddition or 0)),
			0,
			game.MaxPlayers() - #team.GetPlayers(TEAM_HUMAN) - 2)
		-- TODO: Change player.GetHumans() to only count survivors without bots
	end
	
	function lib.MaintainBotRoles()
		if #player.GetHumans() == 0 then return end
		local desiredZombiesCount = lib.GetDesiredZombiesCount()
		local zombiesCount = #team.GetPlayers(TEAM_UNDEAD)
		local counter = 2
		while zombiesCount < desiredZombiesCount and not GAMEMODE.RoundEnded and counter > 0 do
			RunConsoleCommand("bot")
			zombiesCount = zombiesCount + 1
			counter = counter - 1
		end
		for idx, bot in ipairs(player.GetBots()) do
			if bot:Team() == TEAM_UNDEAD then
				if zombiesCount > desiredZombiesCount then
					bot:Kick(lib.BotKickReason)
					zombiesCount = zombiesCount - 1
				end
			else
				bot:Kick(lib.SurvivorBotKickReason)
			end
		end
	end
	
	function lib.UpdatePotBotTgts()
		-- Get humans or non zombie players or any players in that order
		local players = lib.RemoveObsDeadTgts(team.GetPlayers(TEAM_HUMAN))
		if #players == 0 and TEAM_ZOMBIE then
			players = lib.RemoveObsDeadTgts(player.GetAll())
			players = from(players):Where(function(k, v) return v:Team() ~= TEAM_ZOMBIE end).R
		end
		if #players == 0 then
			players = lib.RemoveObsDeadTgts(player.GetAll())
		end
		lib.PotBotTgts = table.Add(players, lib.GetEntsOfClss(lib.PotBotTgtClss))
	end
	
end
