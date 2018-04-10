local AzBot.Handlers = {}

for i, filename in pairs(file.Find(GM.FolderName.."/lua/azbot/sv_zs_bot_handler/handlers/*.lua", "LUA")) do
	include("handlers/"..filename)
end

for k, v in pairs(GAMEMODE.ZombieClasses) do
	v.AzBotHandler = AzBot.Handlers.Fallback
	for k2, v2 in pairs(AzBot.Handlers) do
		if (v2.ZombieClasses == nil or v2.ZombieClasses[v.Name]) do
			v.AzBotHandler = v2
			break
		end
	end
end

hook.Add("StartCommand", AzBot.BotHooksId, function(pl, cmd)
	if AzBot.IsEnabled and pl:IsBot() then
		-- TODO: Cache handlers or use lookup table
		for k, v in pairs(AzBot.Handlers) do
			if v.Team == pl:Team() and (v.ZombieClasses == nil or v.ZombieClasses[pl:GetZombieClass().Name]) then
				v.UpdateBotCmdFunction()
				break
			end
		end
	end
end)