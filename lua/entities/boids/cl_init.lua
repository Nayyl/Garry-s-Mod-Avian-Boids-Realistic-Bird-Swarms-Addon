include("shared.lua")

hook.Add( "AddToolMenuCategories", "CustomCategory", function()
	spawnmenu.AddToolCategory( "Utilities", "Boids_Category", "#Boids_Category" )
end )
local BOIDS_SPEED = GetConVar("sv_boids_speed")

local GHOST_NUMBER = CreateClientConVar("cl_boids_ghost_amount", "0", true, false, "", 0, 10)
local GHOST_DIST = CreateClientConVar("cl_boids_ghost_distances", "50", true, false, "", 10, 100)
local GHOST_DIST_UNIFORM = CreateClientConVar("cl_boids_ghost_distances_uniform", "1", true, false, "", 0, 1)
local GHOST_MODEL = GetConVar("sv_boids_model")
print(GHOST_MODEL)

hook.Add( "PopulateToolMenu", "CustomMenuSettings", function()
	spawnmenu.AddToolMenuOption( "Utilities", "Boids_Category", "Boids_Menu", "#Settings", "", "", function( panel )
    
        panel:Help("Configure the behavior and performance of the bird swarms.")

        -- panel:Help("[ Behavioral Rules ]")
        panel:CheckBox("Enable Separation (Rule 1)", "sv_boids_collision_avoidances")
        panel:CheckBox("Enable Alignment (Rule 2)", "sv_boids_alignment")
        panel:CheckBox("Enable Cohesion (Rule 3)", "sv_boids_cohesion")
        panel:NumSlider("Random Noise (Wander)", "sv_boids_noise_factor", 0, 1, 2)
        panel:ControlHelp("Noise adds natural variation to the flight path.")

        -- panel:Help("[ Force Multipliers ]")
        panel:NumSlider("Separation Weight", "sv_boids_separation_factor", 0.2, 10, 1)
        panel:NumSlider("Alignment Weight", "sv_boids_alignment_factor", 0.2, 10, 1)
        panel:NumSlider("Cohesion Weight", "sv_boids_cohesion_factor", 0.2, 10, 1)
        panel:NumSlider("Orbit Weight", "sv_boids_orbit_factor", 0.2, 10, 1)

        -- panel:Help("[ Flight & Navigation ]")
        panel:NumSlider("Flight Speed", "sv_boids_speed", 100, 1000, 0)
        panel:NumSlider("Wall Detection Distance", "sv_boids_trace_lengh", 10, 1000, 0)
        panel:NumSlider("Minimum Separation Dist", "sv_boids_separation_distances", 3, 50, 0)
        panel:NumSlider("Orbit Target Distance", "sv_boids_orbit_distance", 10, 2000, 0)

        -- panel:Help("[ Visuals & Spawning ]")
        local combobox = panel:ComboBox("Boid Model", "sv_boids_model")
        combobox:AddChoice("models/crow.mdl")
        combobox:AddChoice("models/pigeon.mdl")
        -- combobox:AddChoice("models/seagull.mdl")

        panel:NumSlider("Birds per Spawn", "sv_boids_spawn_number", 1, 50, 0)

        -- panel:Help("[ Optimization & Grid ]")
        panel:CheckBox("Enable Fine Distance Check", "sv_boids_distance_check")
        panel:ControlHelp("If off, boids see everyone in the grid cell (faster).")

        panel:NumSlider("Detection Radius", "sv_boids_distance_check_value", 100, 2000, 0)
        panel:NumSlider("Grid Cell Size", "sv_boids_cell_size", 50, 2000, 0)
        panel:ControlHelp("Warning: Cell size should be larger than Detection Radius.")

        panel:Help("\nGhost boids are entities that fly around the boid without taking much performance from the server.")

        panel:NumSlider("Ghost Amount", "cl_boids_ghost_amount", 0, 10, 0)
        panel:CheckBox("Enable Uniform distances between boids", "cl_boids_ghost_distances_uniform")
        panel:NumSlider("Ghost Minimum Separation Dist", "cl_boids_ghost_distances", 10, 100, 0)
        
	end )
end )

function ENT:GenerateGhosts()
    if self.GhostBoids then
        for _,v in next, self.GhostBoids do
            if not IsValid(v) then continue end
            v:Remove()
        end
    end

    if GHOST_NUMBER:GetInt() <= 0 then return end

    self.GhostBoids = {}
    for i = 1, GHOST_NUMBER:GetInt() do
        local rand_vec = VectorRand()
        local cboid = ClientsideModel( self:GetModel() )
        self.GhostBoids[i] = cboid
        if not IsValid(cboid) then continue end
        cboid:SetNoDraw( true )
        cboid:ResetSequence("fly01") -- "fly01"
        cboid:SetCycle( math.Rand(0,1) )
        cboid.dir = GHOST_DIST_UNIFORM:GetBool() and rand_vec:GetNormalized() or rand_vec * math.Rand(0,1) + rand_vec -- add a minimum distance
        cboid.pos = self:GetPos() + cboid.dir * GHOST_DIST:GetInt()
        
    end
end

-- cl_boids_ghost_distances_uniform
local callback_convar = {
    "cl_boids_ghost_amount",
    "cl_boids_ghost_distances_uniform"
}

for _,v in next, callback_convar do
    cvars.AddChangeCallback(v, function(convar_name, value_old, value_new)
        for _, v in next, ents.FindByClass("boids") do
            v:GenerateGhosts()
        end
    end)
end

function ENT:Initialize()

    self.lerp_pos = self:GetPos()
    self.mins, self.maxs = Vector( -20, -20, -20 ), Vector( 20, 20, 20 )
    self.dead = false

    self:GenerateGhosts()
end

function ENT:Draw()
    
    self:DrawModel()

    debugoverlay.Box(self:GetPos(), self.mins, self.maxs, 0.01, Color(255,255,255,0))

    if not self.GhostBoids then return end
    for _,v in next, self.GhostBoids do
        if not IsValid(v) then continue end

        v:DrawModel()
    end
end

function ENT:MakeBoidRagdoll()
    local ragdoll = self:BecomeRagdollOnClient()
    local phys = ragdoll:GetPhysicsObject()
    
    phys:ApplyForceCenter( self:GetForward() * GetConVar("sv_boids_speed"):GetFloat() * phys:GetMass() )
    self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav")
    self.dead = true

    local blood = EffectData()
    blood:SetOrigin(self:GetPos())
    blood:SetScale(1) -- Taille du jet
    blood:SetFlags(3) -- 3 est le flag pour le sang rouge (flesh)
    util.Effect("BloodImpact", blood)
end

function ENT:Think()
    
    self.lerp_pos = LerpVector(FrameTime() * 100, self.lerp_pos, self:GetNetworkOrigin())

    if self:GetDead() and not self.dead then
        self:MakeBoidRagdoll()
        return
    end

    if not self.GhostBoids then return end
    for _,v in next, self.GhostBoids do
        local cboid = v
        if not IsValid(cboid) then continue end


        cboid.pos = LerpVector(FrameTime() * 3, cboid.pos, self:GetPos() + cboid.dir * 100 )
        cboid.pos = self:GetPos() + cboid.dir * GHOST_DIST:GetInt() * 2

        cboid:SetPos( cboid.pos )
        cboid:SetAngles( self:GetAngles() )
        cboid:FrameAdvance()
    end

    
end

function ENT:OnRemove( bool )
    if not self.GhostBoids then return end
    for i = 1, #self.GhostBoids do
        local cboid = self.GhostBoids[i]
        if not IsValid( cboid ) then continue end
        cboid:Remove()
    end
end