D3bot.Handlers.Undead_Fallback = D3bot.Handlers.Undead_Fallback or {}
HANDLER = D3bot.Handlers.Undead_Fallback

HANDLER.Fallback = true
function HANDLER.SelectorFunction(zombieClassName, team)
	return team == TEAM_UNDEAD
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
	
	local result, buttons, forwardSpeed, aimAngle, majorStuck = D3bot.Basics.PounceAuto(bot)
	if not result then
		result, buttons, forwardSpeed, aimAngle, majorStuck = D3bot.Basics.WalkAttackAuto(bot)
		if not result then
			return
		end
	end
	
	if majorStuck and GAMEMODE:GetWaveActive() then bot:Kill() end
	
	bot:SetEyeAngles(aimAngle)
	cmd:SetViewAngles(aimAngle)
	cmd:SetForwardMove(forwardSpeed)
	cmd:SetButtons(buttons)
end

function HANDLER.ThinkFunction(bot)
	
	--D3bot.Basics.CheckStuck(bot)
end

function HANDLER.OnTakeDamageFunction(bot, dmg)
	local attacker = dmg:GetAttacker()
	if not D3bot.CanBeBotTgt(attacker) then return end
	local mem = bot.D3bot_Mem
	if IsValid(mem.TgtOrNil) and mem.TgtOrNil:GetPos():Distance(bot:GetPos()) <= D3bot.BotTgtFixationDistMin then return end
	mem.TgtOrNil = attacker
	bot:Say("Ouch! Fuck you "..attacker:GetName().."! Gonna kill you!")
end

function HANDLER.OnDoDamageFunction(bot, dmg)
	local mem = bot.D3bot_Mem
	bot:Say("Gotcha!")
end

function HANDLER.OnDeathFunction(bot)
	bot:Say("rip me!")
	bot:D3bot_RerollClass()
end