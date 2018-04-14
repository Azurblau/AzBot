D3bot.Handlers.Survivor_Fallback = D3bot.Handlers.Survivor_Fallback or {}
local HANDLER = D3bot.Handlers.Survivor_Fallback

HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_SURVIVOR or (TEAM_REDEEMER and team == TEAM_REDEEMER)
end

function HANDLER.UpdateBotCmdFunction(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	if not bot:Alive() then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end
	
	bot:D3bot_UpdatePathProgress()
	local mem = bot.D3bot_Mem
	
	local result, actions, forwardSpeed, aimAngle = D3bot.Basics.WalkAttackAuto(bot)
	if not result then
		result, actions, forwardSpeed, aimAngle = D3bot.Basics.Aim(bot, mem.AttackTgtOrNil)
	else
		actions.Attack = false
	end
	
	local target = mem.AttackTgtOrNil
	
	if IsValid(target) then
		local tr = util.TraceLine({
			start = bot:GetShootPos(),
			endpos = bot:GetShootPos() + (aimAngle and aimAngle:Forward() or bot:GetAimVector()) * (bot:GetShootPos():Distance(target:D3bot_GetViewCenter())),
			filter = player.GetAll(),
			mask = MASK_SHOT_HULL
		})
		--local tr = bot:GetEyeTraceNoCursor()
		actions.Attack = ((not tr.Hit) or IsValid(tr.Entity) and tr.Entity:IsPlayer() and HANDLER.IsEnemy(tr.Entity)) and math.random(20) == 1
	end
	
	local buttons
	if actions then
		buttons = bit.bor(actions.Attack and IN_ATTACK or 0, actions.Attack2 and IN_ATTACK2 or 0, actions.Reload and IN_RELOAD or 0, actions.Duck and IN_DUCK or 0, actions.Jump and IN_JUMP or 0, actions.Use and IN_USE or 0)
	end
	
	if aimAngle then bot:SetEyeAngles(aimAngle)	cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	if buttons then cmd:SetButtons(buttons) end
end

function HANDLER.FindEscapePath(node, enemies)
	local tempNodePenalty = {}
	for _, enemy in pairs(enemies) do
		local enemyNode = D3bot.MapNavMesh:GetNearestNodeOrNil(enemy:GetPos())
		if enemyNode then
			tempNodePenalty[enemyNode] = (tempNodePenalty[enemyNode] or 0) + 1
			for linkedNode, link in pairs(enemyNode.LinkByLinkedNode) do
				tempNodePenalty[linkedNode] = (tempNodePenalty[linkedNode] or 0) + 0.5
			end
		end
	end
	
	local function pathCostFunction(node, linkedNode, link)
		local cost = 0
		--for _, enemy in pairs(enemies) do
			--cost = cost + 100 / (LerpVector(0.5, node.Pos, linkedNode.Pos):Distance(enemy:GetPos()) + 100) * 0.1 * node.Pos:Distance(linkedNode.Pos) -- Weight by link length
		--end
		cost = cost + (tempNodePenalty[linkedNode] or 0) * 1000
		return cost-- + node.Pos:Distance(linkedNode.Pos) * 2
	end
	local function totalCostFunction(node, linkedNode, link)
		local cost = 0
		for _, enemy in pairs(enemies) do
			cost = cost + 10 / (linkedNode.Pos:Distance(enemy:GetPos()) + 10) * 1
		end
		return cost
	end
	return D3bot.GetEscapeMeshPathOrNil(node, 50, pathCostFunction, nil, {Walk = true})
end

function HANDLER.CanShootTarget(bot, target)
	if not IsValid(target) then return end
	local origin = bot:D3bot_GetViewCenter()
	local targetPos = target:D3bot_GetViewCenter()
	local tr = util.TraceLine({
		start = origin,
		endpos = targetPos,
		filter = player.GetAll(),
		mask = MASK_SHOT_HULL
	})
	return not tr.Hit
end

function HANDLER.ThinkFunction(bot)
	local mem = bot.D3bot_Mem
	local botPos = bot:GetPos()
	
	if mem.nextUpdateSurroundingPlayers and mem.nextUpdateSurroundingPlayers < CurTime() or not mem.nextUpdateSurroundingPlayers then
		mem.nextUpdateSurroundingPlayers = CurTime() + 0.25
		local enemies = D3bot.From(player.GetAll()):Where(function(k, v) return HANDLER.IsEnemy(v) end).R
		local closeEnemies = D3bot.From(enemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 3000 end).R -- TODO: Constant for the distance
		local closerEnemies = D3bot.From(closeEnemies):Where(function(k, v) return botPos:Distance(v:GetPos()) < 500 end).R -- TODO: Constant for the distance
		if table.Count(closerEnemies) > 0 then
			if (not mem.NextNodeOrNil or mem.lastEscapePath and mem.lastEscapePath < CurTime() - 2 or not mem.lastEscapePath) then
				escapePath = HANDLER.FindEscapePath(D3bot.MapNavMesh:GetNearestNodeOrNil(botPos), closeEnemies)
				if escapePath then
					mem.lastEscapePath = CurTime()
					bot:D3bot_ResetTgt()
					bot:D3bot_SetPath(escapePath) -- Dirty overwrite of the path, as long as no other target is set it works fine
				end
			end
		else
			bot:D3bot_ResetTgt()
			if not IsValid(mem.AttackTgtOrNil) or not HANDLER.CanShootTarget(bot, mem.AttackTgtOrNil) then mem.AttackTgtOrNil = table.Random(closeEnemies) or table.Random(enemies) or nil end
		end
	end
	
	if bot:Health() < 30 then
		-- TODO: Let the bot go to a cade or a crowd of survivors
	else
		
	end
	
	if mem.nextUpdateOffshoot and mem.nextUpdateOffshoot < CurTime() or not mem.nextUpdateOffshoot then
		mem.nextUpdateOffshoot = CurTime() + 0.4 + math.random() * 0.2
		bot:D3bot_UpdateAngsOffshoot() -- TODO: Less offshoot
	end
	
	if mem.nextUpdatePath and mem.nextUpdatePath < CurTime() or not mem.nextUpdatePath then
		mem.nextUpdatePath = CurTime() + 0.9 + math.random() * 0.2
		bot:D3bot_UpdatePath()
	end
end

function HANDLER.OnTakeDamageFunction(bot, dmg)
	local attacker = dmg:GetAttacker()
	if not HANDLER.CanBeShootTgt(bot, attacker) then return end
	local mem = bot.D3bot_Mem
	--if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():Distance(bot:GetPos()) <= D3bot.BotTgtFixationDistMin then return end
	mem.AttackTgtOrNil = attacker
	--bot:Say("Stop That! I'm gonna shoot you, "..attacker:GetName().."!")
end

function HANDLER.OnDoDamageFunction(bot, dmg)
	--bot:Say("Gotcha!")
end

function HANDLER.OnDeathFunction(bot)
	--bot:Say("rip me!")
	HANDLER.RerollTarget(bot)
end

function HANDLER.IsEnemy(ply)
	if IsValid(ply) and ply:IsPlayer() and ply:Team() ~= TEAM_SURVIVOR and ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive() then return true end
end

function HANDLER.CanBeShootTgt(bot, target)
	if not target or not IsValid(target) then return end
	if target:IsPlayer() and target ~= bot and target:Team() ~= TEAM_SURVIVOR and target:GetObserverMode() == OBS_MODE_NONE and target:Alive() then return true end
end

function HANDLER.RerollTarget(bot) -- This should set the target to move to (Either an entity or a position).
	local mem = bot.D3bot_Mem
	-- Get all non human players
	local players = D3bot.RemoveObsDeadTgts(player.GetHumans())
	players = D3bot.From(players):Where(function(k, v) return v:Team() == TEAM_SURVIVOR end).R
	local potTargets = players
	local humanFollowTarget = table.Random(potTargets)
	if humanFollowTarget then
		local targetNode = D3bot.MapNavMesh:GetNearestNodeOrNil(humanFollowTarget:GetPos())
		bot:D3bot_SetNodeTgtOrNil(targetNode)
		--bot:D3bot_SetPosTgtOrNil(humanFollowTarget:GetPos(), 100)
	end
end