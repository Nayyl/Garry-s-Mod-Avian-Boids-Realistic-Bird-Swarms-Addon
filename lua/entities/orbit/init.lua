AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()

    self:SetModel("models/hunter/misc/sphere2x2.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local pos = self:GetPos()
    self:SetPos(pos)
    self:SetColor(Color(255,255,255,100))

    local phys = self:GetPhysicsObject()
    
    if phys:IsValid() then
        phys:Wake()
    end
    
end