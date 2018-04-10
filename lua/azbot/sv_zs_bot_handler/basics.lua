AzBot.Basics = {}

function AzBot.Basics.SuicideOrRetarget(bot)
	local mem = bot.AzBot_Mem
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	if nodeOrNil and nextNodeOrNil and nextNodeOrNil.Pos.z > nodeOrNil.Pos.z + 55 then
		local wallParam = nextNodeOrNil.Params.Wall
		if wallParam == "Retarget" then
			bot:AzBot_ResetTgtOrNil()
		elseif wallParam == "Suicide" then
			bot:Kill()
			return
		end
	end
end

function AzBot.Basics.Walk(bot, pos) -- 'pos' should be inside the current or next node
	local mem = bot.AzBot_Mem
	if not mem then return end
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local getFaceOrigin = bot.GetPos
	local duck, jump
	
	bot:AzBot_FaceTo(pos, getFaceOrigin)
	
	local duckParam = nodeOrNil and nodeOrNil.Params.Duck
	local duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
	local jumpParam = nodeOrNil and nodeOrNil.Params.Jump
	local jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				jump = true
			end
			if duckParam == "Always" or duckToParam == "Always" then
				duck = true
			end
			if facesHindrance then
				if math.random(AzBot.BotJumpAntichance) == 1 then
					jump = true
				else
					duck = true
				end
			end
		else
			duck = true -- This prevents bots from getting out of water. Rewrite jump/crouch logic
		end
	end
	
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" then
		jump = false
	end
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		duck = false
	end
	
	local buttons = bit.bor(IN_FORWARD, (facesTgt or facesHindrance) and IN_ATTACK or 0, duck and IN_DUCK or 0, jump and IN_JUMP or 0, facesHindrance and IN_USE or 0)
	
	return true, buttons, forwardSpeed, mem.Angs
end

function AzBot.Basics.WalkAttackAuto(bot)
	local mem = bot.AzBot_Mem
	if not mem then return end
	
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local aimPos, getFaceOrigin
	local duck, jump
	local facesTgt = false
	
	if bot:AzBot_CanBotSeeTarget() or not nextNodeOrNil then
		aimPos = bot:AzBot_GetAttackPosOrNilFuture(nil, math.Rand(0, AzBot.BotAimPosVelocityOffshoot))
		getFaceOrigin = AzBot.GetViewCenter
		if aimPos:Distance(bot:AzBot_GetViewCenter()) < AzBot.BotAttackDistMin then
			if weapon and weapon.MeleeReach then
				local tr = util.TraceLine({
					start = bot:AzBot_GetViewCenter(),
					endpos = bot:AzBot_GetViewCenter() + bot:EyeAngles():Forward() * weapon.MeleeReach,
					filter = bot
				})
				facesTgt = tr.Entity == mem.TgtOrNil
			else
				facesTgt = true
			end
			if aimPos.z - bot:GetPos().z - bot:GetViewOffsetDucked().z < 0 then
				duck = true
			end
		end
	elseif nextNodeOrNil then
		-- Target not visible, walk towards next node
		return AzBot.Helper_Walk(bot, nextNodeOrNil.Pos)
	else
		return
	end
	
	local facesHindrance = bot:GetVelocity():Length2D() < 0.20 * bot:GetMaxSpeed()
	
	bot:AzBot_BotFace(aimPos, getFaceOrigin)
	
	local duckParam = nodeOrNil and nodeOrNil.Params.Duck
	local duckToParam = nextNodeOrNil and nextNodeOrNil.Params.DuckTo
	local jumpParam = nodeOrNil and nodeOrNil.Params.Jump
	local jumpToParam = nextNodeOrNil and nextNodeOrNil.Params.JumpTo
	
	if bot:GetMoveType() ~= MOVETYPE_LADDER then
		if bot:IsOnGround() then
			if jumpParam == "Always" or jumpToParam == "Always" then
				jump = true
			end
			if duckParam == "Always" or duckToParam == "Always" then
				duck = true
			end
			if facesHindrance then
				if math.random(AzBot.BotJumpAntichance) == 1 then
					jump = true
				else
					duck = true
				end
			end
		else
			duck = true -- This prevents bots from getting out of water. Rewrite jump/crouch logic
		end
	end
	
	if math.random(1, 2) == 1 or jumpParam == "Disabled" or jumpToParam == "Disabled" then
		jump = false
	end
	if duckParam == "Disabled" or duckToParam == "Disabled" then
		duck = false
	end
	
	local buttons = bit.bor(IN_FORWARD, (facesTgt or facesHindrance) and IN_ATTACK or 0, duck and IN_DUCK or 0, jump and IN_JUMP or 0, facesHindrance and IN_USE or 0)
	
	return true, buttons, forwardSpeed, mem.Angs
end

function AzBot.Basics.PounceAuto(bot)
	local mem = bot.AzBot_Mem
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
	for i = 1, 2 do
		if mem.RemainingNodes[i] then
			tempDist = tempDist + tempPos:Distance(mem.RemainingNodes[i].Pos)
			tempPos = mem.RemainingNodes[i].Pos
			table.insert(pounceTargetPositions, {Pos = mem.RemainingNodes[i].Pos + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 1.1})
		end
	end
	local tempAttackPosOrNil = bot:AzBot_GetAttackPosOrNilFuturePlatforms(0, mem.pounceFlightTime or 0)
	if tempAttackPosOrNil then
		tempDist = tempDist + bot:GetPos():Distance(tempAttackPosOrNil)
		table.insert(pounceTargetPositions, {Pos = tempAttackPosOrNil + Vector(0, 0, 1), Dist = tempDist, TimeFactor = 1.4, HeightDiff = 100})
	end
	
	-- Find best trajectory
	local trajectory
	for _, pounceTargetPos in ipairs(table.Reverse(pounceTargetPositions)) do
		local trajectories = bot:AzBot_CanPounceToPos(pounceTargetPos.Pos)
		local timeToTarget = pounceTargetPos.Dist / bot:GetMaxSpeed()
		if trajectories and (pounceTargetPos.ForcePounce or (pounceTargetPos.HeightDiff and pounceTargetPos.Pos.z - bot:GetPos().z > pounceTargetPos.HeightDiff) or timeToTarget > (trajectories[1].t1 + (mem.pouncingStartTime or CurTime()) - CurTime())*pounceTargetPos.TimeFactor) then
			trajectory = trajectories[1]
			break
		end
	end
	
	local aimAngle
	local buttons = 0
	
	if (trajectory and CurTime() >= weapon:GetNextPrimaryFire() and CurTime() >= weapon:GetNextSecondaryFire() and CurTime() >= weapon.NextAllowPounce) or mem.pouncing then
		if trajectory then
			aimAngle = Angle(-math.deg(trajectory.pitch), math.deg(trajectory.yaw), 0)
			mem.pounceFlightTime = math.min(trajectory.t1 + (mem.pouncingStartTime or CurTime()) - CurTime(), 3) -- Store flight time, and use it to iteratively get close to the correct intersection point. (Path prediction of the target)
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
			lib.UpdateBotMem(bot)
		end
		
		return true, buttons, forwardSpeed, aimAngle
	end
	
	return
end