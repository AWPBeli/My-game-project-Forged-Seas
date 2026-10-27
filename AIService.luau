local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShipParts = require(ReplicatedStorage:WaitForChild("ShipParts"))
local Blueprints = require(ReplicatedStorage:WaitForChild("Blueprints"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local BoatService = require(ServerScriptService:WaitForChild("BoatService"))

local AIService = {}

local GUARD_RESPAWN = 40
local PIRATE_RESPAWN = 20
local DETECT_RANGE = 270   -- how far they notice you
local LEASH_RANGE = 400    -- how far from their spawn they will chase
local SPAWN_RANGE = 750    -- ships only appear when a player is this close
local DESPAWN_RANGE = 1100 -- ...and vanish when everyone is farther than this for a while
local DESPAWN_DELAY = 15
local SAFE_R = WorldConfig.Harbor.Radius

local PIRATE_NAMES = { "Pirate Raft", "Pirate Skiff", "Pirate Gunboat" }

local slots = {}
local analysisCache = {}
local territoriesFolder

local function playerNear(pos, range)
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude <= range then return true end
	end
	return false
end

local function steerTo(ship, point)
	local hullCF = ship.Hull.CFrame
	local lv = hullCF:VectorToObjectSpace(point - hullCF.Position)
	local angle = math.atan2(-lv.X, -lv.Z) -- > 0 means the target is on the left
	return angle, Vector3.new(lv.X, 0, lv.Z).Magnitude
end

local function nearestPlayerShip(ship)
	local best, bestDist = nil, DETECT_RANGE
	for _, other in pairs(BoatService.Boats) do
		if other.Alive and other.Owner then
			local p = other.Hull.Position
			if p.X * p.X + p.Z * p.Z > SAFE_R * SAFE_R then -- ships inside the harbor are untouchable
				local d = (p - ship.Hull.Position).Magnitude
				if d < bestDist then best, bestDist = other, d end
			end
		end
	end
	return best
end

local function think(ship, slot)
	local input = ship.AIInput
	local home = slot.Spawn.Position
	local target = nearestPlayerShip(ship)

	if target and (target.Hull.Position - home).Magnitude < LEASH_RANGE then
		local tpos = target.Hull.Position
		local angle, dist = steerTo(ship, tpos)
		input.Steer = -math.clamp(angle * 2, -1, 1)

		local preferred = math.max(ship.Range * 0.5, 40)
		if dist > preferred then
			input.Throttle = 1
		elseif dist < preferred * 0.5 then
			input.Throttle = -0.5
		else
			input.Throttle = 0.2
		end

		local wobble = 4 + dist * 0.04
		local jitter = Vector3.new(math.random(-100, 100), 0, math.random(-100, 100)) / 100 * wobble
		ship.AimPos = tpos + jitter
		ship.Firing = ship.Range > 0 and dist <= ship.Range * 0.9
	else
		ship.Firing = false
		ship.AimPos = nil
		if not ship.Wander or (ship.Wander - ship.Hull.Position).Magnitude < 25 then
			ship.Wander = home + Vector3.new(math.random(-90, 90), 0, math.random(-90, 90))
		end
		local angle = steerTo(ship, ship.Wander)
		input.Steer = -math.clamp(angle * 2, -1, 1)
		input.Throttle = math.abs(angle) < 1.2 and 0.5 or 0.2
	end
end

local function getAnalysis(key, list)
	local analysis = analysisCache[key]
	if not analysis then
		analysis = ShipParts.Analyze(list())
		analysisCache[key] = analysis
	end
	if not analysis.Ok then
		error("AI design '" .. key .. "' is invalid: " .. table.concat(analysis.Problems, "; "))
	end
	return analysis
end

local function spawnShip(slot)
	local sp = slot.Spawn
	local cf = CFrame.new(sp.Position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	local ship

	if sp:GetAttribute("Pirate") then
		local i = math.random(1, Blueprints.PirateCount)
		local analysis = getAnalysis("pirate" .. i, function() return Blueprints.Pirate(i) end)
		ship = BoatService.Build(cf, analysis, nil, "Pirates")
		ship.Model:SetAttribute("OwnerName", PIRATE_NAMES[i] or "Pirate")
	else
		local faction = sp:GetAttribute("Faction")
		local tier = sp:GetAttribute("Tier") or 1
		local analysis = getAnalysis(faction .. tier, function() return Blueprints.Faction(faction, tier) end)
		ship = BoatService.Build(cf, analysis, nil, faction)
		ship.Model:SetAttribute("OwnerName", WorldConfig.Factions[faction].Name .. " (Tier " .. tier .. ")")
	end
	slot.Boat = ship
	slot.FarSince = nil
end

local function territoryHeld(slot)
	local name = slot.Spawn:GetAttribute("Territory")
	if not name then return false end
	local t = territoriesFolder:FindFirstChild(name)
	return t ~= nil and (t:GetAttribute("OwnerId") or 0) ~= 0
end

function AIService.Init()
	local folder = workspace:WaitForChild("AISpawns")
	territoriesFolder = workspace:WaitForChild("Territories")
	for _, sp in ipairs(folder:GetChildren()) do
		if sp:IsA("BasePart") then
			table.insert(slots, { Spawn = sp, Boat = nil, NextSpawn = 0, Pirate = sp:GetAttribute("Pirate") == true })
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			for _, slot in ipairs(slots) do
				local ship = slot.Boat
				if ship and ship.Alive then
					-- vanish when nobody is around
					if playerNear(ship.Hull.Position, DESPAWN_RANGE) then
						slot.FarSince = nil
					else
						slot.FarSince = slot.FarSince or now
						if now - slot.FarSince > DESPAWN_DELAY then
							BoatService.Destroy(ship, false)
							slot.Boat = nil
							slot.NextSpawn = now
							ship = nil
						end
					end
					if ship then think(ship, slot) end
				else
					if ship then -- it was destroyed
						slot.Boat = nil
						slot.NextSpawn = now + (slot.Pirate and PIRATE_RESPAWN or GUARD_RESPAWN)
					end
					if now >= slot.NextSpawn and not territoryHeld(slot) and playerNear(slot.Spawn.Position, SPAWN_RANGE) then
						local ok, err = pcall(spawnShip, slot)
						if not ok then
							warn("[AIService] " .. tostring(err))
							slot.NextSpawn = now + 30
						end
					end
				end
			end
		end
	end)
end

return AIService