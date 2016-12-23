
return function(lib)
	lib.IsEnabled = engine.ActiveGamemode() == "zombiesurvival"
	lib.BotAngOffshoot = 45
	lib.BotAimPosVelocityOffshoot = 0.1
	
	local memoryByBotPl = {}
	hook.Add("PlayerInitialSpawn", tostring({}), function(pl)
		if not pl:IsBot() then return end
		
		memoryByBotPl[pl] = {
			TargetPlOrNil = nil,
			NextNodeOrNil = nil,
			RemainingNodes = {},
			Angs = Angle(),
			AngsOffshoot = Angle(),
			NextUpdate = 0,
			NextTargetChange = 0 }
	end)
	hook.Add("PlayerSpawn", tostring({}), function(pl)
		if not pl:IsBot() then return end
		
		memoryByBotPl[pl].Angs = pl:EyeAngles()
	end)
	local function getAttackPos(targetPl) return LerpVector(0.75, targetPl:GetPos(), targetPl:EyePos()) end
	local function canSee(pl, targetPl)
		return not util.TraceLine{
			start = lib.GetViewCenter(pl),
			endpos = getAttackPos(targetPl),
			mask = MASK_PLAYERSOLID,
			filter = team.GetPlayers(TEAM_UNDEAD) }.Hit
	end
	hook.Add("StartCommand", tostring({}), function(pl, cmd)
		if not lib.IsEnabled or not pl:IsBot() or pl:Team() ~= TEAM_UNDEAD then return end
		
		cmd:ClearButtons()
		cmd:ClearMovement()
		
		if not pl:Alive() then
			cmd:SetButtons(IN_ATTACK)
			return
		end
		
		local memory = memoryByBotPl[pl]
		
		if not IsValid(memory.TargetPlOrNil) or memory.TargetPlOrNil:Team() ~= TEAM_HUMAN or memory.NextTargetChange < CurTime() then
			memory.NextTargetChange = CurTime() + math.random(60, 120)
			
			memory.TargetPlOrNil = table.Random(team.GetPlayers(TEAM_HUMAN))
		end
		
		if memory.NextUpdate < CurTime() then
			memory.NextUpdate = CurTime() + 0.5
			
			local angOffshoot = lib.BotAngOffshoot
			memory.AngsOffshoot = Angle(math.random(-angOffshoot, angOffshoot), math.random(-angOffshoot, angOffshoot), 0)
			
			if IsValid(memory.TargetPlOrNil) then
				local node = lib.MapNavMesh:GetNearestNodeOrNil(pl:GetPos())
				local targetNode = lib.MapNavMesh:GetNearestNodeOrNil(memory.TargetPlOrNil:GetPos())
				if node and targetNode then
					local path = lib.GetBestMeshPathOrNil(node, targetNode)
					if path then
						table.remove(path, 1)
						memory.NextNodeOrNil = table.remove(path, 1)
						memory.RemainingNodes = path
					end
				end
			end
		end
		
		while memory.NextNodeOrNil do
			if memory.NextNodeOrNil:GetContains(pl:GetPos()) then
				memory.NextNodeOrNil = table.remove(memory.RemainingNodes, 1)
			else
				break
			end
		end
		
		local aimPosOrNil
		local attacks = false
		if IsValid(memory.TargetPlOrNil) and (memory.NextNodeOrNil == nil or canSee(pl, memory.TargetPlOrNil)) then
			aimPosOrNil = getAttackPos(memory.TargetPlOrNil) + memory.TargetPlOrNil:GetVelocity() * math.Rand(0, lib.BotAimPosVelocityOffshoot)
			attacks = lib.GetViewCenter(pl):Distance(aimPosOrNil) < 100
		elseif memory.NextNodeOrNil then
			aimPosOrNil = memory.NextNodeOrNil.Pos
		end
		if aimPosOrNil then
			memory.Angs = LerpAngle(0.5, memory.Angs, (aimPosOrNil - lib.GetViewCenter(pl)):Angle() + memory.AngsOffshoot)
			cmd:SetViewAngles(memory.Angs)
			
			cmd:SetForwardMove(999999)
			
			local facesHindrance = pl:GetVelocity():Length2D() < 0.25 * pl:GetMaxSpeed()
			
			local ternaryButton = 0
			if pl:GetMoveType() == MOVETYPE_LADDER then
				if IsValid(memory.TargetPlOrNil) and canSee(pl, memory.TargetPlOrNil) then ternaryButton = IN_JUMP end
			else
				if pl:IsOnGround() then
					if facesHindrance then ternaryButton = math.random(2) == 1 and IN_JUMP or IN_DUCK end
				else
					ternaryButton = IN_DUCK
				end
			end
			
			cmd:SetButtons(bit.bor(IN_FORWARD, (attacks or facesHindrance) and IN_ATTACK or 0, ternaryButton))
		end
	end)
end
