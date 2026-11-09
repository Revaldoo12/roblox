--[[
	Environment.lua
	Menyiapkan dunia di server:
	  - Gravitasi
	  - Menghapus Baseplate & SpawnLocation bawaan template (supaya jurang benar-benar jurang)
	  - Langit: matahari, awan dinamis Roblox, kabut lembut, efek cahaya halus
	  - Pulau melayang sebagai titik start
	  - Collision group agar pemain tidak saling tabrak
	Jalan & dekorasi dibangun di client (TrackStreamer). Pergantian waktu
	per zona juga di client (perubahan Lighting dari client hanya lokal).
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
local C = GameConfig.Colors

local function clearTemplate()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("SpawnLocation") or (child.Name == "Baseplate" and child:IsA("BasePart")) then
			child:Destroy()
		end
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		for _, child in ipairs(terrain:GetChildren()) do
			if child:IsA("Clouds") then
				child:Destroy()
			end
		end
	end
end

local function setupLighting()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local zone = GameConfig.Zones[1]
	Lighting.ClockTime = zone.ClockTime
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = zone.Brightness
	Lighting.Ambient = zone.Ambient
	Lighting.OutdoorAmbient = zone.Ambient
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6
	Lighting.FogEnd = 100000

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 1500
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.28
	atmo.Offset = 0.1
	atmo.Color = zone.AtmoColor
	atmo.Decay = zone.AtmoDecay
	atmo.Glare = 0.4
	atmo.Haze = 1.4
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.04
	cc.Saturation = -0.05
	cc.Parent = Lighting

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.5
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

local function sphere(props)
	local p = makePart(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function buildStartIsland()
	local old = Workspace:FindFirstChild("OBC_Start")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "OBC_Start"

	-- pulau: lapisan rumput di atas, batuan mengecil ke bawah
	makePart({
		Name = "IslandGrass",
		Size = Vector3.new(W + 22, 2, 46),
		CFrame = CFrame.new(0, Y - 1.2, 20),
		Color = C.Grass,
		Parent = folder,
	})
	makePart({
		Name = "IslandSoil",
		Size = Vector3.new(W + 20, 5, 44),
		CFrame = CFrame.new(0, Y - 4.6, 20),
		Color = C.Rock,
		CanCollide = false,
		Parent = folder,
	})
	makePart({
		Name = "IslandRoot",
		Size = Vector3.new(W + 10, 8, 30),
		CFrame = CFrame.new(0, Y - 10.5, 20),
		Color = C.RockDark,
		CanCollide = false,
		Parent = folder,
	})
	makePart({
		Name = "IslandTip",
		Size = Vector3.new(W - 2, 8, 16),
		CFrame = CFrame.new(0, Y - 17, 20),
		Color = C.RockDark,
		CanCollide = false,
		Parent = folder,
	})

	-- jalan batu di atas pulau
	for i = 0, 3 do
		makePart({
			Name = "StartPath",
			Size = Vector3.new(W, 0.4, 10),
			CFrame = CFrame.new(0, Y - 0.2 + 0.01, 5 + i * 10),
			Color = if i % 2 == 0 then C.PathA else C.PathB,
			Parent = folder,
		})
	end

	-- gapura kayu di garis start
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = "GatePost",
			Size = Vector3.new(1.2, 11, 1.2),
			CFrame = CFrame.new(side * (W / 2 + 1.5), Y + 5.5, 1),
			Color = C.Wood,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end
	makePart({
		Name = "GateBeam",
		Size = Vector3.new(W + 5, 1, 1.4),
		CFrame = CFrame.new(0, Y + 11, 1),
		Color = C.WoodDark,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	-- bendera kecil di gapura
	for i = 0, 6 do
		local x = -W / 2 + i * (W / 6)
		local flag = makePart({
			Name = "GateFlag",
			Size = Vector3.new(1.2, 1.4, 0.1),
			CFrame = CFrame.new(x, Y + 9.9, 1) * CFrame.Angles(0, 0, math.rad(45)),
			Color = C.Flags[(i % #C.Flags) + 1],
			CanCollide = false,
			CastShadow = false,
			Parent = folder,
		})
		flag.Name = "GateFlag" .. i
	end

	-- pohon di pulau
	for _, info in ipairs({ { -14, 28, 1 }, { 13, 34, 0.8 }, { -11, 40, 0.7 } }) do
		local x, z, s = info[1], info[2], info[3]
		makePart({
			Name = "TreeTrunk",
			Size = Vector3.new(1.4 * s, 7 * s, 1.4 * s),
			CFrame = CFrame.new(x, Y + 3.5 * s, z),
			Color = C.WoodDark,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		sphere({
			Name = "TreeLeaves",
			Size = Vector3.new(8, 7, 8) * s,
			CFrame = CFrame.new(x, Y + 8.5 * s, z),
			Color = C.Leaf,
			CanCollide = false,
			Parent = folder,
		})
		sphere({
			Name = "TreeLeavesTop",
			Size = Vector3.new(5, 4.5, 5) * s,
			CFrame = CFrame.new(x + 0.8 * s, Y + 11.5 * s, z - 0.5 * s),
			Color = C.LeafLight,
			CanCollide = false,
			Parent = folder,
		})
	end

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
	buildStartIsland()
	setupCollisionGroups()
	print("[OBC] Environment siap ✔")
end

return Environment
