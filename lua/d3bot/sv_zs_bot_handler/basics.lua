D3bot.Basics = {}

function D3bot.Basics.SuicideOrRetarget(bot)
	local mem = bot.D3bot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	if nodeOrNil and nextNodeOrNil and nextNodeOrNil.Pos.z > nodeOrNil.Pos.z + 55 then
		local wallParam = nextNodeOrNil.Params.Wall
		if wallParam == "Retarget" then
			local handler = findHandler(bot:GetZombieClass(), bot:Team())
			if handler and handler.RerollTarget then handler.RerollTarget(bot) end
			return
		elseif wallParam == "Suicide" then
			bot:Kill()
			return
		end
	end
end

function D3bot.Basics.Walk(bot, pos, slowdown, proximity) -- 'pos' should be inside the current or next node
	local mem = bot.D3bot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local origin = bot:GetPos()
	local actions = {}
	
	-- TODO: Recalculate offshoot when outside of current area (2D), to make it face inside that area again. (Borders towards 'pos' are ignored)
	-- This will prevent bots from falling over edges
	bot:D3bot_FaceTo(pos, origin, D3bot.BotAngLerpFactor)
	
	local duckParam = nodeOrNil and nodeOrNil.Params.Duck
	local duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
	local jumpParam = nodeOrNil and nodeOrNil.Params.Jump
	local jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	
	-- Slow down bot when close to target (2D distance)
	local tempPos = Vector(pos.x, pos.y, origin.z)
	local invProximity = math.Clamp((origin:Distance(tempPos) - (proximity or 10))/60, 0, 1)
	local speed = bot:GetMaxSpeed() * (slowdown and invProximity or 1)
	
	local facesHindrance = bot:GetVelocity():Length2D() < 0.20 * speed - 10
	local minorStuck, majorStuck = bot:D3bot_CheckStuck()
	
	if duckParam == "Always" or duckToParam == "Always" then
		actions.Duck = true
	end
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				actions.Jump = true
			end
			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					actions.Jump = true
				else
					actions.Duck = true
				end
			end
		else
			actions.Duck = true
		end
	elseif minorStuck then
		actions.Jump = true
		actions.Duck = true
		actions.Use = true
	end
	
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" then
		actions.Jump = false
	end
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		actions.Duck = false
	end
	
	actions.Attack = facesHindrance
	actions.Use = actions.Use or facesHindrance
	
	return true, actions, speed, mem.Angs, majorStuck
end

function D3bot.Basics.WalkAttackAuto(bot)
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local aimPos, origin
	local actions = {}
	local facesTgt = false
	
	-- TODO: Reduce can see target calls
	if mem.TgtOrNil and (bot:D3bot_CanSeeTarget() or not nextNodeOrNil) then
		aimPos = bot:D3bot_GetAttackPosOrNilFuture(nil, math.Rand(0, D3bot.BotAimPosVelocityOffshoot))
		origin = bot:D3bot_GetViewCenter()
		if aimPos and aimPos:Distance(bot:D3bot_GetViewCenter()) < D3bot.BotAttackDistMin then
			if weapon and weapon.MeleeReach then
				local tr = util.TraceLine({
					start = bot:D3bot_GetViewCenter(),
					endpos = bot:D3bot_GetViewCenter() + bot:EyeAngles():Forward() * weapon.MeleeReach,
					filter = bot
				})
				facesTgt = tr.Entity == mem.TgtOrNil
			else
				facesTgt = true
			end
			if aimPos.z < bot:GetPos().z + bot:GetViewOffsetDucked().z then
				actions.Duck = true
			end
		end
	elseif mem.PosTgtOrNil and not nextNodeOrNil then
		-- Go straight to position target
		return D3bot.Basics.Walk(bot, mem.PosTgtOrNil, true, mem.PosTgtProximity)
	elseif nextNodeOrNil then
		-- Target not visible, walk towards next node
		return D3bot.Basics.Walk(bot, nextNodeOrNil.Pos)
	else
		return
	end
	
	if aimPos then
		bot:D3bot_FaceTo(aimPos, origin, D3bot.BotAttackAngLerpFactor, facesTgt and 0.2 or 1)
	end
	
	local duckParam = nodeOrNil and nodeOrNil.Params.Duck
	local duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
	local jumpParam = nodeOrNil and nodeOrNil.Params.Jump
	local jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	
	local facesHindrance = bot:GetVelocity():Length2D() < 0.20 * bot:GetMaxSpeed()
	local minorStuck, majorStuck = bot:D3bot_CheckStuck()
	
	if duckParam == "Always" or duckToParam == "Always" then
		actions.Duck = true
	end
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				actions.Jump = true
			end
			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					actions.Jump = true
				else
					actions.Duck = true
				end
			end
		else
			actions.Duck = true
		end
	elseif minorStuck then
		actions.Jump = true
		actions.Duck = true
		actions.Use = true
	end
	
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" then
		actions.Jump = false
	end
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		actions.Duck = false
	end
	
	actions.Attack = facesTgt or facesHindrance
	actions.Use = actions.Use or facesHindrance
	
	return true, actions, bot:GetMaxSpeed(), mem.Angs, majorStuck
