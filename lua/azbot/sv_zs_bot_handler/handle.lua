AzBot.Handlers = {}

for i, filename in pairs(file.Find("azbot/sv_zs_bot_handler/handlers/*.lua", "LUA")) do
	include("handlers/"..filename)
end

hook.Add("StartCommand", AzBot.BotHooksId, function(pl, cmd)
	if AzBot.IsEnabled and pl:IsBot() then
		-- TODO: Cache handlers or use lookup table
		print(pl:GetZombieClass())
		for k, v in pairs(AzBot.Handlers) do
			if v.Team == pl:Team() and (v.ZombieClasses == nil or v.ZombieClasses[pl:GetZombieClassTable().Name]) then
				v.UpdateBotCmdFunction(pl, cmd)
				break
			end
		end
	end
end)
