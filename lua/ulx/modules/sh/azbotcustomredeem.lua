if engine.ActiveGamemode() == "zombiesurvival" then
	local nextByPl = {}
	local tierByPl = {}
	function ulx.human(pl)
		if not AzBot.IsSelfRedeemEnabled then
			local response = "This command is enabled on bot maps only!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if GAMEMODE:GetWave() > AzBot.SelfRedeemWaveMax then
			local response = "It's too late to self-redeem (can only be done before wave "..(AzBot.SelfRedeemWaveMax + 1)..")."
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if pl:Team() == TEAM_HUMAN then
			local response = "You're already human!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local remainingTime = (nextByPl[pl] or 0) - CurTime()
		if remainingTime > 0 then
			local response = "You already self-redeemed recently. Try again in "..remainingTime.." seconds!"
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local nextTier = (tierByPl[pl] or 0) + 1
		tierByPl[pl] = nextTier
		local cooldown = nextTier * 30
		nextByPl[pl] = CurTime() + cooldown
		local response = "You self-redeemed. Your current cooldown until next self-redeem is ".. math.ceil(cooldown).." seconds."
		pl:ChatPrint(response)
		pl:PrintMessage(HUD_PRINTCENTER, response)
		pl:ChangeTeam(TEAM_HUMAN)
		pl:SetDeaths(0)
		pl:SetPoints(0)
		pl:SetFrags(0)
		pl:DoHulls()
		pl:UnSpectateAndSpawn()
		pl:StripWeapons()
		pl:StripAmmo()
		ulx.giveHumanLoadout(pl)
		ulx.tryBringToHumans(pl)
	end
	local cmd = ulx.command("Zombie Survival", "ulx human", ulx.human, "!human", true)
	cmd:defaultAccess(ULib.ACCESS_ALL)
	cmd:help("If you're a zombie, you can use this command to instantly respawn as a human with a default loadout.")
end