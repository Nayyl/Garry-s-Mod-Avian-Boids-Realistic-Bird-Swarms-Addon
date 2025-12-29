AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local DELETE_ON_ESCAPE_REALITY = CreateConVar( "sv_boids_delete_on_escape_reality", "0", FCVAR_NONE, "Delete the boid when he's getting out of the world", 0, 1 )
local COLLISION_RULE = CreateConVar( "sv_boids_collision_avoidances", "1", FCVAR_NONE, "", 0, 1 )
local ALIGNMENT_RULE = CreateConVar( "sv_boids_alignment", "1", FCVAR_NONE, "", 0, 1 )
local COHESION_RULE = CreateConVar( "sv_boids_cohesion", "1", FCVAR_NONE, "", 0, 1 )
local NOISE_FACTOR = CreateConVar( "sv_boids_noise_factor", "0.5", FCVAR_NONE, "", 0, 1 )
local MIN_DIST = CreateConVar( "sv_boids_separation_distances", "5", FCVAR_NONE, "", 2, 50 )
local SPEED = CreateConVar( "sv_boids_speed", "600", FCVAR_NONE, "", 0, 1000 )
local SPAWN_NUMBER = CreateConVar( "sv_boids_spawn_number", "1", FCVAR_NONE, "", 1, 100 )
local TRACE_LEN = CreateConVar( "sv_boids_trace_lengh", "500", FCVAR_NONE, "", 10, 1000 )

local BOIDS_MODEL = CreateConVar("sv_boids_model", "models/crow.mdl")

local ALIGNMENT_FACTOR = CreateConVar( "sv_boids_alignment_factor", "0.8", FCVAR_NONE, "", 1, 10 )
local COHESION_FACTOR = CreateConVar( "sv_boids_cohesion_factor", "1.0", FCVAR_NONE, "", 1, 10 )
local SEPARATION_FACTOR = CreateConVar( "sv_boids_separation_factor", "1.5", FCVAR_NONE, "", 1, 10 )
local ORBIT_FACTOR = CreateConVar( "sv_boids_orbit_factor", "1.5", FCVAR_NONE, "", 0, 10 )
local ORBIT_DISTANCE = CreateConVar( "sv_boids_orbit_distance", "200", FCVAR_NONE, "", 10, 2000 )

local DISTANCE_CHECK = CreateConVar( "sv_boids_distance_check", "1", FCVAR_NONE, "However, check the distance between boids to consider them as neighbors instead of just looking at who is in the cell.", 0, 1 )
local DISTANCE_CHECK_VALUE = CreateConVar( "sv_boids_distance_check_value", "250", FCVAR_NONE, "", 100, 2000 )

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

BOID_GRID = {}
hook.Add("Tick", "UpdateBoidGrid", function()
    BOID_GRID = {} 
    
    local cell_size = CELL_SIZE:GetFloat()
    for _, ent in ipairs(ents.FindByClass("boids")) do 
        if not IsValid(ent) then continue end

        local pos = ent:GetPos()

        local gx = math.floor(pos.x / cell_size)
        local gy = math.floor(pos.y / cell_size)
        local gz = math.floor(pos.z / cell_size)
        
        local key = gx .. "|" .. gy .. "|" .. gz
        
        BOID_GRID[key] = BOID_GRID[key] or {}
        table.insert(BOID_GRID[key], ent)
        
        ent.GridX = gx
        ent.GridY = gy
        ent.GridZ = gz
    end
end)

function ENT:NotMyNeighbors( ent )
    if ent == self or ent:GetClass() == "boids" then return false end
    return true
end

function ENT:Initialize()
    self:SetModel(BOIDS_MODEL:GetString())
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NOCLIP)
    self:SetSolid(SOLID_VPHYSICS)
    
    self:SetAngles(Angle(math.random(-180, 180), math.random(-180, 180), 0))

    self:ResetSequence("fly01") -- "fly01"
    self:SetCycle( math.Rand(0,1) )
    self:SetAutomaticFrameAdvance( true )
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
                            if not DISTANCE_CHECK:GetBool() then table.insert(neighbors, b) continue end

                            local distSqr = b:GetPos():DistToSqr(self:GetPos())
                            if distSqr < (DISTANCE_CHECK_VALUE:GetInt() ^ 2) then
                                table.insert(neighbors, b)
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
    local pos = self:GetPos()
    local angles = self:GetAngles()
    
    for _, dir in ipairs(BoidDirections) do
        local worldDir = LocalToWorld(dir, Angle(0,0,0), Vector(0,0,0), angles)
        
        
        local tr = util.TraceLine({
            start = pos,
            endpos = pos + worldDir * TRACE_LEN:GetFloat(), 
            filter = function( ent ) return self:NotMyNeighbors( ent ) end
        })
        
        
        if not tr.Hit then
            -- developer 1 to see this
            debugoverlay.Line( tr.StartPos, tr.HitPos, engine.TickInterval()*10, Color( 0, 255, 0, 1), false )
            return worldDir
        end
        debugoverlay.Line( tr.StartPos, tr.HitPos, engine.TickInterval()*10, Color( 255, 0, 0, 1), false )
    end
    
    
    return -self:GetForward() 
