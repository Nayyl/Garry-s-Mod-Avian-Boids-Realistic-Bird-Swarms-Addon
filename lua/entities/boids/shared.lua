ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Boid"
ENT.Author    = "Nayl"
ENT.Spawnable = true
ENT.Category  = "Boids"

function ENT:SetupDataTables()
    self:NetworkVar("Bool", false, "Dead")
end

local function ShotCatch( ent, data )
    --[[ PrintTable( data )

    print(data.Trace.Fraction) ]]

    -- debugoverlay.Box( data.Trace.StartPos, Vector(-1,-1,-1), Vector(1,1,1), 1, color_white)
    -- debugoverlay.Line(data.Trace.StartPos, data.Trace.HitPos, 1, Color(255,255,255), false)

    for k, v in next, ents.FindByClass("boids") do
        if v.dead then continue end
        local rayDelta = data.Trace.HitPos - data.Trace.StartPos
        local inter = util.IntersectRayWithOBB( data.Trace.StartPos, rayDelta, v:GetPos(), Angle(), v:OBBMins(), v:OBBMaxs() )

        if not inter then continue end

        if SERVER then
            v:SetDead( true )
            v:Remove()
        end

    end
end
hook.Add( "PostEntityFireBullets", "BoidsShotCatch", ShotCatch)