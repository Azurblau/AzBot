
if engine.ActiveGamemode() == "zombiesurvival" then
	hook.Add("PlayerSpawn", "!human info", function(pl)
		if not AzBot.IsSelfRedeemEnabled or pl:Team() ~= TEAM_UNDEAD or GAMEMODE:GetWave() > AzBot.SelfRedeemWaveMax then return end
		pl:PrintMessage(HUD_PRINTCENTER, "You can type !human to play as survivor.")
	end)
	
	function ulx.giveHumanLoadout(pl)
		pl:Give("weapon_zs_axe")
		pl:Give("weapon_zs_owens")
		pl:GiveAmmo(50, "pistol")
	end
	function ulx.human(pl)
		if not AzBot.IsSelfRedeemEnabled then return end
		if GAMEMODE:GetWave() > AzBot.SelfRedeemWaveMax then
			pl:ChatPrint("It's too late to self-redeem.")
			return
		end
		if pl:Team() ~= TEAM_UNDEAD then
			pl:ChatPrint("You're already human!")
			return
		end
		pl:Redeem()
		pl:StripWeapons()
		pl:StripAmmo()
		ulx.giveHumanLoadout(pl)
	end
	local cmd = ulx.command("Zombie Survival", "ulx human", ulx.human, "!human")
	cmd:defaultAccess(ULib.ACCESS_ALL)
	cmd:help("If you're a zombie, you can use this command to instantly respawn as a human with a default loadout.")
end

local function registerCmd(camelCaseName, ...)
	local func
	local params = {}
	for idx, arg in ipairs({...}) do
		if istable(arg) then
			table.insert(params, arg)
		elseif isfunction(arg) then
			func = arg
			break
		else
			break
		end
	end
	ulx["azBot" .. camelCaseName] = func
	local cmdStr = "azbot " .. camelCaseName:lower()
	local cmd = ulx.command("AzBot", cmdStr, func, "!" .. cmdStr)
	for k, param in pairs(params) do cmd:addParam(param) end
	cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
end

local plsParam = { type = ULib.cmds.PlayersArg }
local strParam = { type = ULib.cmds.StringArg }
local optionalStrParam = { type = ULib.cmds.StringArg, ULib.cmds.optional }

registerCmd("ViewMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "view") end end)
registerCmd("EditMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "edit") end end)
registerCmd("HideMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, nil) end end)

registerCmd("SaveMesh", function(caller)
	AzBot.SaveMapNavMesh()
	caller:ChatPrint("Saved.")
end)
registerCmd("ReloadMesh", function(caller)
	AzBot.LoadMapNavMesh()
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Reloaded.")
end)
registerCmd("RefreshMeshView", function(caller)
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Refreshed.")
end)

registerCmd("SetParam", strParam, strParam, optionalStrParam, function(caller, id, name, serializedNumOrStrOrEmpty)
	AzBot.TryCatch(function()
		AzBot.MapNavMesh.ItemById[AzBot.DeserializeNavMeshItemId(id)]:SetParam(name, serializedNumOrStrOrEmpty)
		AzBot.UpdateMapNavMeshUiSubscribers()
	end, function(errorMsg)
		caller:ChatPrint("Error. Re-check your parameters.")
	end)
end)

registerCmd("ViewPath", plsParam, strParam, strParam, function(caller, pls, startNodeId, endNodeId)
	local nodeById = AzBot.MapNavMesh.NodeById
	local startNode = nodeById[AzBot.DeserializeNavMeshItemId(startNodeId)]
	local endNode = nodeById[AzBot.DeserializeNavMeshItemId(endNodeId)]
	if not startNode or not endNode then
		caller:ChatPrint("Not all specified nodes exist.")
		return
	end
	local path = AzBot.GetBestMeshPathOrNil(startNode, endNode)
	if not path then
		caller:ChatPrint("Couldn't find any path for the two specified nodes.")
		return
	end
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, path) end
end)
registerCmd("DebugPath", plsParam, optionalStrParam, function(caller, pls, serializedEntIdxOrEmpty)
	local ent = serializedEntIdxOrEmpty == "" and caller:GetEyeTrace().Entity or Entity(tonumber(serializedEntIdxOrEmpty) or -1)
	if not IsValid(ent) then
		caller:ChatPrint("No entity cursored or invalid entity index specified.")
		return
	end
	caller:ChatPrint("Debugging path from player to " .. tostring(ent) .. ".")
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, pl, ent) end
end)
registerCmd("ResetPath", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.HideMapNavMeshPath(pl) end end)
