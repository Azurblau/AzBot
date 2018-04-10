AzBot.Handlers.Undead_Crow = {}
HANDLER = AzBot.Handlers.Undead_Crow

HANDLER.ZombieClasses = {Crow = true}
HANDLER.Team = 3 --TEAM_UNDEAD

HANDLER.UpdateBotCmdFunction = function(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	print("crowe")
	
	if not bot:Alive() then
		-- Get back into the game
		--cmd:SetButtons(IN_ATTACK)
		--return
	end
	
	local mem = bot.AzBot_Mem
	local nodeOrNil = mem.NodeOrNil
	local nextNodeOrNil = mem.NextNodeOrNil
	
	local result, buttons, forwardSpeed, aimAngle
	if nextNodeOrNil then
		result, buttons, forwardSpeed, aimAngle = AzBot.Basics.Walk(bot, nextNodeOrNil.Pos + Vector(0, 0, 64))
	end
	
	bot:AzBot_UpdateMem()
	AzBot.Basics.SuicideOrRetarget(bot)
	
	buttons = bit.bor(buttons, IN_JUMP)
	
	if aimAngle then cmd:SetViewAngles(aimAngle) end
	if forwardSpeed then cmd:SetForwardMove(forwardSpeed) end
	cmd:SetButtons(buttons)
end