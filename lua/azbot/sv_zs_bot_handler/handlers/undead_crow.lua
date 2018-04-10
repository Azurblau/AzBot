AzBot.Handlers.Undead_Crow = {}
HANDLER = AzBot.Handlers.Undead_Crow

HANDLER.ZombieClasses = {Crow = true}
HANDLER.Team = 3 --TEAM_UNDEAD

HANDLER.UpdateBotCmdFunction = function(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	if not bot:Alive() and math.random(1, 50) == 1 then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end
	
	bot:AzBot_UpdateMem()
	local mem = bot.AzBot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local result, buttons, forwardSpeed, aimAngle = nil, 0, 0, nil
	if nextNodeOrNil then
		result, buttons, forwardSpeed, aimAngle = AzBot.Basics.Walk(bot, nextNodeOrNil.Pos + Vector(0, 0, 64))
	end
	
	buttons = bit.band(buttons, bit.bnot(IN_USE)) -- Prevent crow bots from pressing USE
	buttons = bit.bor(buttons or 0, (math.random(1, 2) == 1) and result and IN_JUMP or 0)
	
	if aimAngle then cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	cmd:SetButtons(buttons)
end