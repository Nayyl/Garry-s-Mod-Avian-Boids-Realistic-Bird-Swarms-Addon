include("shared.lua")

hook.Add( "AddToolMenuCategories", "CustomCategory", function()
	spawnmenu.AddToolCategory( "Utilities", "Boids_Category", "#Boids_Category" )
end )

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
    panel:NumSlider("Min Separation Dist", "sv_boids_separation_distances", 3, 50, 0)
    panel:NumSlider("Orbit Target Distance", "sv_boids_orbit_distance", 10, 2000, 0)

    -- panel:Help("[ Visuals & Spawning ]")
    local combobox = panel:ComboBox("Boid Model", "sv_boids_model")
        combobox:AddChoice("models/crow.mdl")
        combobox:AddChoice("models/pigeon.mdl")
        combobox:AddChoice("models/seagull.mdl")

        panel:NumSlider("Birds per Spawn", "sv_boids_spawn_number", 1, 50, 0)

        -- panel:Help("[ Optimization & Grid ]")
        panel:CheckBox("Enable Fine Distance Check", "sv_boids_distance_check")
        panel:ControlHelp("If off, boids see everyone in the grid cell (faster).")

        panel:NumSlider("Detection Radius", "sv_boids_distance_check_value", 100, 2000, 0)
        panel:NumSlider("Grid Cell Size", "sv_boids_cell_size", 50, 2000, 0)
        panel:ControlHelp("Warning: Cell size should be larger than Detection Radius.")
	end )
end )

function ENT:Initialize()

    self.lerp_pos = self:GetPos()

end

function ENT:Draw()

    --self:SetPos( self.lerp_pos )
    self:DrawModel()
    
    --[[ render.SetColorMaterial()
    render.DrawLine(self:GetPos(), self:GetPos() + self:GetForward() * 100, Color(255, 255, 255), true) ]]
end

function ENT:Think()
    self.lerp_pos = LerpVector(FrameTime() * 100, self.lerp_pos, self:GetNetworkOrigin())
end

