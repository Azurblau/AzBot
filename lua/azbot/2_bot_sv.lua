
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
	lib.ZombieHumanRatioMin = 0.15
	lib.ZombiesCountAddition = 1
	lib.HasMapNavMesh = table.Count(lib.MapNavMesh.ItemById) > 0
	lib.MaintainBotRolesAutomatically = lib.HasMapNavMesh
	lib.IsSelfRedeemEnabled = lib.HasMapNavMesh
	lib.IsBonusEnabled = lib.HasMapNavMesh
	lib.SelfRedeemWaveMax = 4
	lib.BotHooksId = tostring({})
	lib.BotClasses = {
		"Zombie", "Zombie", "Zombie",
		"Ghoul",
		"Wraith", "Wraith",
		"Bloated Zombie", "Bloated Zombie", "Bloated Zombie",
		"Fast Zombie", "Fast Zombie", "Fast Zombie", "Fast Zombie",
		"Mailed Zombie",
		"Scratcher",
		"Poison Zombie", "Poison Zombie", "Poison Zombie",
		"Screamer",
		"Zombine", "Zombine", "Zombine", "Zombine", "Zombine" }
	lib.BotKickReason = "I did my job. :)"
	lib.SurvivorBotKickReason = "I'm not supposed to be a survivor. :O"
	
	hook.Add("Initialize", lib.BotHooksId, function() GAMEMODE.RoundLimit = 1 end)
	hook.Add("Think", lib.BotHooksId, function()
		if not lib.IsEnabled then return end
		if lib.NextBotConfigUpdate > CurTime() then return end
		lib.NextBotConfigUpdate = CurTime() + 0.2
		lib.UpdateBotConfig()
	end)
	hook.Add("PlayerInitialSpawn", lib.BotHooksId, function(pl) if lib.IsEnabled and pl:IsBot() then lib.InitializeBot(pl) end end)
	local hadBonusByPl = {}
	hook.Add("PlayerSpawn", lib.BotHooksId, function(pl)
		if not lib.IsEnabled then return end
		if pl:IsBot() then lib.SetUpBot(pl) end
		if lib.IsBonusEnabled and pl:Team() == TEAM_HUMAN then
			local hadBonus = hadBonusByPl[pl]
			hadBonusByPl[pl] = true
			pl:SetPoints(hadBonus and 0 or 25)
		end
	end)
	hook.Add("PlayerDeath", lib.BotHooksId, function(pl) if lib.IsEnabled and pl:IsBot() then lib.HandleBotDeath(pl) end end)
	hook.Add("PreRestartRound", lib.BotHooksId, function() hadBonusByPl = {} end)
	hook.Add("StartCommand", lib.BotHooksId, function(pl, cmd) if lib.IsEnabled and pl:IsBot() then lib.UpdateBotCmd(pl, cmd) end end)
	hook.Add("EntityTakeDamage", lib.BotHooksId, function(ent, dmg) if lib.IsEnabled and ent:IsPlayer() and ent:IsBot() then lib.HandleBotDamage(ent, dmg) end end)
	
	lib.MemByBot = {}
	local memByBot = lib.MemByBot
	
	function lib.GetBotAttackPosOrNil(bot, fraction)
		local tgt = memByBot[bot].TgtOrNil
		if not IsValid(tgt) then return end
		return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) or tgt:WorldSpaceCenter()
	end
	
	function lib.GetBotAttackPosOrNilFuture(bot, fraction, t)
		local tgt = memByBot[bot].TgtOrNil
		if not IsValid(tgt) then return end
		return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + tgt:GetVelocity()*t or tgt:WorldSpaceCenter()
	end
	
	function lib.GetTrajectories2DParams(g, initVel, distZ, distRad)
		local trajectories = {}
		local radix = initVel^4 - g*(g*distRad^2 + 2*distZ*initVel^2)
		
		if radix < 0 then return trajectories end
		local pitch = math.atan((initVel^2 - math.sqrt(radix)) / (g*distRad))
		local t1 = distRad / (initVel * math.cos(pitch))
		table.insert(trajectories, {g = g, initVel = initVel, pitch = pitch, t1 = t1})
		if radix > 0 then
			local pitch = math.atan((initVel^2 + math.sqrt(radix)) / (g*distRad))
			local t1 = distRad / (initVel * math.cos(pitch))
			table.insert(trajectories, {g = g, initVel = initVel, pitch = pitch, t1 = t1})
		end
		
		return trajectories
	end
	
	function lib.GetTrajectory2DPoints(trajectory, segments)
		trajectory.points = {}
		for i = 0, segments, 1 do
			local t = Lerp(i/segments, 0, trajectory.t1)
			local r = Vector(math.cos(trajectory.pitch)*trajectory.initVel*t, 0, math.sin(trajectory.pitch)*trajectory.initVel*t - trajectory.g/2*t^2)
			table.insert(trajectory.points, r)
		end
		
		return trajectory
	end
	
	function lib.GetTrajectories(bot, r0, r1, segments)
		local g = 600 -- Hard coded acceleration, should be read from gmod later
		
		local initVel
		if bot:GetActiveWeapon() and bot:GetActiveWeapon().PounceVelocity then
			initVel = (1 - 0.5 * (bot:GetLegDamage() / GAMEMODE.MaxLegDamage)) * bot:GetActiveWeapon().PounceVelocity
		else
			return {}
		end
		
		local distZ = r1.z - r0.z
		local distRad = math.sqrt((r1.x - r0.x)^2 + (r1.y - r0.y)^2)
		local yaw = math.atan2(r1.y - r0.y, r1.x - r0.x)
		
		local trajectories = lib.GetTrajectories2DParams(g, initVel, distZ, distRad)
		for i, trajectory in ipairs(trajectories) do
			trajectories[i].yaw = yaw
			trajectories[i].totalTime = trajectories[i].t1 + bot:GetActiveWeapon().PounceStartDelay or 0
			-- Calculate 2D trajectory from parameters
			trajectories[i] = lib.GetTrajectory2DPoints(trajectory, segments)
			-- Rotate and move trajectory into 3D space
			for k, _ in ipairs(trajectory.points) do
				trajectory.points[k]:Rotate(Angle(0, math.deg(yaw), 0))
				trajectory.points[k]:Add(r0)
			end
		end
		
		return trajectories
	end
	
	function lib.CanBotPounceToTarget(bot, attackPos)
		if not attackPos then return end
		local selfPos = bot:GetPos()--LerpVector(0.75, bot:GetPos(), bot:EyePos())
		local trajectories = lib.GetTrajectories(bot, selfPos, attackPos, 10)
		local resultTrajectories = {}
		for _, trajectory in ipairs(trajectories) do
			local lastPoint = nil
			local hit = false
			for _, point in ipairs(trajectory.points) do
				if lastPoint then
					local tr = util.TraceEntity({start = point, endpos = lastPoint, filter = player.GetAll()}, bot)
					if tr.Hit then
						hit = true
						break
					end
				end
				lastPoint = point
			end
			if not hit then
				table.insert(resultTrajectories, trajectory)
			end
		end
		if #resultTrajectories == 0 then resultTrajectories = nil end
		return resultTrajectories
	end
	
	function lib.CanBotSeeTarget(bot)
		local attackPos = lib.GetBotAttackPosOrNil(bot)
		if not attackPos then return false end
		local mem = memByBot[bot]
		if mem.TgtNodeOrNil and mem.NodeOrNil ~= mem.TgtNodeOrNil and mem.TgtNodeOrNil.Params.See == "Disabled" then return false end
		local tr = lib.BotSeeTr
		tr.start = lib.GetViewCenter(bot)
		tr.endpos = attackPos
		tr.filter = player.GetAll()
		return attackPos and not util.TraceHull(tr).Hit
	end
	
	function lib.BotFace(bot, pos, getOrigin)
		local mem = memByBot[bot]
		mem.Angs = LerpAngle(lib.BotAngLerpFactor, mem.Angs, (pos - getOrigin(bot)):Angle() + mem.AngsOffshoot)
	end
	
	function lib.RerollBotClass(bot)
		if not GAMEMODE:GetWaveActive() then return end
		if bot:GetZombieClassTable().Name == "Zombie Torso" then return end
		local zombieClasses = {}
		for _, class in ipairs(lib.BotClasses) do
			local zombieClass = GAMEMODE.ZombieClasses[class]
			if zombieClass then
				if zombieClass.Unlocked then
					table.insert(zombieClasses, zombieClass)
				end
			end
		end
		local zombieClass = table.Random(zombieClasses)
		if not zombieClass then zombieClass = GAMEMODE.ZombieClasses[GAMEMODE.DefaultZombieClass] end
		bot:SetZombieClass(zombieClass.Index)
	end
	
	function lib.GetDesiredZombiesCount()
		return math.Clamp(
			math.ceil(#player.GetHumans() * lib.ZombieHumanRatioMin * math.max(1, GAMEMODE:GetWave())) + lib.ZombiesCountAddition,
			0,
			game.MaxPlayers() - #team.GetPlayers(TEAM_HUMAN) - 2)
	end
	
	function lib.MaintainBotRoles()
		if #player.GetHumans() == 0 then return end
		local desiredZombiesCount = lib.GetDesiredZombiesCount()
		local zombiesCount = #team.GetPlayers(TEAM_UNDEAD)
		while zombiesCount < desiredZombiesCount do
			RunConsoleCommand("bot")
			zombiesCount = zombiesCount + 1
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
	
	function lib.UpdatePotBotTgts() lib.PotBotTgts = table.Add(team.GetPlayers(TEAM_HUMAN), lib.GetEntsOfClss(lib.PotBotTgtClss)) end
	function lib.ResetBotTgtOrNil(bot) memByBot[bot].TgtOrNil = table.Random(lib.PotBotTgts) end
	function lib.UpdateBotTgtOrNil(bot) if not lib.CanBeBotTgt(memByBot[bot].TgtOrNil) then lib.ResetBotTgtOrNil(bot) end end
	function lib.CanBeBotTgt(tgtOrNil) return IsValid(tgtOrNil) and ((tgtOrNil:IsPlayer() and tgtOrNil:Team() == TEAM_HUMAN) or lib.IsPotBotTgtClsOrNilByName[tgtOrNil:GetClass()]) end
	
	function lib.UpdateBotConfig()
		lib.UpdatePotBotTgts()
		if lib.MaintainBotRolesAutomatically then lib.MaintainBotRoles() end
	end
	
	function lib.InitializeBot(bot)
		if lib.MaintainBotRolesAutomatically then
			GAMEMODE.PreviouslyDied[bot:UniqueID()] = CurTime()
			GAMEMODE:PlayerInitialSpawn(bot)
		end
		
		memByBot[bot] = {
			PosMilestone = Vector(),
			ZeroPosMilestone = Vector(),
			NextPosMilestoneTime = 0,
			NextZeroPosMilestoneTime = 0,
			NextFailPosMilestone = function() end,
			TgtOrNil = nil,
			TgtNodeOrNil = nil,
			NodeOrNil = nil,
			NextNodeOrNil = nil,
			RemainingNodes = {},
			ConsidersPathLethality = false,
			Spd = 0,
			Angs = Angle(),
			AngOffshoot = 0,
			AngsOffshoot = Angle(),
			NextSlowThinkTime = 0,
			ButtonsToBeClicked = 0 }
	end
	
	function lib.SetUpBot(bot)
		local mem = memByBot[bot]
		lib.ResetBotPosMilestone(bot)
		mem.TgtOrNil = nil
		mem.NextNodeOrNil = nil
		mem.RemainingNodes = {}
		mem.ConsidersPathLethality = math.random(1, lib.BotConsideringDeathCostAntichance) == 1
		mem.Angs = bot:EyeAngles()
		mem.NextSlowThinkTime = 0
	end
	
	function lib.HandleBotDeath(bot)
		lib.RerollBotClass(bot)
		local mem = memByBot[bot]
		local nodeOrNil = mem.NodeOrNil
		local nextNodeOrNil = mem.NextNodeOrNil
		if not nodeOrNil or not nextNodeOrNil then return end
		local link = nodeOrNil.LinkByLinkedNode[nextNodeOrNil]
		if not link then return end
		lib.DeathCostOrNilByLink[link] = (lib.DeathCostOrNilByLink[link] or 0) + lib.LinkDeathCostRaise
	end
	
	function lib.ResetBotPosMilestone(bot)
		lib.SetBotPosMilestone(bot)
		lib.SetBotZeroPosMilestone(bot)
		memByBot[bot].NextFailPosMilestone = lib.FailFirstPosMilestone
	end
	function lib.UpdateBotPosMilestone(bot)
		local mem = memByBot[bot]
		if mem.NextZeroPosMilestoneTime <= CurTime() then
			if bot:GetPos() == mem.ZeroPosMilestone then
				if bot:GetMoveType() == MOVETYPE_LADDER then
					mem.ButtonsToBeClicked = bit.bor(mem.ButtonsToBeClicked, IN_JUMP)
				-- else
					-- bot:Kill()
					-- lib.ResetBotPosMilestone(bot)
					-- return
				end
			end
			lib.SetBotZeroPosMilestone(bot)
		end
		if mem.NextPosMilestoneTime > CurTime() then return end
		local failed = bot:GetPos():Distance(mem.PosMilestone) < lib.BotPosMilestoneDistMin
		lib.SetBotPosMilestone(bot)
		if failed then mem.NextFailPosMilestone(bot) end
	end
	function lib.SetBotPosMilestone(bot)
		local mem = memByBot[bot]
		mem.PosMilestone = bot:GetPos()
		mem.NextPosMilestoneTime = CurTime() + lib.BotPosMilestoneUpdateDelay - math.random(0, math.floor(lib.BotPosMilestoneUpdateDelay * 0.5))
	end
	function lib.SetBotZeroPosMilestone(bot)
		local mem = memByBot[bot]
		mem.ZeroPosMilestone = bot:GetPos()
		mem.NextZeroPosMilestoneTime = CurTime() + lib.BotZeroPosMilestoneUpdateDelay
	end
	function lib.FailFirstPosMilestone(bot)
		local mem = memByBot[bot]
		lib.ResetBotTgtOrNil(bot)
		mem.NextFailPosMilestone = lib.FailSecondPosMilestone
		mem.ButtonsToBeClicked = bit.bor(mem.ButtonsToBeClicked, IN_JUMP)
	end
	function lib.FailSecondPosMilestone(bot)
		bot:Kill()
		lib.ResetBotPosMilestone(bot)
	end
	
	function lib.UpdateBotTgtProximity(bot)
		local mem = memByBot[bot]
		local inverseFactor = IsValid(mem.TgtOrNil) and math.min(1, bot:GetPos():Distance(mem.TgtOrNil:GetPos()) / lib.BotTgtAreaRadius) or 1
		mem.Spd = bot:GetMaxSpeed() * (lib.BotMinSpdFactor + (1 - lib.BotMinSpdFactor) * inverseFactor)
		mem.AngOffshoot = lib.BotAngOffshoot + lib.BotAdditionalAngOffshoot * (1 - inverseFactor)
	end
	
	function lib.UpdateBotAngsOffshoot(bot)
		local mem = memByBot[bot]
		local nodeOrNil = mem.NodeOrNil
		if nodeOrNil and nodeOrNil.Params.Aim == "Straight" then
			mem.AngsOffshoot = Angle()
			return
		end
		local angOffshoot = mem.AngOffshoot
		mem.AngsOffshoot = Angle(math.random(-angOffshoot, angOffshoot), math.random(-angOffshoot, angOffshoot), 0)
	end
	
	function lib.UpdateBotPath(bot)
		local mem = memByBot[bot]
		if not IsValid(mem.TgtOrNil) then return end
		local mapNavMesh = lib.MapNavMesh
		local node = mapNavMesh:GetNearestNodeOrNil(bot:GetPos())
		mem.TgtNodeOrNil = mapNavMesh:GetNearestNodeOrNil(mem.TgtOrNil:GetPos())
		if not node or not mem.TgtNodeOrNil then return end
		local path = lib.GetBestMeshPathOrNil(node, mem.TgtNodeOrNil, mem.ConsidersPathLethality and lib.DeathCostOrNilByLink or {})
		if not path then return end
		mem.NodeOrNil = table.remove(path, 1)
		mem.NextNodeOrNil = table.remove(path, 1)
		mem.RemainingNodes = path
	end
	function lib.UpdateBotPathProgress(bot)
		local mem = memByBot[bot]
		while mem.NextNodeOrNil do
			if mem.NextNodeOrNil:GetContains(bot:GetPos()) then
				mem.NodeOrNil = mem.NextNodeOrNil
				mem.NextNodeOrNil = table.remove(mem.RemainingNodes, 1)
			else
				break
			end
		end
	end
	
	function lib.UpdateBotMem(bot)
		local mem = memByBot[bot]
		lib.UpdateBotPosMilestone(bot)
		lib.UpdateBotTgtOrNil(bot)
		lib.UpdateBotTgtProximity(bot)
		if mem.NextSlowThinkTime <= CurTime() then
			mem.NextSlowThinkTime = CurTime() + 0.5
			lib.UpdateBotAngsOffshoot(bot)
			lib.UpdateBotPath(bot)
		end
		lib.UpdateBotPathProgress(bot)
	end
	
	function lib.UpdateBotCmd(bot, cmd)
		cmd:ClearButtons()
		cmd:ClearMovement()
		
		if bot:Team() ~= TEAM_UNDEAD then return end
		
		if not bot:Alive() then
			cmd:SetButtons(IN_ATTACK)
			return
		end
		
		lib.UpdateBotMem(bot)
		local mem = memByBot[bot]
		
		local nodeOrNil = mem.NodeOrNil
		local nextNodeOrNil = mem.NextNodeOrNil
		
		if nodeOrNil and nextNodeOrNil and nextNodeOrNil.Pos.z > nodeOrNil.Pos.z + 55 then
			local wallParam = nextNodeOrNil.Params.Wall
			if wallParam == "Retarget" then
				lib.ResetBotTgtOrNil(bot)
			elseif wallParam == "Suicide" then
				bot:Kill()
				return
			end
		end
		
		-- Fill table with possible pounce target positions
		local pounceTargetPositions = {lib.GetBotAttackPosOrNilFuture(bot, 0, mem.pounceFlightTime or 1)}
		if mem.RemainingNodes[2] then table.insert(pounceTargetPositions, mem.RemainingNodes[2].Pos + Vector(0, 0, 1)) end
		if mem.RemainingNodes[1] then table.insert(pounceTargetPositions, mem.RemainingNodes[1].Pos + Vector(0, 0, 1)) end
		if nextNodeOrNil then table.insert(pounceTargetPositions, nextNodeOrNil.Pos + Vector(0, 0, 1)) end
		
		-- Find possible trajectory
		local trajectory
		if bot:IsOnGround() then
			for _, pounceTargetPos in ipairs(pounceTargetPositions) do
				if pounceTargetPos then
					local trajectories = lib.CanBotPounceToTarget(bot, pounceTargetPos)
					local timeToTarget = bot:GetPos():Distance(pounceTargetPos) / bot:GetMaxSpeed()
					if trajectories and (timeToTarget > trajectories[1].totalTime*1.3 or pounceTargetPos.z - bot:GetPos().z > 55) then
						trajectory = trajectories[1]
						break
					end
				end
			end
		end
		
		local getFaceOrigin = lib.GetViewCenter
		local facesTgt = false
		local pounce = false
		local facesHindrance = bot:GetVelocity():Length2D() < 0.20 * bot:GetMaxSpeed()
		local ternaryButton = 0
		local aimPos, aimAngle
		local weapon = bot:GetActiveWeapon()
		
		if (weapon and trajectory and CurTime() >= weapon:GetNextPrimaryFire() and CurTime() >= weapon:GetNextSecondaryFire() and CurTime() >= weapon.NextAllowPounce) or mem.pouncing then
			if trajectory then
				mem.pounceAngle = Angle(-math.deg(trajectory.pitch), math.deg(trajectory.yaw), 0)
				mem.pounceFlightTime = math.min(trajectory.t1 + bot:GetActiveWeapon().PounceStartDelay or 0, 1) -- Store flight time, and use it to iteratively get close to the correct intersection point
			end
			if not mem.pouncing then
				-- Started pouncing
				pounce = true
				mem.pouncingTimer = CurTime() + 1
				mem.pouncing = true
			elseif mem.pouncingTimer and mem.pouncingTimer < CurTime() and (CurTime() - mem.pouncingTimer > 5 or bot:WaterLevel() >= 2 or bot:IsOnGround()) then
				-- Ended pouncing
				mem.pouncing = false
				lib.UpdateBotMem(bot)
			end
			aimAngle = mem.pounceAngle
		elseif (lib.CanBotSeeTarget(bot) or not nextNodeOrNil) and lib.GetBotAttackPosOrNil(bot) then
			aimPos = lib.GetBotAttackPosOrNil(bot) + mem.TgtOrNil:GetVelocity() * math.Rand(0, lib.BotAimPosVelocityOffshoot)
			facesTgt = aimPos:Distance(lib.GetViewCenter(bot)) < lib.BotAttackDistMin
			if facesTgt and aimPos.z - lib.GetViewCenter(bot).z < -20 then
				ternaryButton = IN_DUCK
			end
		elseif nextNodeOrNil then
			aimPos = nextNodeOrNil.Pos
			getFaceOrigin = bot.GetPos
		else
			return
		end
		
		if mem.pouncing then facesHindrance = false end
		
		if aimAngle then
			mem.Angs = aimAngle
		elseif aimPos then
			lib.BotFace(bot, aimPos, getFaceOrigin)
		end
		cmd:SetViewAngles(mem.Angs)
		
		cmd:SetForwardMove(mem.Spd)
		
		local duckParam = nodeOrNil and nodeOrNil.Params.Duck
		local jumpParam = nodeOrNil and nodeOrNil.Params.Jump
		
		if bot:GetMoveType() ~= MOVETYPE_LADDER then
			if bot:IsOnGround() then
				if jumpParam == "Always" then
					ternaryButton = IN_JUMP
				elseif duckParam == "Always" then
					ternaryButton = IN_DUCK
				elseif facesHindrance then
					ternaryButton = math.random(lib.BotJumpAntichance) == 1 and IN_JUMP or IN_DUCK
				end
			else
				ternaryButton = IN_DUCK
			end
		end
		
		cmd:SetButtons(bit.band(
			bit.bor(IN_FORWARD, (facesTgt or facesHindrance) and IN_ATTACK or 0, ternaryButton, facesHindrance and IN_USE or 0, pounce and IN_ATTACK2 or 0, mem.ButtonsToBeClicked),
			bit.bnot((math.random(1, 2) == 1 or jumpParam == "Disabled") and IN_JUMP or 0)))
		mem.ButtonsToBeClicked = 0
	end
	
	function lib.HandleBotDamage(bot, dmg)
		local attacker = dmg:GetAttacker()
		if not lib.CanBeBotTgt(attacker) then return end
		local mem = memByBot[bot]
		if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():Distance(bot:GetPos()) <= lib.BotTgtFixationDistMin then return end
		mem.TgtOrNil = attacker
		lib.ResetBotPosMilestone(bot)
	end
end
