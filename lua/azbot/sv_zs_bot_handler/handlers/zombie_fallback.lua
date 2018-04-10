AzBot.Handlers.Fallback = {}
HANDLER = AzBot.Handlers.Fallback

-- HANDLER.ZombieClasses = {}
HANDLER.Team = TEAM_UNDEAD

HANDLER.UpdateBotCmdFunction = function(bot, cmd)
		cmd:ClearButtons()
		cmd:ClearMovement()
		
		if not bot:Alive() then
			-- Get back into the game
			cmd:SetButtons(IN_ATTACK)
			return
		end
		
		local aimAngle, forwardSpeed, buttons
		
		bot:AzBot_UpdateMem(bot)
		AzBot.Basics.SuicideOrRetarget(bot)
		
		result, buttons, forwardSpeed, aimAngle = AzBot.Basics.WalkAttack(bot)
		if not result then
			return
		end
		
		cmd:SetViewAngles(aimAngle)
		cmd:SetForwardMove(forwardSpeed)
		cmd:SetButtons(buttons)
	end
end