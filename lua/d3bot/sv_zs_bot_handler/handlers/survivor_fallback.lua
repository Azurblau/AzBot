D3bot.Handlers.Survivor_Fallback = {}
HANDLER = D3bot.Handlers.Survivor_Fallback

-- HANDLER.ZombieClasses = {}
local TEAM_SURVIVOR = 4 -- TODO: Create a function for the selection
local TEAM_REDEEMER = 5
HANDLER.Team = {[TEAM_SURVIVOR] = true, [TEAM_REDEEMER] = true}

HANDLER.UpdateBotCmdFunction = function(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	if not bot:Alive() then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end
	
	bot:D3bot_UpdateMem()
	D3bot.Basics.SuicideOrRetarget(bot)
	
	local result, buttons, forwardSpeed, aimAngle = D3bot.Basics.PounceAuto(bot)
	if not result then
		result, buttons, forwardSpeed, aimAngle = D3bot.Basics.WalkAttackAuto(bot)
		if not result then
			return
		end
	end
	
	bot:SetEyeAngles(aimAngle)
	cmd:SetViewAngles(aimAngle)
	cmd:SetForwardMove(forwardSpeed)
	cmd:SetButtons(buttons)
end