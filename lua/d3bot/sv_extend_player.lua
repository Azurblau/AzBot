local meta = FindMetaTable("Player")

function meta:D3bot_GetAttackPosOrNil(fraction)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) or tgt:WorldSpaceCenter()
end

function meta:D3bot_GetAttackPosOrNil(fraction)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) or tgt:WorldSpaceCenter()
end

-- Position prediction
function meta:D3bot_GetAttackPosOrNilFuture(fraction, t)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + tgt:GetVelocity()*t or tgt:WorldSpaceCenter()
end

-- Position prediction with platform physics
function meta:D3bot_GetAttackPosOrNilFuturePlatforms(fraction, t)
	local mem = self.D3bot_Mem
	local tgt = mem.TgtOrNil
	if not IsValid(tgt) then return end
	local phys = tgt:GetPhysicsObject()
	if not IsValid(phys) then return end
	return tgt:IsPlayer() and LerpVector(fraction or 0.75, tgt:GetPos(), tgt:EyePos()) + phys:GetVelocity()*t or tgt:WorldSpaceCenter()
end

function meta:D3bot_GetViewCenter() return self:GetPos() + (self:Crouching() and self:GetViewOffsetDucked() or self:GetViewOffset()) end

function meta:D3bot_CanPounceToPos(pos)
	if not pos then return end
	
	local initVel
	if self:GetActiveWeapon() and self:GetActiveWeapon().PounceVelocity then
		initVel = (1 - 0.5 * (self:GetLegDamage() / GAMEMODE.MaxLegDamage)) * self:GetActiveWeapon().PounceVelocity
	else
		return
	end
	
	local selfPos = self:GetPos()--LerpVector(0.75, self:GetPos(), self:EyePos())
	local trajectories = D3bot.GetTrajectories(initVel, selfPos, pos, 8)
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

function meta:D3bot_CanSeeTarget()
	local attackPos = self:D3bot_GetAttackPosOrNil()
	if not attackPos then return false end
	local mem = self.D3bot_Mem
	if mem.TgtNodeOrNil and mem.NodeOrNil ~= mem.TgtNodeOrNil and mem.TgtNodeOrNil.Params.See == "Disabled" then return false end
	local tr = D3bot.BotSeeTr
	tr.start = self:D3bot_GetViewCenter()
	tr.endpos = attackPos
	tr.filter = player.GetAll()
	return attackPos and not util.TraceHull(tr).Hit
end

function meta:D3bot_FaceTo(pos, origin, lerpFactor)
	local mem = self.D3bot_Mem
	mem.Angs = LerpAngle(lerpFactor, mem.Angs, (pos - origin):Angle() + mem.AngsOffshoot)
	-- TODO: Recalculate offshoot when outside of current area (2D), to make it face inside that area again. (Borders towards the next node are ignored)
	-- This will prevent bots from falling over edges
end

function meta:D3bot_RerollClass()
	if not GAMEMODE:GetWaveActive() then return end
	if self:GetZombieClassTable().Name == "Zombie Torso" then return end
	if GAMEMODE.ZombieEscape then return end
	local zombieClasses = {}
	for _, class in ipairs(D3bot.BotClasses) do
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

function meta:D3bot_ResetTgtOrNil()
	local targets = D3bot.PotBotTgts
	table.RemoveByValue(targets, self)
	self.D3bot_Mem.TgtOrNil = table.Random(targets)
end

function meta:D3bot_UpdateTgtOrNil() if not D3bot.CanBeBotTgt(self.D3bot_Mem.TgtOrNil) then self:D3bot_ResetTgtOrNil() end end

