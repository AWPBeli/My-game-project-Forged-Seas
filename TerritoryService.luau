local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local BoatService = require(ServerScriptService:WaitForChild("BoatService"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TerritoryService = {}
local territories = {}
local harbor = nil

local function ownerColor(userId)
	return Color3.fromHSV((math.abs(userId) % 360) / 360, 0.7, 1)
end

local function refresh(t)
	local m = t.Model
	local ownerId = m:GetAttribute("OwnerId")
	local faction = WorldConfig.Factions[m:GetAttribute("Faction")]
	local holder = ownerId == 0 and faction.Name or m:GetAttribute("OwnerName")

	local text = ("%s  [Tier %d]\n%s: %s"):format(m.Name, m:GetAttribute("Tier"), ownerId == 0 and "Held by" or "Owner", holder)
	local progress = math.floor(m:GetAttribute("Progress"))
	if progress > 0 then text ..= ("\nCapturing... %d%%"):format(progress) end
	t.Label.Text = text
	t.Zone.Color = ownerId == 0 and faction.Color or ownerColor(ownerId)
end

local function setOwner(t, player)
	local m = t.Model
	local oldId = m:GetAttribute("OwnerId")
	if oldId ~= 0 then
		local old = Players:GetPlayerByUserId(oldId)
		if old and old ~= player then
			Remotes.Notify:FireClient(old, "You lost " .. m.Name .. "!")
		end
	end
	m:SetAttribute("OwnerId", player and player.UserId or 0)
	m:SetAttribute("OwnerName", player and player.Name or "")
	m:SetAttribute("CapturerId", 0)
	m:SetAttribute("Progress", 0)
	if player then
		Remotes.Notify:FireClient(player, "You conquered " .. m.Name .. "! Its oil now pays you.")
	end
	refresh(t)
end

local function inside(zone, pos)
	local lp = zone.CFrame:PointToObjectSpace(pos)
	return math.abs(lp.X) <= zone.Size.X / 2 and math.abs(lp.Z) <= zone.Size.Z / 2
end

local function updateCapture(t, dt)
	local m = t.Model
	local players, playerCount, aiPresent, lone = {}, 0, false, nil

	for _, b in pairs(BoatService.Boats) do
		if b.Alive and inside(t.Zone, b.Hull.Position) then
			if b.Owner then
				if not players[b.Owner] then
					players[b.Owner] = true
					playerCount += 1
					lone = b.Owner
				end
			else
				aiPresent = true
			end
		end
	end

	local progress = m:GetAttribute("Progress")
	if playerCount == 1 and not aiPresent then
		if lone.UserId == m:GetAttribute("OwnerId") then
			progress = math.max(0, progress - dt * 20)
		else
			if m:GetAttribute("CapturerId") ~= lone.UserId then
				m:SetAttribute("CapturerId", lone.UserId)
				progress = 0
			end
			progress += 100 / TechConfig.Territory.CaptureSeconds * dt
			if progress >= 100 then
				setOwner(t, lone)
				return
			end
		end
	else
		progress = math.max(0, progress - dt * 10) -- contested or empty: progress drains
	end
	m:SetAttribute("Progress", progress)
	refresh(t)
end

local function depositSum(model)
	local sum = 0
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "OilDeposit" then
			sum += d:GetAttribute("Income") or TechConfig.Territory.OilIncomePerDeposit
		end
	end
	return sum
end

local function payOil()
	local income = {}
	for _, t in ipairs(territories) do
		local ownerId = t.Model:GetAttribute("OwnerId")
		if ownerId ~= 0 then
			local owner = Players:GetPlayerByUserId(ownerId)
			if owner then income[owner] = (income[owner] or 0) + depositSum(t.Model) end
		end
	end
	-- Home Harbor pays every player
	if harbor then
		local sum = depositSum(harbor)
		for _, p in ipairs(Players:GetPlayers()) do
			income[p] = (income[p] or 0) + sum
		end
	end
	for player, amount in pairs(income) do
		PlayerData.AddMoney(player, amount)
	end
end

function TerritoryService.Init()
	local folder = workspace:WaitForChild("Territories")
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Home") then
			harbor = model
		else
			local zone = model:FindFirstChild("Zone")
			if zone and zone:IsA("BasePart") then
				zone.CanQuery = false
				zone.CanCollide = false
				model:SetAttribute("OwnerId", 0)
				model:SetAttribute("OwnerName", "")
				model:SetAttribute("Progress", 0)
				model:SetAttribute("CapturerId", 0)

				local gui = Instance.new("BillboardGui")
				gui.Adornee = zone
				gui.Size = UDim2.fromOffset(260, 60)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 48, 0)
				gui.AlwaysOnTop = true
				gui.MaxDistance = 900
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.TextColor3 = Color3.new(1, 1, 1)
				label.Font = Enum.Font.GothamBold
				label.TextSize = 17
				label.TextStrokeTransparency = 0.4
				label.Parent = gui
				gui.Parent = zone

				local t = { Model = model, Zone = zone, Label = label }
				table.insert(territories, t)
				refresh(t)
			end
		end
	end

	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			for _, t in ipairs(territories) do updateCapture(t, dt) end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TechConfig.Territory.OilTickSeconds)
			payOil()
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		for _, t in ipairs(territories) do
			if t.Model:GetAttribute("OwnerId") == p.UserId then setOwner(t, nil) end
		end
	end)
end

return TerritoryService