D3bot.Handlers.Undead_Crow = D3bot.Handlers.Undead_Crow or {}
HANDLER = D3bot.Handlers.Undead_Crow

HANDLER.Fallback = false
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_UNDEAD and zombieClassName == "Crow"
end

function HANDLER.UpdateBotCmdFunction(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	if not bot:Alive() and math.random(1, 50) == 1 then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end
	
	bot:D3bot_UpdateMem()
	local mem = bot.D3bot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local result, buttons, forwardSpeed, aimAngle = nil, 0, 0, nil
	if nextNodeOrNil then
		result, buttons, forwardSpeed, aimAngle = D3bot.Basics.Walk(bot, nextNodeOrNil.Pos + Vector(0, 0, 64))
	end
	
	buttons = bit.band(buttons, bit.bnot(IN_USE)) -- Prevent crow bots from pressing USE
	buttons = bit.bor(buttons or 0, (math.random(1, 2) == 1) and result and IN_JUMP or 0)
	
	if aimAngle then bot:SetEyeAngles(aimAngle) cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	cmd:SetButtons(buttons)
end

function HANDLER.ThinkFunction(bot)
	
end

function HANDLER.OnTakeDamageFunction(bot, dmg)
	bot:Say("ouch!")
end

function HANDLER.OnDoDamageFunction(bot, dmg)
	bot:Say("Gotcha!")
end

function HANDLER.OnDeathFunction(bot)
	bot:Say("rip me!")
end