function meta:D3bot_Initialize()
	if D3bot.MaintainBotRolesAutomatically then
		--GAMEMODE.PreviouslyDied[self:UniqueID()] = CurTime()
		--GAMEMODE:PlayerInitialSpawn(self)
	end
	
	self.D3bot_Mem = {
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

function meta:D3bot_SetUp()
	local mem = self.D3bot_Mem
	self:D3bot_ResetPosMilestone()
	mem.TgtOrNil = nil
	mem.NextNodeOrNil = nil
	mem.RemainingNodes = {}
	mem.ConsidersPathLethality = math.random(1, D3bot.BotConsideringDeathCostAntichance) == 1
	mem.Angs = self:EyeAngles()
	mem.NextSlowThinkTime = 0
end

function meta:D3bot_ResetPosMilestone()
	self:D3bot_SetPosMilestone()
	self:D3bot_SetZeroPosMilestone()
	self.D3bot_Mem.NextFailPosMilestone = self.D3bot_FailFirstPosMilestone
end

function meta:D3bot_UpdatePosMilestone()
	local mem = self.D3bot_Mem
	if mem.NextZeroPosMilestoneTime <= CurTime() then
		if self:GetPos() == mem.ZeroPosMilestone then
			--if self:GetMoveType() == MOVETYPE_LADDER then
			--	mem.ButtonsToBeClicked = bit.bor(mem.ButtonsToBeClicked, IN_JUMP)
			-- TODO: Put that somewhere else
			-- else
				-- self:Kill()
				-- self:D3bot_ResetPosMilestone()
				-- return
			--end
		end
		self:D3bot_SetZeroPosMilestone()
	end
	if mem.NextPosMilestoneTime > CurTime() then return end
	local failed = self:GetPos():Distance(mem.PosMilestone) < D3bot.BotPosMilestoneDistMin
	self:D3bot_SetPosMilestone()
	if failed then mem.NextFailPosMilestone(self) end
end

function meta:D3bot_SetPosMilestone()
	local mem = self.D3bot_Mem
	mem.PosMilestone = self:GetPos()
	mem.NextPosMilestoneTime = CurTime() + D3bot.BotPosMilestoneUpdateDelay - math.random(0, math.floor(D3bot.BotPosMilestoneUpdateDelay * 0.5))
end

function meta:D3bot_SetZeroPosMilestone()
	local mem = self.D3bot_Mem
	mem.ZeroPosMilestone = self:GetPos()
	mem.NextZeroPosMilestoneTime = CurTime() + D3bot.BotZeroPosMilestoneUpdateDelay
end

function meta:D3bot_FailFirstPosMilestone()
	local mem = self.D3bot_Mem
	self:D3bot_ResetTgtOrNil()
	mem.NextFailPosMilestone = self.D3bot_FailSecondPosMilestone
	--mem.ButtonsToBeClicked = bit.bor(mem.ButtonsToBeClicked, IN_JUMP)
	-- TODO: Put that jump somewhere else
end

function meta:D3bot_FailSecondPosMilestone()
	self:Kill()
	self:D3bot_ResetPosMilestone()
end

function meta:D3bot_UpdateTgtProximity()
	local mem = self.D3bot_Mem
	local inverseFactor = IsValid(mem.TgtOrNil) and math.min(1, self:GetPos():Distance(mem.TgtOrNil:GetPos()) / D3bot.BotTgtAreaRadius) or 1
	mem.Spd = self:GetMaxSpeed() * (D3bot.BotMinSpdFactor + (1 - D3bot.BotMinSpdFactor) * inverseFactor)
	mem.AngOffshoot = D3bot.BotAngOffshoot + D3bot.BotAdditionalAngOffshoot * (1 - inverseFactor)
end

function meta:D3bot_UpdateAngsOffshoot()
	local mem = self.D3bot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	if (nodeOrNil and nodeOrNil.Params.Aim == "Straight") or (nextNodeOrNil and nextNodeOrNil.Params.AimTo == "Straight") then
		mem.AngsOffshoot = Angle()
		return
	end
	local angOffshoot = mem.AngOffshoot
	mem.AngsOffshoot = Angle(math.random(-angOffshoot, angOffshoot), math.random(-angOffshoot, angOffshoot), 0)
end

function meta:D3bot_UpdatePath()
	local mem = self.D3bot_Mem
	if not IsValid(mem.TgtOrNil) then return end
	local mapNavMesh = D3bot.MapNavMesh
	local node = mapNavMesh:GetNearestNodeOrNil(self:GetPos())
	mem.TgtNodeOrNil = mapNavMesh:GetNearestNodeOrNil(mem.TgtOrNil:GetPos())
	if not node or not mem.TgtNodeOrNil then return end
	local abilities = {Walk = true}
	if self:GetActiveWeapon() and self:GetActiveWeapon().PounceVelocity then abilities.Pounce = true end
	local path = D3bot.GetBestMeshPathOrNil(node, mem.TgtNodeOrNil, mem.ConsidersPathLethality and D3bot.DeathCostOrNilByLink or {}, abilities)
	if not path then self:D3bot_ResetTgtOrNil() return end
	if mem.NextNodeOrNil and mem.NextNodeOrNil == path[1] then table.insert(path, 1, mem.NodeOrNil) end -- Preserve current node if the path starts with the next node
	mem.NodeOrNil = table.remove(path, 1)
	mem.NextNodeOrNil = table.remove(path, 1)
	mem.RemainingNodes = path
	if mem.NodeOrNil and mem.NodeOrNil.Params.BotMod then
		D3bot.nodeZombiesCountAddition = mem.NodeOrNil.Params.BotMod
	end
end

function meta:D3bot_UpdatePathProgress()
	local mem = self.D3bot_Mem
	while mem.NextNodeOrNil do
		if mem.NextNodeOrNil:GetContains2D(self:GetPos()) then
			mem.NodeOrNil = mem.NextNodeOrNil
			mem.NextNodeOrNil = table.remove(mem.RemainingNodes, 1)
			if mem.NodeOrNil and mem.NodeOrNil.Params.BotMod then
				D3bot.nodeZombiesCountAddition = mem.NodeOrNil.Params.BotMod
				-- TODO: Change node botmod to trigger on human
			end
		else
			break
		end
	end
end

function meta:D3bot_UpdateMem()
	local mem = self.D3bot_Mem
	self:D3bot_UpdatePosMilestone()
	self:D3bot_UpdateTgtOrNil()
	self:D3bot_UpdateTgtProximity()
	if mem.NextSlowThinkTime <= CurTime() then
		mem.NextSlowThinkTime = CurTime() + 0.5
		self:D3bot_UpdateAngsOffshoot()
		self:D3bot_UpdatePath()
	end
	self:D3bot_UpdatePathProgress()
end