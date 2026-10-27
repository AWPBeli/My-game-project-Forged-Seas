local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientAudio = {}
local rng = Random.new()

local sfxFolder = Instance.new("Folder")
sfxFolder.Name = "LocalSfx"
sfxFolder.Parent = workspace

local function configure(sound, cfg, gain)
	sound.SoundId = cfg.Id
	sound.Volume = math.clamp(cfg.Volume * (gain or 1) * Config.MasterVolume, 0, 10)
	sound.PlaybackSpeed = cfg.Speed * (1 + rng:NextNumber(-cfg.Var, cfg.Var))
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = cfg.Min or 20
	sound.RollOffMaxDistance = cfg.Max or 500
end

-- a sound at a point in the world: Roblox pans it left/right and fades it by distance from the camera
function ClientAudio.Play3D(key, pos, gain)
	local cfg = Config.Sounds[key]
	if not cfg then return end
	local camPos = workspace.CurrentCamera.CFrame.Position
	if (pos - camPos).Magnitude > (cfg.Max or 500) * 1.2 then return end

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = pos
	anchor.Parent = sfxFolder

	local s = Instance.new("Sound")
	configure(s, cfg, gain)
	s.Parent = anchor
	s:Play()
	Debris:AddItem(anchor, cfg.Dur or 2)
end

-- an interface sound (flat, not positioned)
function ClientAudio.UI(key, gain)
	local cfg = Config.Sounds[key]
	if not cfg then return end
	local s = Instance.new("Sound")
	s.SoundId = cfg.Id
	s.Volume = math.clamp(cfg.Volume * (gain or 1) * Config.MasterVolume, 0, 10)
	s.PlaybackSpeed = cfg.Speed * (1 + rng:NextNumber(-cfg.Var, cfg.Var))
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, cfg.Dur or 2)
end

-- sounds the server sends (weapons, hits, explosions...)
local sfxRemote = Remotes:WaitForChild("Sfx", 10)
if sfxRemote then
	sfxRemote.OnClientEvent:Connect(function(key, pos, gain)
		ClientAudio.Play3D(key, pos, gain)
	end)
else
	warn("[Audio] The 'Sfx' RemoteEvent is missing - did you add \"Sfx\" to the list in Main?")
end

-- engine chug on every ship + sea ambience around you
local ships = {}
task.spawn(function()
	local nextSwell = os.clock() + 3
	while true do
		local dt = task.wait(0.1)
		local cam = workspace.CurrentCamera
		local camPos = cam.CFrame.Position
		local boats = workspace:FindFirstChild("Boats")

		if boats then
			for _, m in ipairs(boats:GetChildren()) do
				local root = m:IsA("Model") and m.PrimaryPart
				if root and (root.Position - camPos).Magnitude < 650 then
					local top = m:GetAttribute("TopSpeed") or 0
					if top > 0 then
						local st = ships[m]
						if not st then
							local s = Instance.new("Sound")
							s.Parent = root
							st = { Sound = s, Next = rng:NextNumber(0, 0.5) }
							ships[m] = st
						end
						local v = root.AssemblyLinearVelocity
						local ratio = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / top, 0, 1)
						st.Next -= dt
						if st.Next <= 0 then
							st.Next = 0.6 - ratio * 0.42 -- faster chug at speed
							local cfg = Config.Sounds.Thump
							configure(st.Sound, cfg, 0.6 + ratio * 1.4)
							st.Sound.PlaybackSpeed = cfg.Speed * (0.8 + ratio * 0.6) * (1 + rng:NextNumber(-cfg.Var, cfg.Var))
							st.Sound.TimePosition = 0
							st.Sound:Play()
						end
					end
				end
			end
		end
		for m in pairs(ships) do
			if not m.Parent then ships[m] = nil end
		end

		if os.clock() >= nextSwell and cam.CameraType ~= Enum.CameraType.Scriptable then
			nextSwell = os.clock() + rng:NextNumber(4, 8)
			local side = rng:NextInteger(0, 1) == 0 and -1 or 1
			ClientAudio.Play3D("SeaSwell", camPos + cam.CFrame.RightVector * side * 45 + Vector3.new(0, -8, 0), 1)
		end
	end
end)

-- warn about any sound file that does not load
task.spawn(function()
	local seen, failed = {}, {}
	for _, cfg in pairs(Config.Sounds) do
		if not seen[cfg.Id] then
			seen[cfg.Id] = true
			local s = Instance.new("Sound")
			s.SoundId = cfg.Id
			local ok = pcall(function() ContentProvider:PreloadAsync({ s }) end)
			if not ok or s.TimeLength <= 0 then table.insert(failed, cfg.Id) end
			s:Destroy()
		end
	end
	if #failed > 0 then
		warn("[Audio] These sounds could not load (replace them in SoundConfig): " .. table.concat(failed, ", "))
	end
end)

return ClientAudio