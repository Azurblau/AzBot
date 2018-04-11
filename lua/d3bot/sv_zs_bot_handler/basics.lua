D3bot.Basics = {}

function D3bot.Basics.SuicideOrRetarget(bot)
	local mem = bot.D3bot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	if nodeOrNil and nextNodeOrNil and nextNodeOrNil.Pos.z > nodeOrNil.Pos.z + 55 then
		local wallParam = nextNodeOrNil.Params.Wall
		if wallParam == "Retarget" then
			bot:D3bot_ResetTgtOrNil()
		elseif wallParam == "Suicide" then
			bot:Kill()
			return
		end
	end
end

function D3bot.Basics.CheckStuck(bot)
	local mem = bot.D3bot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	if nodeOrNil and nextNodeOrNil and nextNodeOrNil.Pos.z > nodeOrNil.Pos.z + 55 then
		local wallParam = nextNodeOrNil.Params.Wall
		if wallParam == "Retarget" then
			bot:D3bot_ResetTgtOrNil()
		elseif wallParam == "Suicide" then
			bot:Kill()
			return
		end
	end
end

function D3bot.Basics.Walk(bot, pos) -- 'pos' should be inside the current or next node
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local origin = bot:GetPos()
	local duck, jump
	
	bot:D3bot_FaceTo(pos, origin, D3bot.BotAngLerpFactor)
	
	local duckParam = nodeOrNil and nodeOrNil.Params.Duck
	local duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
	local jumpParam = nodeOrNil and nodeOrNil.Params.Jump
	local jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	
	local facesHindrance = bot:GetVelocity():Length2D() < 0.20 * bot:GetMaxSpeed()
	
	if duckParam == "Always" or duckToParam == "Always" then
		duck = true
	end
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				jump = true
			end
			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					jump = true
				else
					duck = true
				end
			end
		else
			duck = true
		end
	end
	
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" then
		jump = false
	end
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		duck = false
	end
	
	local buttons = bit.bor(IN_FORWARD, (facesTgt or facesHindrance) and IN_ATTACK or 0, duck and IN_DUCK or 0, jump and IN_JUMP or 0, facesHindrance and IN_USE or 0)
	
	return true, buttons, bot:GetMaxSpeed(), mem.Angs
end

function D3bot.Basics.WalkAttackAuto(bot)
	local mem = bot.D3bot_Mem
	if not mem then return end
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local aimPos, origin
	local duck, jump
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
				duck = true
			end
		end
	elseif nextNodeOrNil then
		-- Target not visible, walk towards next node
		return D3bot.Basics.Walk(bot, nextNodeOrNil.Pos)
	else
		return
	end
	
	if aimPos then
		bot:D3bot_FaceTo(aimPos, origin, D3bot.BotAttackAngLerpFactor)
	end
	
	local duckParam = nodeOrNil and nodeOrNil.Params.Duck
	local duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
	local jumpParam = nodeOrNil and nodeOrNil.Params.Jump
	local jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	
	local facesHindrance = bot:GetVelocity():Length2D() < 0.20 * bot:GetMaxSpeed()
	
	if duckParam == "Always" or duckToParam == "Always" then
		duck = true
	end
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				jump = true
			end
			if facesHindrance then
				if math.random(D3bot.BotJumpAntichance) == 1 then
					jump = true
				else
					duck = true
				end
			end
		else
			duck = true
		end
	end
	
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" then
		jump = false
	end
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		duck = false
	end
	
	local buttons = bit.bor(IN_FORWARD, (facesTgt or facesHindrance) and IN_ATTACK or 0, duck and IN_DUCK or 0, jump and IN_JUMP or 0, facesHindrance and IN_USE or 0)
	
	return true, buttons, bot:GetMaxSpeed(), mem.Angs
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
	for k, v in ipairs(mem.RemainingNodes) do
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
	
	local buttons = 0
	
	if (trajectory and CurTime() >= weapon:GetNextPrimaryFire() and CurTime() >= weapon:GetNextSecondaryFire() and CurTime() >= weapon.NextAllowPounce) or mem.pouncing then
		if trajectory then
			mem.Angs = Angle(-math.deg(trajectory.pitch), math.deg(trajectory.yaw), 0)
			mem.pounceFlightTime = math.Clamp(trajectory.t1 + (mem.pouncingStartTime or CurTime()) - CurTime(), 0, 1) -- Store flight time, and use it to iteratively get close to the correct intersection point.
		end
		if not mem.pouncing then
			-- Started pouncing
			buttons = IN_ATTACK2
			mem.pouncingTimer = CurTime() + 1
			mem.pouncingStartTime = CurTime() + weapon.PounceStartDelay
			mem.pouncing = true
		elseif mem.pouncingTimer and mem.pouncingTimer < CurTime() and (CurTime() - mem.pouncingTimer > 5 or bot:WaterLevel() >= 2 or bot:IsOnGround()) then
			-- Ended pouncing
			mem.pouncing = false
			mem.pounceFlightTime = nil
			bot:D3bot_UpdateMem(bot)
		end
		
		return true, buttons, 0, mem.Angs
	end
	
	return
end