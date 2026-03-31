AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local DELETE_ON_ESCAPE_REALITY = CreateConVar( "sv_boids_delete_on_escape_reality", "0", FCVAR_NONE, "Delete the boid when he's getting out of the world", 0, 1 )
local COLLISION_RULE = CreateConVar( "sv_boids_collision_avoidances", "1", FCVAR_NONE, "", 0, 1 )
local ALIGNMENT_RULE = CreateConVar( "sv_boids_alignment", "1", FCVAR_NONE, "", 0, 1 )
local COHESION_RULE = CreateConVar( "sv_boids_cohesion", "1", FCVAR_NONE, "", 0, 1 )
local NOISE_FACTOR = CreateConVar( "sv_boids_noise_factor", "0.5", FCVAR_NONE, "", 0, 1 )
local MIN_DIST = CreateConVar( "sv_boids_separation_distances", "5", FCVAR_NONE, "", 2, 50 )
local SPEED = CreateConVar( "sv_boids_speed", "600", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "", 0, 1000 )
local SPAWN_NUMBER = CreateConVar( "sv_boids_spawn_number", "1", FCVAR_NONE, "", 1, 100 )
local TRACE_LEN = CreateConVar( "sv_boids_trace_lengh", "500", FCVAR_NONE, "", 10, 1000 )
local BOIDS_MODEL = CreateConVar("sv_boids_model", "models/crow.mdl", {FCVAR_REPLICATED, FCVAR_ARCHIVE})
local ALIGNMENT_FACTOR = CreateConVar( "sv_boids_alignment_factor", "0.8", FCVAR_NONE, "", 1, 10 )
local COHESION_FACTOR = CreateConVar( "sv_boids_cohesion_factor", "1.0", FCVAR_NONE, "", 1, 10 )
local SEPARATION_FACTOR = CreateConVar( "sv_boids_separation_factor", "1.5", FCVAR_NONE, "", 1, 10 )
local ORBIT_FACTOR = CreateConVar( "sv_boids_orbit_factor", "1.5", FCVAR_NONE, "", 0, 10 )
local ORBIT_DISTANCE = CreateConVar( "sv_boids_orbit_distance", "200", FCVAR_NONE, "", 10, 2000 )
local DISTANCE_CHECK = CreateConVar( "sv_boids_distance_check", "1", FCVAR_NONE, "However, check the distance between boids to consider them as neighbors instead of just looking at who is in the cell.", 0, 1 )
local DISTANCE_CHECK_VALUE = CreateConVar( "sv_boids_distance_check_value", "250", FCVAR_NONE, "", 100, 2000 )
local MINSMAXS_BOUNDS = CreateConVar( "sv_boids_mins_maxs_bounds", "20", FCVAR_NONE, "", 5, 50 )

local NUM_DIRECTIONS = 100
local GOLDEN_RATIO = (1 + math.sqrt(5)) / 2
local ANGLE_INCREMENT = math.pi * 2 * GOLDEN_RATIO
local CELL_SIZE = CreateConVar( "sv_boids_cell_size", "1000", FCVAR_NONE, "", 50, 2000 )
local BoidDirections = {}

for i = 0, NUM_DIRECTIONS - 1 do
    local t = i / NUM_DIRECTIONS
    local inclination = math.acos(1 - 2 * t)
    local azimuth = ANGLE_INCREMENT * i

    
    local x = 1 - 2 * t
    local radius = math.sqrt(1 - x * x)
    
    local y = math.sin(azimuth) * radius
    local z = math.cos(azimuth) * radius
    
    table.insert(BoidDirections, Vector(x, y, z))
end

-- Chached Functions
local Vector = Vector
local Color = Color
local Angle = Angle
local IsValid = IsValid
local CurTime = CurTime
local SysTime = SysTime
local FrameTime = FrameTime
local LerpVector = LerpVector
local LocalToWorld = LocalToWorld
local ipairs = ipairs
local table_insert = table.insert
local table_sort = table.sort
local math_sqrt = math.sqrt
local math_random = math.random
local math_floor = math.floor
local util_TraceLine = util.TraceLine
local debugoverlay_Line = debugoverlay.Line
local Color = Color
local ents_FindByClass = ents.FindByClass
local FrameTime = FrameTime
local LerpVector = LerpVector

-- MetaTables
local ent_meta = FindMetaTable("Entity")
local vec_meta = FindMetaTable("Vector")
local ang_meta = FindMetaTable("Angle")

-- Cached Meta Functions
local GetPos = ent_meta.GetPos
local SetPos = ent_meta.SetPos
local GetForward = ent_meta.GetForward
local GetAngles = ent_meta.GetAngles
local SetAngles = ent_meta.SetAngles
local GetClass = ent_meta.GetClass
local NextThink = ent_meta.NextThink
local IsInWorld = ent_meta.IsInWorld
local Remove = ent_meta.Remove

