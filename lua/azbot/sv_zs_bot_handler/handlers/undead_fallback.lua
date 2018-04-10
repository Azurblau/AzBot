AzBot.Handlers.Undead_Fallback = {}
HANDLER = AzBot.Handlers.Undead_Fallback

-- HANDLER.ZombieClasses = {}
HANDLER.Team = 3 --TEAM_UNDEAD

HANDLER.UpdateBotCmdFunction = function(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	if not bot:Alive() then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end
	
	bot:AzBot_UpdateMem()
	AzBot.Basics.SuicideOrRetarget(bot)
	
	local result, buttons, forwardSpeed, aimAngle = AzBot.Basics.PounceAuto(bot)
	if not result then
		result, buttons, forwardSpeed, aimAngle = AzBot.Basics.WalkAttackAuto(bot)
		if not result then
			return
		end
	end
	
	cmd:SetViewAngles(aimAngle)
	cmd:SetForwardMove(forwardSpeed)
	cmd:SetButtons(buttons)
end