end

function ENT:Think()
    if DELETE_ON_ESCAPE_REALITY:GetBool() and not self:IsInWorld() then 
        self:Remove() 
        return 
    end 
    
    local pos = self:GetPos()
    local rawNeighbors = self:GetNearByOptimized()
    local validNeighbors = {}
    
    local FOV_THRESHOLD = 0 -- 0.5 c'est environ 120° devant. probably a convar for this

    for _, ent in ipairs(rawNeighbors) do
        if not IsValid(ent) or ent == self then continue end
        
        local diff = ent:GetPos() - pos
        local distSqr = diff:LengthSqr()
        
        
        local toNeighbor = diff:GetNormalized()
        local dot = self:GetForward():Dot(toNeighbor)
    
        if dot > -FOV_THRESHOLD then 
            table.insert(validNeighbors, {ent = ent, dist = math.sqrt(distSqr)})
        end
        
    end

    local separation = Vector(0, 0, 0)
    local alignment = Vector(0, 0, 0)
    local cohesion = Vector(0, 0, 0)
    local avgPos = Vector(0, 0, 0)
    
    local numNeighbors = #validNeighbors
    
    if numNeighbors > 0 then
        for _, n in ipairs(validNeighbors) do
            local otherPos = n.ent:GetPos()
            
            if COLLISION_RULE:GetBool() then
                local flee = pos - otherPos
                flee:Normalize()
                separation = separation + (flee / (n.dist / MIN_DIST:GetFloat())) 
            end
            
            if ALIGNMENT_RULE:GetBool() then alignment = alignment + n.ent:GetForward() end
            
            if COHESION_RULE:GetBool() then avgPos = avgPos + otherPos end
        end
        
        if ALIGNMENT_RULE:GetBool() then alignment = (alignment / numNeighbors):GetNormalized() end
        if COHESION_RULE:GetBool() then cohesion = ((avgPos / numNeighbors) - pos):GetNormalized() end
    end

    // "dim sum un" idea (https://steamcommunity.com/profiles/76561198146498441)
    
    local entities = ents.FindByClass("orbit")
    local orbitForce = Vector()
    if #entities >= 1 then
        table.sort( entities, function( a, b ) return pos:Distance2DSqr( a:GetPos() ) <  pos:Distance2DSqr( b:GetPos() ) end)
        

        local targetPos = entities[1]:GetPos()
        local distToTarget = pos:Distance(targetPos)

        if distToTarget > ORBIT_DISTANCE:GetInt() then
            local dirToTarget = (targetPos - pos):GetNormalized()

            local orbitDir = dirToTarget:Cross(Vector(0, 0, 1)):GetNormalized()

            orbitForce = (dirToTarget * 0.3) + (orbitDir * 1.0)

        end
    end
    
    local steer = (separation * SEPARATION_FACTOR:GetFloat()) + 
                  (alignment * ALIGNMENT_FACTOR:GetFloat()) + 
                  (cohesion * COHESION_FACTOR:GetFloat()) + 
                  (orbitForce * ORBIT_FACTOR:GetFloat())

    
    steer = steer + VectorRand() * NOISE_FACTOR:GetFloat()

    if steer:Length() > 1 then steer:Normalize() end

    local forwardRay = util.QuickTrace(pos, self:GetForward() * TRACE_LEN:GetFloat(), function( ent ) return self:NotMyNeighbors( ent ) end)
    
    local traceDist = TRACE_LEN:GetFloat()
    local forwardRay = util.QuickTrace(pos, self:GetForward() * traceDist, function(ent) return self:NotMyNeighbors(ent) end)
    
    // I am having some issues with this escaping shit
    if forwardRay.Hit then
        local escapeDir = self:ObstacleRay()

        local repelPower = (1 - forwardRay.Fraction) * 2 
        local repulsion = forwardRay.HitNormal * repelPower
        
        local finalEscape = (escapeDir + repulsion):GetNormalized()

        local intensity = (1 - forwardRay.Fraction) 
        steer = LerpVector(intensity, steer, finalEscape * 10)
    end

    if not self:IsInWorld() then
        local centerDir = (Vector(0,0,0) - pos):GetNormalized()
        steer = centerDir * 20
    end

    if steer:Length() > 1 then steer:Normalize() end
    
    local currentDir = self:GetForward()
    local finalDir = (currentDir + steer * 0.1):GetNormalized()
    
    self:SetAngles(finalDir:Angle())
    self:SetPos(pos + finalDir * (SPEED:GetFloat() * FrameTime()))
    self:NextThink(CurTime())
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