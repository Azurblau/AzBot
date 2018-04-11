D3bot.Handlers = {}

for i, filename in pairs(file.Find("d3bot/sv_zs_bot_handler/handlers/*.lua", "LUA")) do
	include("handlers/"..filename)
end

hook.Add("StartCommand", D3bot.BotHooksId, function(pl, cmd)
	if D3bot.IsEnabled and pl:IsBot() then
		-- TODO: Cache handlers or use lookup table
		for k, v in pairs(D3bot.Handlers) do
			if (v.Team == nil or v.Team[pl:Team()]) and (v.ZombieClasses == nil or v.ZombieClasses[pl:GetZombieClassTable().Name]) then
				v.UpdateBotCmdFunction(pl, cmd)
				break
			end
		end
	end
end)