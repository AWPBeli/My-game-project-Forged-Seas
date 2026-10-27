local Lighting = game:GetService("Lighting")

Lighting.ClockTime = 15.5
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(90, 100, 120)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 150)
Lighting.GlobalShadows = true
Lighting.EnvironmentSpecularScale = 0.3 -- less sky reflection on shiny surfaces = no colour glints
Lighting.EnvironmentDiffuseScale = 0.8

local function ensure(class)
	local o = Lighting:FindFirstChildOfClass(class)
	if not o then
		o = Instance.new(class)
		o.Parent = Lighting
	end
	return o
end

local atm = ensure("Atmosphere")
atm.Density = 0.3
atm.Offset = 0.25
atm.Color = Color3.fromRGB(199, 210, 230)
atm.Decay = Color3.fromRGB(106, 112, 125)
atm.Glare = 0.25 -- sun glare flares move with the camera
atm.Haze = 0.75

-- gentle colour only: bloom and sun rays shimmer on moving water and cost frame time
local cc = ensure("ColorCorrectionEffect")
cc.Saturation = 0.15
cc.Contrast = 0.08
for _, className in ipairs({ "BloomEffect", "SunRaysEffect" }) do
	local e = Lighting:FindFirstChildOfClass(className)
	if e then e:Destroy() end
end

-- the sea floor under the animated water: plain, matte, same colour (no mirror to flash through gaps)
local tiles = workspace:WaitForChild("OceanTiles", 15)
if tiles then
	for _, t in ipairs(tiles:GetChildren()) do
		t.Material = Enum.Material.SmoothPlastic
		t.Reflectance = 0
		t.Color = Color3.fromRGB(20, 90, 160)
		t.CastShadow = false
	end
end