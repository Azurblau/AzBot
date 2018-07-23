D3bot.IsEnabled = engine.ActiveGamemode() == "zombiesurvival" and table.Count(D3bot.MapNavMesh.ItemById) > 0
D3bot.BotHooksId = "D3bot"

D3bot.BotSeeTr = {
	mins = Vector(-15, -15, -15),
	maxs = Vector(15, 15, 15),
	mask = MASK_PLAYERSOLID
}
D3bot.NodeBlocking = {
	mins = Vector(-1, -1, -1),
	maxs = Vector(1, 1, 1),
	classes = {func_breakable = true, prop_physics = true, prop_dynamic = true, prop_door_rotating = true, func_door = true, func_physbox = true, func_physbox_multiplayer = true, func_movelinear = true}
}

D3bot.NodeDamageEnts = {"prop_*turret", "prop_arsenalcrate", "prop_resupply"}

D3bot.BotAttackDistMin = 100
D3bot.LinkDeathCostRaise = 300
D3bot.BotConsideringDeathCostAntichance = 3
D3bot.BotAngLerpFactor = 0.125
D3bot.BotAttackAngLerpFactor = 0.125--0.5
D3bot.BotAimAngLerpFactor = 0.5
D3bot.BotAimPosVelocityOffshoot = 0.4
D3bot.BotJumpAntichance = 25
D3bot.BotDuckAntichance = 25

D3bot.ZombiesPerPlayer = 0.3
D3bot.ZombiesPerPlayerMax = 2.0			-- Limits amount of zombies to this zombie/player ratio. (ZombiesCountAddition is not calculated in)
D3bot.ZombiesPerPlayerWave = 0.20
D3bot.ZombiesPerMinute = 0
D3bot.ZombiesPerWave = 0.4
D3bot.ZombiesCountAddition = 0			-- BotMod
D3bot.SurvivorsPerPlayer = 0--1.2		-- Survivor bots per total player (non bot) amount. Will only spawn pre round.
D3bot.SurvivorCountAddition = 0			-- BotMod for survivor bots

D3bot.IsSelfRedeemEnabled = true
D3bot.IsBonusEnabled = false
D3bot.SelfRedeemWaveMax = 1

D3bot.BotNameFile = "fng_usernames"		-- Comment out this line to use Bot, Bot(2), Bot(3), ... as name. Changes are applied on map restart

D3bot.BotKickReason = "I did my job. :)"