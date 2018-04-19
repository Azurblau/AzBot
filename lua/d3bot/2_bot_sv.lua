
return function(lib)
	local from = lib.From
	
	lib.IsEnabled = engine.ActiveGamemode() == "zombiesurvival" and table.Count(lib.MapNavMesh.ItemById) > 0
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
	lib.LinkDeathCostRaise = 1000
	lib.BotConsideringDeathCostAntichance = 3
	lib.BotMinSpdFactor = 0.75
	lib.BotAdditionalAngOffshoot = 30
	lib.BotAngLerpFactor = 0.125
	lib.BotAttackAngLerpFactor = 0.125--0.5
	lib.BotAimAngLerpFactor = 0.5
	lib.BotAimPosVelocityOffshoot = 0.4
	lib.BotJumpAntichance = 25
	lib.ZombiesPerPlayer = 0.3
	lib.ZombiesPerPlayerMax = 1.2			-- Limits amount of zombies to this zombie/player ratio. (ZombiesCountAddition is not calculated in)
	lib.ZombiesPerPlayerWave = 0.10
	lib.ZombiesPerMinute = 0
	lib.ZombiesPerWave = 0.4
	lib.ZombiesCountAddition = 1			-- BotMod
	lib.SurvivorsPerPlayer = 0.25--1.2		-- Survivor bots per total player (non bot) amount. Will only spawn pre round. But excess bots will be kicked/slain.
	lib.SurvivorCountAddition = 5
	lib.IsSelfRedeemEnabled = true
	lib.IsBonusEnabled = true
	lib.SelfRedeemWaveMax = 4
	lib.BotHooksId = "D3bot"
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
	
	lib.NodeDamageEnts = {"prop_*turret", "prop_arsenalcrate", "prop_resupply"}
	function lib.DoNodeDamage() -- TODO: Move node damage
		local players = lib.RemoveObsDeadTgts(player.GetAll())
		players = from(players):Where(function(k, v) return v:Team() ~= TEAM_ZOMBIE end).R
		local ents = table.Add(players, lib.GetEntsOfClss(lib.NodeDamageEnts))
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
	end)
	hook.Add("PlayerInitialSpawn", lib.BotHooksId, function(pl) if lib.IsEnabled and pl:IsBot() then pl:D3bot_Initialize() end end)
	local hadBonusByPl = {}
	hook.Add("PlayerSpawn", lib.BotHooksId, function(pl)
		if not lib.IsEnabled then return end
		if pl:IsBot() then pl:D3bot_SetUp() end
		if lib.IsEnabled and lib.IsBonusEnabled and pl:Team() == TEAM_HUMAN then
			local hadBonus = hadBonusByPl[pl]
			hadBonusByPl[pl] = true
			pl:SetPoints(hadBonus and 0 or 25)
		end
	end)
	
	hook.Add("PreRestartRound", lib.BotHooksId, function() hadBonusByPl = {} end)
	
end
