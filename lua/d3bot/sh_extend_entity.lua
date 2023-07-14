---@class GEntity
local meta = FindMetaTable("Entity")

---Returns whether this entity is a barricade.
---This means that it is either a nailed physics object, or some other kind of thing that players can use to block zombies.
---@return boolean
function meta:D3bot_IsBarricade()
	-- Anything that is nailed is considered a barricade entity.
	if self.IsNailed and self:IsNailed() then return true end

	-- Use IsBarricadeObject property of some entities.
	-- This is true for prop_aegisboard and prop_arsenalcrate, basically anything that players can use to block zombies.
	return self.IsBarricadeObject or false
end