-- Cached Vector Functions
local Length = vec_meta.Length
local LengthSqr = vec_meta.LengthSqr
local GetNormalized = vec_meta.GetNormalized
local Dot = vec_meta.Dot
local Cross = vec_meta.Cross
local Distance = vec_meta.Distance
local DistToSqr = vec_meta.DistToSqr
local Distance2DSqr = vec_meta.Distance2DSqr
local Normalize = vec_meta.Normalize


-- The one angle function
local ToAngle = ang_meta.Angle

local BOID_GRID = {}
hook.Add("Tick", "UpdateBoidGrid", function()
    BOID_GRID = {}
    
    local cell_size = CELL_SIZE:GetFloat()
    for _, ent in ipairs(ents_FindByClass("boids")) do 
        if not IsValid(ent) then continue end

        local pos = ent:GetPos()

        local gx = math_floor(pos.x / cell_size)
        local gy = math_floor(pos.y / cell_size)
        local gz = math_floor(pos.z / cell_size)
        
        local key = gx .. "|" .. gy .. "|" .. gz
        
        BOID_GRID[key] = BOID_GRID[key] or {}
        table_insert(BOID_GRID[key], ent)
        
        ent.GridX = gx
        ent.GridY = gy
        ent.GridZ = gz
    end
end)


function ENT:NotMyNeighbors( ent )
    if ent == self or GetClass(ent) == "boids" then return false end
    return true
end

function ENT:Initialize()
    // Lag compensation changes everything that is insane
    self:SetLagCompensated( true )
    self:SetModel(BOIDS_MODEL:GetString())
    self:PhysicsInit(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_NONE)
    
    self:SetAngles(Angle(math.random(-180, 180), math.random(-180, 180), 0))

    self:ResetSequence("fly01") -- "fly01"
    self:SetCycle( math.Rand(0,1) )
    self:SetAutomaticFrameAdvance( true )

    local bounds = MINSMAXS_BOUNDS:GetFloat()
    local mins = -Vector(bounds,bounds,bounds)
    local maxs = -mins
    self:SetCollisionBounds( mins, maxs )

    // For the shared part
    self.dead = false
    self.lerp_pos = self:GetPos()
    self.mins, self.maxs = Vector( -20, -20, -20 ), Vector( 20, 20, 20 )
    self.dead = false
end

function ENT:GetNearByOptimized()
    local neighbors = {}
    if not self.GridX then return neighbors end

    
    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                local key = (self.GridX + dx) .. "|" .. (self.GridY + dy) .. "|" .. (self.GridZ + dz)
                local cell = BOID_GRID[key]
                
                if cell then
                    for _, b in ipairs(cell) do
                        if b != self then
                            if not DISTANCE_CHECK:GetBool() then table_insert(neighbors, b) continue end

                            local distSqr = DistToSqr( GetPos(b), GetPos(self) )
                            if distSqr < (DISTANCE_CHECK_VALUE:GetInt() * DISTANCE_CHECK_VALUE:GetInt()) then -- probably better without a ^2
                                table_insert(neighbors, b)
                            end
                        end
                    end
                end
            end
        end
    end
    return neighbors
end

function ENT:ObstacleRay()
    local pos = GetPos( self )
    local angles = GetAngles( self )
    
    for _, dir in ipairs(BoidDirections) do
        local worldDir = LocalToWorld(dir, Angle(0,0,0), Vector(0,0,0), angles)
        
        
        local tr = util_TraceLine({
            start = pos,
            endpos = pos + worldDir * TRACE_LEN:GetFloat(),
            mask = MASK_ALL,
            filter = function( ent ) return self:NotMyNeighbors( ent ) end
        })
        
        
        if not tr.Hit then
            -- developer 1 to see this
            debugoverlay_Line( tr.StartPos, tr.HitPos, 0.05, Color( 0, 255, 0, 1), false )
            return worldDir
        end
        debugoverlay_Line( tr.StartPos, tr.HitPos, 0.05, Color( 255, 0, 0, 1), false )
    end
    
    
    return -GetForward( self ) 
end

