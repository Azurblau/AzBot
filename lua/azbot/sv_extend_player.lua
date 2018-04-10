local meta = FindMetaTable( "Player" )

function meta:AzBot_GetAttackPosOrNil(fraction)
	local mem = self.AzBot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) or tgt:WorldSpaceCenter()
end

function meta:AzBot_GetAttackPosOrNil(fraction)
	local mem = self.AzBot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) or tgt:WorldSpaceCenter()
end

-- Position prediction
function meta:AzBot_GetAttackPosOrNilFuture(fraction, t)
	local mem = self.AzBot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + tgt:GetVelocity()*t or tgt:WorldSpaceCenter()
end

-- Position prediction with platform physics
function meta:AzBot_GetAttackPosOrNilFuturePlatforms(fraction, t)
	local mem = self.AzBot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	local phys = tgt:GetPhysicsObject() 
	if not IsValid(phys) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + phys:GetVelocity()*t or tgt:WorldSpaceCenter()
end

function meta:AzBot_GetViewCenter() return self:GetPos() + (self:Crouching() and self:GetViewOffsetDucked() or self:GetViewOffset()) end

function meta:AzBot_CanPounceToPos(pos)
	if not pos then return end
	
	local initVel
	if self:GetActiveWeapon() and self:GetActiveWeapon().PounceVelocity then
		initVel = (1 - 0.5 * (self:GetLegDamage() / GAMEMODE.MaxLegDamage)) * self:GetActiveWeapon().PounceVelocity
	else
		return
	end
	
	local selfPos = self:GetPos()--LerpVector(0.75, self:GetPos(), self:EyePos())
	local trajectories = AzBot.GetTrajectories(initVel, selfPos, pos, 8)
	local resultTrajectories = {}
	for _, trajectory in ipairs(trajectories) do
		local lastPoint = nil
		local hit = false
		for _, point in ipairs(trajectory.points) do
			if lastPoint then
				local tr = util.TraceEntity({start = point, endpos = lastPoint, filter = player.GetAll()}, self)
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

function meta:AzBot_CanSeeTarget()
	local attackPos = self:AzBot_GetAttackPosOrNil()
	if not attackPos then return false end
	local mem = self.AzBot_Mem
	if mem.TgtNodeOrNil and mem.NodeOrNil ~= mem.TgtNodeOrNil and mem.TgtNodeOrNil.Params.See == "Disabled" then return false end
	local tr = AzBot.BotSeeTr
	tr.start = self:AzBot_GetViewCenter()
	tr.endpos = attackPos
	tr.filter = player.GetAll()
	return attackPos and not util.TraceHull(tr).Hit
end

function meta:AzBot_FaceTo(pos, origin)
	local mem = self.AzBot_Mem
	mem.Angs = LerpAngle(AzBot.BotAngLerpFactor, mem.Angs, (pos - origin):Angle() + mem.AngsOffshoot)
end

function meta:AzBot_RerollClass()
	if not GAMEMODE:GetWaveActive() then return end
	if self:GetZombieClassTable().Name == "Zombie Torso" then return end
	if GAMEMODE.ZombieEscape then return end
	local zombieClasses = {}
	for _, class in ipairs(AzBot.BotClasses) do
		local zombieClass = GAMEMODE.ZombieClasses[class]
		if zombieClass then
			if not zombieClass.Locked and (zombieClass.Unlocked or zombieClass.Wave <= GAMEMODE:GetWave()) then
				table.insert(zombieClasses, zombieClass)
			end
		end
	end
	local zombieClass = table.Random(zombieClasses)
	if not zombieClass then zombieClass = GAMEMODE.ZombieClasses[GAMEMODE.DefaultZombieClass] end
	self:SetZombieClass(zombieClass.Index)
end

function meta:AzBot_ResetTgtOrNil()
	local targets = AzBot.PotBotTgts
	table.RemoveByValue(targets, self)
	self.AzBot_Mem.TgtOrNil = table.Random(targets)
end

function meta:AzBot_UpdateTgtOrNil() if not AzBot.CanBeBotTgt(self.AzBot_Mem.TgtOrNil) then self:AzBot_ResetTgtOrNil() end end

function meta:AzBot_Initialize()
	if AzBot.MaintainBotRolesAutomatically then
		GAMEMODE.PreviouslyDied[self:UniqueID()] = CurTime()
		GAMEMODE:PlayerInitialSpawn(self)
	end
	
	self.AzBot_Mem = {
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
		ButtonsToBeClicked = 0
	}
end

function meta:AzBot_SetUp()
	local mem = self.AzBot_Mem
	self:AzBot_ResetPosMilestone()
	mem.TgtOrNil = nil
	mem.NextNodeOrNil = nil
	mem.RemainingNodes = {}
	mem.ConsidersPathLethality = math.random(1, AzBot.BotConsideringDeathCostAntichance) == 1
	mem.Angs = self:EyeAngles()
	mem.NextSlowThinkTime = 0
end

function meta:AzBot_ResetPosMilestone()
	self:AzBot_SetPosMilestone()
	self:AzBot_SetZeroPosMilestone()
	self.AzBot_Mem.NextFailPosMilestone = self.AzBot_FailFirstPosMilestone
end

