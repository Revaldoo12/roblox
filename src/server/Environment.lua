--[[
	Environment.lua
	Menyiapkan dunia di server:
	  - Gravitasi
	  - Menghapus Baseplate & SpawnLocation bawaan template (supaya jurang benar-benar jurang)
	  - Lighting malam neon: langit berbintang, kabut ungu, bloom, color correction
	  - Platform start + SpawnLocation
	  - Collision group agar pemain tidak saling tabrak
	Lintasan sendiri dibangun di client (TrackStreamer) supaya endless & mulus.
--]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Environment = {}

local PLAYER_GROUP = "OBC_Players"
local Y = GameConfig.TrackY
local W = GameConfig.TrackWidth

local function clearTemplate()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("SpawnLocation") or (child.Name == "Baseplate" and child:IsA("BasePart")) then
			child:Destroy()
		end
	end
end

local function setupLighting()
	for _, child in ipairs(Lighting:GetChildren()) do
		if
			child:IsA("Sky")
			or child:IsA("Atmosphere")
			or child:IsA("BloomEffect")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("DepthOfFieldEffect")
			or child:IsA("BlurEffect")
		then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(40, 30, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 50, 110)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.2
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 100000

	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.MoonAngularSize = 15
	sky.Parent = Lighting

	local pal = GameConfig.Palettes[1]
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.25
	atmo.Color = pal.Fog
	atmo.Decay = pal.Fog:Lerp(Color3.new(0, 0, 0), 0.5)
	atmo.Glare = 0
	atmo.Haze = 1.5
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.9
	bloom.Size = 28
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.15
	cc.Saturation = 0.25
	cc.TintColor = Color3.fromRGB(255, 240, 255)
	cc.Parent = Lighting
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

local function buildStartPlatform()
	local old = Workspace:FindFirstChild("OBC_Start")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "OBC_Start"

	local pal = GameConfig.Palettes[1]
	makePart({
		Name = "StartPlatform",
		Size = Vector3.new(W + 8, 4, 40),
		CFrame = CFrame.new(0, Y - 2, 20),
		Color = Color3.fromRGB(14, 16, 34),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.12,
		Parent = folder,
	})
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = "StartRail",
			Size = Vector3.new(0.6, 0.8, 40),
			CFrame = CFrame.new(side * (W / 2 + 4), Y + 0.2, 20),
			Color = pal.Primary,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
	end
	-- garis start
	makePart({
		Name = "StartLine",
		Size = Vector3.new(W, 0.1, 1.5),
		CFrame = CFrame.new(0, Y + 0.05, 1),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OBC_Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, Y + 0.5, 24)
	spawn.Color = pal.Secondary
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0 -- tanpa force field
	spawn.Neutral = true
	spawn.Parent = folder

	folder.Parent = Workspace
end

local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)

	local function apply(inst: Instance)
		if inst:IsA("BasePart") then
			inst.CollisionGroup = PLAYER_GROUP
		end
	end
	local function onCharacter(character: Model)
		for _, d in ipairs(character:GetDescendants()) do
			apply(d)
		end
		character.DescendantAdded:Connect(apply)
	end
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(onCharacter)
		if p.Character then
			onCharacter(p.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
end

function Environment.Setup()
	Workspace.Gravity = GameConfig.Gravity
	clearTemplate()
	setupLighting()
	buildStartPlatform()
	setupCollisionGroups()
	print("[OBC] Environment siap ✔")
end

return Environment
