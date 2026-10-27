local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Sfx = {}

-- plays sound `key` at a world position for every player close enough to hear it
function Sfx.Play(key, pos, gain)
	local cfg = Config.Sounds[key]
	local remote = Remotes:FindFirstChild("Sfx")
	if not cfg or not remote then return end
	local range = (cfg.Max or 500) * 1.2
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude <= range then
			remote:FireClient(p, key, pos, gain or 1)
		end
	end
end

return Sfx