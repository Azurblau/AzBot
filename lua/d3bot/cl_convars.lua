CreateClientConVar("d3bot_navmeshing_enabled", 1, true, true, "Defines if the client is in the navmeshing mode.")
CreateClientConVar("d3bot_navmeshing_mode", "", true, true, "Defines the navmeshing mode, the user is in.")
CreateClientConVar("d3bot_navmeshing_reloadmodecycle", 1, true, true, "Defines if the client is in the navmeshing mode.")

D3bot.Convar_Navmeshing_SmartDraw = CreateClientConVar("d3bot_navmeshing_smartdraw", 1, true, true, "Automatically hides obscured nodes and links.")
D3bot.Convar_Navmeshing_PreviewTool = CreateClientConVar("d3bot_navmeshing_previewtool", 1, true, true, "Preview of changes in the mesh using the selected mod.")
D3bot.Convar_Navmeshing_DrawDistance = CreateClientConVar("d3bot_navmeshing_drawdistance", 0, true, true, "The maximum drawing distance. Use 0 to disable this option.")
