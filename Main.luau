local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- nobody spawns until the world exists (otherwise you land on the default baseplate and fall when it is removed)
Players.CharacterAutoLoads = false

-- 1) Create the RemoteEvents (clients wait for these)
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "DataUpdate", "DesignUpdate", "RequestData", "RequestResearch", "SaveDesign", "LaunchShip", "Aim", "Notify", "Sfx" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
end
remotes.Parent = ReplicatedStorage

-- 2) Safe loading: nothing can freeze the whole game, and every failure says what and why
local status = {}
local function note(name, ok)
	table.insert(status, name .. (ok and ": ok" or ": FAILED"))
end

local function load(name)
	local result, done = nil, false
	task.spawn(function()
		local ok, r = xpcall(function()
			local module = ServerScriptService:WaitForChild(name, 5)
			if not module then
				error("'" .. name .. "' was not found in ServerScriptService (check its name and that it is a ModuleScript)")
			end
			return require(module)
		end, debug.traceback)
		if ok then
			result = r
		else
			warn("[Main] Could not load '" .. name .. "':\n" .. tostring(r))
		end
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 12 do task.wait() end
	if not done then
		warn("[Main] '" .. name .. "' is stuck while loading - it is waiting for something that does not exist. Look for an 'Infinite yield possible' warning in Output.")
	end
	note("load " .. name, result ~= nil)
	return result
end

local function start(name, module, fnName)
	if not module then return end
	local ok, err = xpcall(module[fnName], debug.traceback)
	if not ok then
		warn("[Main] " .. name .. "." .. fnName .. " failed:\n" .. tostring(err))
	end
	note(name .. "." .. fnName, ok)
end

local okShipParts, ShipParts = pcall(function()
	return require(ReplicatedStorage:WaitForChild("ShipParts", 5))
end)
if not okShipParts then
	warn("[Main] ShipParts could not load: " .. tostring(ShipParts))
	ShipParts = nil
end

-- 3) The world comes first
local MapBuilder = load("MapBuilder")
start("MapBuilder", MapBuilder, "Build")

-- now players may spawn
Players.CharacterAutoLoads = true
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function() p:LoadCharacter() end)
end

-- 4) Everything else
local PlayerData = load("PlayerData")
local BoatService = load("BoatService")
local TerritoryService = load("TerritoryService")
local AIService = load("AIService")

start("BoatService", BoatService, "Init")
start("PlayerData", PlayerData, "Init")
start("TerritoryService", TerritoryService, "Init")
start("AIService", AIService, "Init")

-- 5) Client requests (the server re-checks everything)
remotes.RequestData.OnServerEvent:Connect(function(player)
	if PlayerData then PlayerData.Sync(player, true) end
end)

remotes.RequestResearch.OnServerEvent:Connect(function(player, id)
	if not PlayerData or typeof(id) ~= "string" then return end
	local _, message = PlayerData.Unlock(player, id)
	remotes.Notify:FireClient(player, message)
end)

remotes.SaveDesign.OnServerEvent:Connect(function(player, blueprint)
	if not PlayerData or not BoatService or not ShipParts or typeof(blueprint) ~= "table" then return end
	local d = PlayerData.Get(player)
	if not d then return end
	local analysis = ShipParts.Analyze(blueprint, d.Unlocked)
	if #analysis.Blocks > 0 then
		PlayerData.SetDesign(player, BoatService.ToList(analysis))
	end
end)

remotes.LaunchShip.OnServerEvent:Connect(function(player, blueprint)
	if not BoatService or typeof(blueprint) ~= "table" then return end
	BoatService.PlayerBuild(player, blueprint)
end)

remotes.Aim.OnServerEvent:Connect(function(player, pos, firing)
	if not BoatService or typeof(pos) ~= "Vector3" or pos ~= pos or typeof(firing) ~= "boolean" then return end
	BoatService.PlayerAim(player, pos, firing)
end)

-- tells the loading screen the world is complete, and how many objects the client should receive
local worldTotal = 0
for _, folderName in ipairs({ "OceanTiles", "WorldEdge", "Territories", "AISpawns", "Decor" }) do
	local f = workspace:FindFirstChild(folderName)
	if f then worldTotal += #f:GetDescendants() + 1 end
end
workspace:SetAttribute("WorldTotal", worldTotal)
workspace:SetAttribute("ServerReady", true)

print("[Main] Startup report -> " .. table.concat(status, " | "))