end

function D3bot.Basics.PounceAuto(bot)
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	if not bot:IsOnGround() or bot:GetMoveType() == MOVETYPE_LADDER then return end
	
	local weapon = bot:GetActiveWeapon()
	if not weapon and not weapon.PounceVelocity then return end
	
	-- Fill table with possible pounce target positions, ordered with increasing priority
	local tempPos = bot:GetPos()
	local tempDist = 0
	local pounceTargetPositions = {}
	if nextNodeOrNil then
		tempDist = tempDist + tempPos:Distance(nextNodeOrNil.Pos)
		tempPos = nextNodeOrNil.Pos
		table.insert(pounceTargetPositions, {Pos = nextNodeOrNil.Pos + Vector(0, 0, 1),
											 Dist = tempDist,
											 TimeFactor = 1.1,
											 ForcePounce = (nextNodeOrNil.LinkByLinkedNode[nodeOrNil] and nextNodeOrNil.LinkByLinkedNode[nodeOrNil].Params.Pouncing == "Needed")})
	end
	local i = 0
	for k, v in ipairs(mem.RemainingNodes) do -- TODO: Check if it behaves as expected
		tempDist = tempDist + tempPos:Distance(v.Pos)
		tempPos = v.Pos
		table.insert(pounceTargetPositions, {Pos = v.Pos + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 1.1})
		i = i + 1
		if i == 2 then break end
	end
	local tempAttackPosOrNil = bot:D3bot_GetAttackPosOrNilFuturePlatforms(0, mem.pounceFlightTime or 0)
	if tempAttackPosOrNil then
		tempDist = tempDist + bot:GetPos():Distance(tempAttackPosOrNil)
		table.insert(pounceTargetPositions, {Pos = tempAttackPosOrNil + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 0.8, HeightDiff = 100}) -- TODO: Global bot 'IQ' level influences TimeFactor, the lower the more likely they will cut off the players path
	elseif mem.PosTgtOrNil then
		tempDist = tempDist + bot:GetPos():Distance(mem.PosTgtOrNil)
		table.insert(pounceTargetPositions, {Pos = mem.PosTgtOrNil + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 0.8, HeightDiff = 100})
	end
	
	-- Find best trajectory
	local trajectory
	for _, pounceTargetPos in ipairs(table.Reverse(pounceTargetPositions)) do
		local trajectories = bot:D3bot_CanPounceToPos(pounceTargetPos.Pos)
		local timeToTarget = pounceTargetPos.Dist / bot:GetMaxSpeed()
		if trajectories and (pounceTargetPos.ForcePounce or (pounceTargetPos.HeightDiff and pounceTargetPos.Pos.z - bot:GetPos().z > pounceTargetPos.HeightDiff) or timeToTarget > (trajectories[1].t1 + weapon.PounceStartDelay)*pounceTargetPos.TimeFactor) then
			trajectory = trajectories[1]
			break
		end
	end
	
	local actions = {}
	
	if (trajectory and CurTime() >= weapon:GetNextPrimaryFire() and CurTime() >= weapon:GetNextSecondaryFire() and CurTime() >= weapon.NextAllowPounce) or mem.pouncing then
		if trajectory then
			mem.Angs = Angle(-math.deg(trajectory.pitch), math.deg(trajectory.yaw), 0)
			mem.pounceFlightTime = math.Clamp(trajectory.t1 + (mem.pouncingStartTime or CurTime()) - CurTime(), 0, 1) -- Store flight time, and use it to iteratively get close to the correct intersection point.
		end
		if not mem.pouncing then
			-- Started pouncing
			actions.Attack2 = true
			mem.pouncingTimer = CurTime() + 1
			mem.pouncingStartTime = CurTime() + weapon.PounceStartDelay
			mem.pouncing = true
		elseif mem.pouncingTimer and mem.pouncingTimer < CurTime() and (CurTime() - mem.pouncingTimer > 5 or bot:WaterLevel() >= 2 or bot:IsOnGround()) then
			-- Ended pouncing
			mem.pouncing = false
			mem.pounceFlightTime = nil
			bot:D3bot_UpdatePathProgress()
		end
		
		return true, actions, 0, mem.Angs, false
	end
	
	return
end

function D3bot.Basics.Aim(bot, target)
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	local actions = {}
	
	if not IsValid(target) then return end
	local weapon = bot:GetActiveWeapon()
	if not IsValid(weapon) then return end
	if weapon:Clip1() == 0 then actions.Reload = math.random(10) == 1 end
	
	local origin = bot:D3bot_GetViewCenter()
	local targetPos = LerpVector(math.random(5, 10)/10, target:GetPos(), target:EyePos())
	
	if targetPos then
		bot:D3bot_FaceTo(targetPos, origin, D3bot.BotAttackAngLerpFactor * 2, 0)
	end
	
	return true, actions, 0, mem.Angs, false
end