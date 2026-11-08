--!strict
--[[
	TrackBuilder.lua
	------------------------------------------------------------
	Membangun SELURUH map lewat kode — kamu tidak perlu menyusun Part
	manual di Studio. Membuat:
	  - Lantai lintasan panjang (ke arah -Z)
	  - Rintangan "Low" (dilompati) & "High" (di-dash) dari ObstacleGenerator
	  - SpawnLocation di awal lintasan
	  - Zona mati (KillPart) di bawah lintasan

	Rintangan ditempatkan sekali saat server start. Untuk endless sejati,
	lihat README (chunk streaming) — untuk prototipe & publish awal, lintasan
	panjang sudah lebih dari cukup.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ObstacleGenerator = require(ReplicatedStorage.Shared.ObstacleGenerator)

local TrackBuilder = {}

local TRACK_LENGTH = 4000 -- panjang total lintasan (studs)
local OBSTACLE_HEIGHT_LOW = 3 -- rintangan rendah: harus dilompati
local OBSTACLE_HEIGHT_HIGH = 6 -- rintangan tinggi: celah di bawah, harus di-dash/menunduk

local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

function TrackBuilder.Build(seed: number?)
	local folder = Instance.new("Folder")
	folder.Name = "GeneratedTrack"

	-- ===== LANTAI =====
	local floor = makePart({
		Name = "TrackFloor",
		Size = Vector3.new(GameConfig.LaneWidth, 2, TRACK_LENGTH),
		Position = Vector3.new(0, 0, -TRACK_LENGTH / 2 + 10),
		Color = Color3.fromRGB(40, 44, 60),
		Material = Enum.Material.SmoothPlastic,
	})
	floor.Parent = folder

	-- garis tengah dekoratif untuk kesan kecepatan
	local stripe = makePart({
		Name = "CenterStripe",
		Size = Vector3.new(1, 2.1, TRACK_LENGTH),
		Position = Vector3.new(0, 0.1, -TRACK_LENGTH / 2 + 10),
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.Neon,
	})
	stripe.Parent = folder

	-- ===== SPAWN =====
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StartSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(GameConfig.LaneWidth, 1, 6)
	spawn.Position = Vector3.new(0, 1.5, 4)
	spawn.Color = Color3.fromRGB(80, 220, 120)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = folder

	-- ===== ZONA MATI (jika jatuh / nabrak terlalu keras) =====
	local kill = makePart({
		Name = "KillZone",
		Size = Vector3.new(GameConfig.LaneWidth * 4, 1, TRACK_LENGTH),
		Position = Vector3.new(0, -20, -TRACK_LENGTH / 2 + 10),
		Transparency = 1,
		CanCollide = false,
		Color = Color3.fromRGB(255, 0, 0),
	})
	kill.Parent = folder
	kill.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)

	-- ===== RINTANGAN =====
	local generator = ObstacleGenerator.new(seed or os.time())
	local placed = 0
	while true do
		-- kecepatan "virtual" naik seiring jarak, agar gap mengecil ke ujung lintasan
		local pseudoSpeed = GameConfig.StartSpeed
			+ (GameConfig.MaxSpeed - GameConfig.StartSpeed) * (placed / 200)
		pseudoSpeed = math.min(pseudoSpeed, GameConfig.MaxSpeed)

		local obstacle = generator:Next(pseudoSpeed)
		if obstacle.distance > TRACK_LENGTH - 20 then
			break
		end

		local zPos = -obstacle.distance + 4
		local xPos = obstacle.lane * (GameConfig.LaneWidth / 3)

		if obstacle.kind == "Low" then
			-- dinding rendah: harus DILOMPATI
			local wall = makePart({
				Name = "Obstacle_Low",
				Size = Vector3.new(GameConfig.LaneWidth / 2.5, OBSTACLE_HEIGHT_LOW, 2),
				Position = Vector3.new(xPos, 1 + OBSTACLE_HEIGHT_LOW / 2, zPos),
				Color = Color3.fromRGB(255, 120, 90),
				Material = Enum.Material.Neon,
			})
			wall.Parent = folder
		else
			-- palang tinggi dengan celah di bawah: harus DI-DASH (menunduk)
			local bar = makePart({
				Name = "Obstacle_High",
				Size = Vector3.new(GameConfig.LaneWidth / 2.5, 2, 2),
				Position = Vector3.new(xPos, 1 + OBSTACLE_HEIGHT_HIGH, zPos),
				Color = Color3.fromRGB(180, 120, 255),
				Material = Enum.Material.Neon,
			})
			bar.Parent = folder
		end

		placed += 1
	end

	folder.Parent = workspace
	print(("[OBC] Track dibangun: %d rintangan sepanjang %d studs"):format(placed, TRACK_LENGTH))
	return folder
end

return TrackBuilder