function ENT:Think()
    --local t = SysTime()
    if DELETE_ON_ESCAPE_REALITY:GetBool() and not IsInWorld( self ) then 
        Remove( self ) 
        return 
    end 
    
    local pos = GetPos( self )
    local rawNeighbors = self:GetNearByOptimized()
    local validNeighbors = {}
    
    local FOV_THRESHOLD = 0 -- 0.5 c'est environ 120° devant. probably a convar for this

    for _, ent in ipairs(rawNeighbors) do
        if not IsValid(ent) or ent == self then continue end
        
        local diff = GetPos( ent ) - pos
        local distSqr = LengthSqr( diff )
        
        
        local toNeighbor = GetNormalized( diff )
        local dot = Dot( GetForward( self ), toNeighbor)
    
        if dot > -FOV_THRESHOLD then 
            table_insert(validNeighbors, {ent = ent, dist = math_sqrt(distSqr)})
        end
        
    end

    local separation = Vector(0, 0, 0)
    local alignment = Vector(0, 0, 0)
    local cohesion = Vector(0, 0, 0)
    local avgPos = Vector(0, 0, 0)
    
    local numNeighbors = #validNeighbors
    
    if numNeighbors > 0 then
        for _, n in ipairs(validNeighbors) do
            local otherPos = GetPos( n.ent )
            
            if COLLISION_RULE:GetBool() then
                local flee = pos - otherPos
                Normalize( flee )
                separation = separation + (flee / (n.dist / MIN_DIST:GetFloat())) 
            end
            
            if ALIGNMENT_RULE:GetBool() then alignment = alignment + GetForward( n.ent ) end
            
            if COHESION_RULE:GetBool() then avgPos = avgPos + otherPos end
        end
        
        if ALIGNMENT_RULE:GetBool() then alignment = GetNormalized( (alignment / numNeighbors) ) end
        if COHESION_RULE:GetBool() then cohesion = GetNormalized( ((avgPos / numNeighbors) - pos) ) end
    end

    // "dim sum un" idea (https://steamcommunity.com/profiles/76561198146498441)
    
    local entities = ents_FindByClass("orbit")
    local orbitForce = Vector()
    if #entities >= 1 then
        table_sort( entities, function( a, b ) return Distance2DSqr( pos, GetPos( a ) ) <  Distance2DSqr( pos, GetPos( a ) ) end)
        

        local targetPos = GetPos( entities[1] )
        local distToTarget = Distance( pos, targetPos)

        if distToTarget > ORBIT_DISTANCE:GetInt() then
            local dirToTarget = GetNormalized( targetPos - pos )

            local orbitDir = GetNormalized(Cross( dirToTarget, Vector(0, 0, 1)))

            orbitForce = (dirToTarget * 0.3) + (orbitDir * 1.0)

        end
    end
    
    local steer = (separation * SEPARATION_FACTOR:GetFloat()) + 
                  (alignment * ALIGNMENT_FACTOR:GetFloat()) + 
                  (cohesion * COHESION_FACTOR:GetFloat()) + 
                  (orbitForce * ORBIT_FACTOR:GetFloat())

    
    steer = steer + VectorRand() * NOISE_FACTOR:GetFloat()

    if Length( steer ) > 1 then Normalize( steer ) end
    
    local traceDist = TRACE_LEN:GetFloat()
    
    -- local forwardRay = util.QuickTrace(pos, self:GetForward() * traceDist, function(ent) return self:NotMyNeighbors(ent) end)

    local forwardRay = util_TraceLine({
        start = pos,
        endpos = pos + GetForward( self ) * traceDist,
        mask = MASK_ALL,
        filter = function(ent) return self:NotMyNeighbors(ent) end
    })
    
    // I am having some issues with this escaping shit
    if forwardRay.Hit then
        local escapeDir = self:ObstacleRay()

        local sub = (1 - forwardRay.Fraction)
        local repelPower = sub * 2 
        local repulsion = forwardRay.HitNormal * repelPower
        
        local finalEscape = GetNormalized( escapeDir + repulsion )

        local intensity = sub
        steer = LerpVector(intensity, steer, finalEscape * 10)
    end

    if not IsInWorld( self ) then
        local centerDir = GetNormalized( Vector(0,0,0) - pos )
        steer = centerDir * 20
    end

    if Length( steer ) > 1 then Normalize( steer ) end
    
    local currentDir = GetForward( self )
    local finalDir = GetNormalized( currentDir + steer * 0.1 )
    
    SetAngles( self, finalDir:Angle())
    SetPos( self, pos + finalDir * (SPEED:GetFloat() * FrameTime()) )
    NextThink( self, CurTime())

    -- print( (SysTime() - t) * 1000 )

    return true
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end
    undo.Create("Boids")
        for i = 1, SPAWN_NUMBER:GetInt() do
            local ent = ents.Create(ClassName)
            ent:SetPos(tr.HitPos + tr.HitNormal * 1000 + VectorRand() * 30)
            ent:Spawn()
            ent:Activate()
            undo.AddEntity(ent)
        end
        undo.SetPlayer(ply)
    undo.Finish()
end