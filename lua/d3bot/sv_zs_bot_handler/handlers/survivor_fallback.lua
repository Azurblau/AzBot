D3bot.Handlers.Survivor_Fallback = D3bot.Handlers.Survivor_Fallback or {}
HANDLER = D3bot.Handlers.Survivor_Fallback

HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_SURVIVOR or team == TEAM_REDEEMER
end

function HANDLER.UpdateBotCmdFunction(bot, cmd)
	cmd:ClearButtons()
	cmd:ClearMovement()
	
	if not bot:Alive() then
		-- Get back into the game
		cmd:SetButtons(IN_ATTACK)
		return
	end
	
	bot:D3bot_UpdateMem()
	D3bot.Basics.SuicideOrRetarget(bot)
	
	local result, buttons, forwardSpeed, aimAngle = D3bot.Basics.WalkAttackAuto(bot)
	if not result then
		return
	end
	
	bot:SetEyeAngles(aimAngle)
	cmd:SetViewAngles(aimAngle)
	cmd:SetForwardMove(forwardSpeed)
	cmd:SetButtons(buttons)
end

function HANDLER.ThinkFunction(bot)
	
end

function HANDLER.OnTakeDamageFunction(bot, dmg)
	bot:Say("Stop that")
end

function HANDLER.OnDoDamageFunction(bot, dmg)
	bot:Say("Gotcha!")
end

function HANDLER.OnDeathFunction(bot)
	bot:Say("rip me!")
end