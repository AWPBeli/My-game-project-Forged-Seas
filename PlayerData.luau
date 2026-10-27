local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("DepthsConquest_v2") -- change the name to wipe everyone's progress
	end)
	if ok then store = result else warn("[PlayerData] DataStore unavailable, progress will NOT be saved: " .. tostring(result)) end
end

local PlayerData = {}
local data, loading = {}, {}

local function defaultData()
	local d = { Money = TechConfig.StartMoney, XP = 0, Unlocked = {} }
	for _, t in ipairs(TechConfig.Techs) do
		if t.XPCost == 0 and not t.Requires then d.Unlocked[t.Id] = true end
	end
	return d
end

function PlayerData.Get(player) return data[player] end

function PlayerData.Sync(player, withDesign)
	local d = data[player]
	if not d then return end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Money.Value = d.Money
		ls.XP.Value = d.XP
	end
	Remotes.DataUpdate:FireClient(player, { Money = d.Money, XP = d.XP, Unlocked = d.Unlocked })
	if withDesign and d.Design then Remotes.DesignUpdate:FireClient(player, d.Design) end
end

function PlayerData.Load(player)
	if data[player] or loading[player] then return end
	loading[player] = true

	local ok, result = false, nil
	if store then
		ok, result = pcall(function() return store:GetAsync("P_" .. player.UserId) end)
		if not ok then warn("[PlayerData] Could not load (normal unless published + API access on): " .. tostring(result)) end
	end
	loading[player] = nil
	if not player.Parent then return end

	local d = defaultData()
	if ok and type(result) == "table" then
		d.Money = result.Money or d.Money
		d.XP = result.XP or d.XP
		for id in pairs(result.Unlocked or {}) do
			if TechConfig.ById[id] then d.Unlocked[id] = true end
		end
		if type(result.Design) == "table" then d.Design = result.Design end
	end
	data[player] = d

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Parent = ls
	local xp = Instance.new("IntValue")
	xp.Name = "XP"
	xp.Parent = ls
	ls.Parent = player

	PlayerData.Sync(player, true)
end

function PlayerData.Save(player)
	local d = data[player]
	if not d or not store then return end
	local ok, err = pcall(function() store:SetAsync("P_" .. player.UserId, d) end)
	if not ok then warn("[PlayerData] Save failed: " .. tostring(err)) end
end

function PlayerData.AddMoney(player, amount)
	local d = data[player]
	if not d then return end
	d.Money += math.floor(amount)
	PlayerData.Sync(player)
end

function PlayerData.AddXP(player, amount)
	local d = data[player]
	if not d then return end
	d.XP += math.floor(amount)
	PlayerData.Sync(player)
end

function PlayerData.SpendMoney(player, amount)
	local d = data[player]
	if not d or d.Money < amount then return false end
	if amount > 0 then
		d.Money -= amount
		PlayerData.Sync(player)
	end
	return true
end

function PlayerData.SetDesign(player, blueprint)
	local d = data[player]
	if not d then return end
	local list = {}
	for _, e in ipairs(blueprint) do
		table.insert(list, { Id = e.Id, X = e.X, Y = e.Y, Z = e.Z, R = e.R })
	end
	d.Design = list
end

function PlayerData.Unlock(player, id)
	local d = data[player]
	local t = TechConfig.ById[id]
	if not d or not t then return false, "Unknown tech" end
	if d.Unlocked[id] then return false, "Already researched" end
	if t.Requires and not d.Unlocked[t.Requires] then
		return false, "Research " .. TechConfig.ById[t.Requires].Name .. " first"
	end
	if d.XP < t.XPCost then
		return false, ("Not enough XP (need %d)"):format(t.XPCost)
	end
	d.XP -= t.XPCost
	d.Unlocked[id] = true
	PlayerData.Sync(player)
	return true, "Researched " .. t.Name .. "!"
end

function PlayerData.Init()
	Players.PlayerAdded:Connect(function(p) PlayerData.Load(p) end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerData.Load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		PlayerData.Save(p)
		data[p] = nil
		loading[p] = nil
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do PlayerData.Save(p) end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, p in ipairs(Players:GetPlayers()) do PlayerData.Save(p) end
		end
	end)
end

return PlayerData