function meta:AzBot_UpdatePosMilestone()
	local mem = self.AzBot_Mem
	if mem.NextZeroPosMilestoneTime <= CurTime() then
		if self:GetPos() == mem.ZeroPosMilestone then
			--if self:GetMoveType() == MOVETYPE_LADDER then
			--	mem.ButtonsToBeClicked = bit.bor(mem.ButtonsToBeClicked, IN_JUMP)
			-- TODO: Put that somewhere else
			-- else
				-- self:Kill()
				-- self:AzBot_ResetPosMilestone()
				-- return
			--end
		end
		self:AzBot_SetZeroPosMilestone()
	end
	if mem.NextPosMilestoneTime > CurTime() then return end
	local failed = self:GetPos():Distance(mem.PosMilestone) < AzBot.BotPosMilestoneDistMin
	self:AzBot_SetPosMilestone()
	if failed then mem.NextFailPosMilestone(self) end
end

function meta:AzBot_SetPosMilestone()
	local mem = self.AzBot_Mem
	mem.PosMilestone = self:GetPos()
	mem.NextPosMilestoneTime = CurTime() + AzBot.BotPosMilestoneUpdateDelay - math.random(0, math.floor(AzBot.BotPosMilestoneUpdateDelay * 0.5))
end

function meta:AzBot_SetZeroPosMilestone()
	local mem = self.AzBot_Mem
	mem.ZeroPosMilestone = self:GetPos()
	mem.NextZeroPosMilestoneTime = CurTime() + AzBot.BotZeroPosMilestoneUpdateDelay
end

function meta:AzBot_FailFirstPosMilestone()
	local mem = self.AzBot_Mem
	self:AzBot_ResetTgtOrNil()
	mem.NextFailPosMilestone = self.AzBot_FailSecondPosMilestone
	--mem.ButtonsToBeClicked = bit.bor(mem.ButtonsToBeClicked, IN_JUMP)
	-- TODO: Put that jump somewhere else
end

function meta:AzBot_FailSecondPosMilestone()
	self:Kill()
	self:AzBot_ResetPosMilestone()
end

function meta:AzBot_UpdateTgtProximity()
	local mem = self.AzBot_Mem
	local inverseFactor = IsValid(mem.TgtOrNil) and math.min(1, self:GetPos():Distance(mem.TgtOrNil:GetPos()) / AzBot.BotTgtAreaRadius) or 1
	mem.Spd = self:GetMaxSpeed() * (AzBot.BotMinSpdFactor + (1 - AzBot.BotMinSpdFactor) * inverseFactor)
	mem.AngOffshoot = AzBot.BotAngOffshoot + AzBot.BotAdditionalAngOffshoot * (1 - inverseFactor)
end

function meta:AzBot_UpdateAngsOffshoot()
	local mem = self.AzBot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	if (nodeOrNil and nodeOrNil.Params.Aim == "Straight") or (nextNodeOrNil and nextNodeOrNil.Params.AimTo == "Straight") then
		mem.AngsOffshoot = Angle()
		return
	end
	local angOffshoot = mem.AngOffshoot
	mem.AngsOffshoot = Angle(math.random(-angOffshoot, angOffshoot), math.random(-angOffshoot, angOffshoot), 0)
end

function meta:AzBot_UpdatePath()
	local mem = self.AzBot_Mem
	if not IsValid(mem.TgtOrNil) then return end
	local mapNavMesh = AzBot.MapNavMesh
	local node = mapNavMesh:GetNearestNodeOrNil(self:GetPos())
	mem.TgtNodeOrNil = mapNavMesh:GetNearestNodeOrNil(mem.TgtOrNil:GetPos())
	if not node or not mem.TgtNodeOrNil then return end
	local abilities = {Walk = true}
	if self:GetActiveWeapon() and self:GetActiveWeapon().PounceVelocity then abilities.Pounce = true end
	local path = AzBot.GetBestMeshPathOrNil(node, mem.TgtNodeOrNil, mem.ConsidersPathLethality and AzBot.DeathCostOrNilByLink or {}, abilities)
	if not path then self:AzBot_ResetTgtOrNil() return end
	if mem.NextNodeOrNil and mem.NextNodeOrNil == path[1] then table.insert(path, 1, mem.NodeOrNil) end -- Preserve current node if the path starts with the next node
	mem.NodeOrNil = table.remove(path, 1)
	mem.NextNodeOrNil = table.remove(path, 1)
	mem.RemainingNodes = path
	if mem.NodeOrNil and mem.NodeOrNil.Params.BotMod then
		AzBot.nodeZombiesCountAddition = mem.NodeOrNil.Params.BotMod
	end
end

function meta:AzBot_UpdatePathProgress()
	local mem = self.AzBot_Mem
	while mem.NextNodeOrNil do
		if mem.NextNodeOrNil:GetContains(self:GetPos()) then
			mem.NodeOrNil = mem.NextNodeOrNil
			mem.NextNodeOrNil = table.remove(mem.RemainingNodes, 1)
			if mem.NodeOrNil and mem.NodeOrNil.Params.BotMod then
				AzBot.nodeZombiesCountAddition = mem.NodeOrNil.Params.BotMod
				-- TODO: Change node botmod to trigger on human
			end
		else
			break
		end
	end
end

function meta:AzBot_UpdateMem()
	local mem = self.AzBot_Mem
	self:AzBot_UpdatePosMilestone()
	self:AzBot_UpdateTgtOrNil()
	self:AzBot_UpdateTgtProximity()
	if mem.NextSlowThinkTime <= CurTime() then
		mem.NextSlowThinkTime = CurTime() + 0.5
		self:AzBot_UpdateAngsOffshoot()
		self:AzBot_UpdatePath()
	end
	self:AzBot_UpdatePathProgress()
end