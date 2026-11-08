--[[
	TrackStreamer.lua
	Membangun lintasan ENDLESS secara lokal di depan pemain dan menghapus
	bagian di belakang. Semua visual (lantai neon, rel, gedung, gerbang,
	grid synthwave) dan rintangan dibuat di sini.

	Hitbox rintangan dipisah dari visualnya (sedikit lebih kecil = adil)
	dan ditaruh di folder Hazards untuk deteksi tabrakan.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrackGenerator = require(Shared:WaitForChild("TrackGenerator"))

local TrackStreamer = {}
TrackStreamer.__index = TrackStreamer

local BUCKET = 60
local Y = GameConfig.TrackY
local W = GameConfig.TrackWidth
local NEON = Enum.Material.Neon

local CRUSH_PERIOD = 2.4
local CRUSH_UP = 9.5

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

local function crusherLift(u: number): number
	if u < 0.45 then
		return CRUSH_UP
	elseif u < 0.53 then
		local k = (u - 0.45) / 0.08
		return CRUSH_UP * (1 - k * k) -- menghantam ke bawah
	elseif u < 0.78 then
		return 0
	end
	local k = (u - 0.78) / 0.22
	return CRUSH_UP * (k * k * (3 - 2 * k)) -- naik perlahan
end

function TrackStreamer.new(seed: number)
	local self = setmetatable({}, TrackStreamer)
	self._gen = TrackGenerator.new(seed)
	self._decoRng = Random.new(seed + 7919)
	self._buckets = {}
	self._cleanedBucket = -2
	self._floorTo = 0
	self._decorTo = -BUCKET
	self._floorRanges = {}
	self._groups = {}
	self._animated = {}

	self.model = Instance.new("Folder")
	self.model.Name = "OBC_LocalTrack"
	self.hazardFolder = Instance.new("Folder")
	self.hazardFolder.Name = "Hazards"
	self.hazardFolder.Parent = self.model
	self.model.Parent = Workspace
	return self
end

-- Simpan instance ke bucket (untuk dihapus nanti) dan opsional ke grup rintangan
function TrackStreamer:_track(inst: Instance, endD: number, group)
	local key = math.floor(endD / BUCKET)
	local bucket = self._buckets[key]
	if not bucket then
		bucket = {}
		self._buckets[key] = bucket
	end
	table.insert(bucket, inst)
	if group then
		table.insert(group.insts, inst)
	end
	if not inst.Parent then
		inst.Parent = self.model
	end
	return inst
end

function TrackStreamer:_newGroup(from: number, to: number)
	local group = { from = from, to = to, insts = {} }
	table.insert(self._groups, group)
	return group
end

function TrackStreamer:_hazard(size: Vector3, cf: CFrame, endD: number, group)
	local hb = part({
		Name = "Hitbox",
		Size = size,
		CFrame = cf,
		Transparency = 1,
		CanQuery = true,
	})
	hb.Parent = self.hazardFolder
	return self:_track(hb, endD, group)
end

function TrackStreamer:_label(d: number, text: string, color: Color3, endD: number, group)
	local anchor = part({
		Name = "Hint",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CFrame = CFrame.new(0, Y + 7.5, -d),
	})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(280, 64)
	bb.LightInfluence = 0
	bb.MaxDistance = 260
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.Parent = bb
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.new(0, 0, 0)
	s.Parent = t
	self:_track(anchor, endD, group)
end

-- ================= LANTAI =================

function TrackStreamer:_floorPiece(s: number, e: number)
	local len = e - s
	local mid = (s + e) / 2
	local pal = GameConfig.GetPalette(mid)

	self:_track(
		part({
			Name = "Floor",
			Size = Vector3.new(W, 4, len),
			CFrame = CFrame.new(0, Y - 2, -mid),
			Color = pal.Floor,
			Reflectance = 0.12,
			CanCollide = true,
			CanQuery = true,
		}),
		e
	)

	for _, side in ipairs({ -1, 1 }) do
		self:_track(
			part({
				Name = "Rail",
				Size = Vector3.new(0.5, 0.7, len),
				CFrame = CFrame.new(side * (W / 2 + 0.25), Y + 0.15, -mid),
				Color = pal.Primary,
				Material = NEON,
			}),
			e
		)
		self:_track(
			part({
				Name = "Skirt",
				Size = Vector3.new(0.3, 3.6, len),
				CFrame = CFrame.new(side * (W / 2 + 0.15), Y - 2.2, -mid),
				Color = pal.Secondary,
				Material = NEON,
				Transparency = 0.55,
			}),
			e
		)
	end

	-- garis tengah
	self:_track(
		part({
			Name = "CenterLine",
			Size = Vector3.new(0.25, 0.06, len),
			CFrame = CFrame.new(0, Y + 0.03, -mid),
			Color = pal.Secondary,
			Material = NEON,
			Transparency = 0.5,
		}),
		e
	)

	-- garis grid melintang tiap 10 studs (memberi kesan kecepatan)
	local g = math.ceil(s / 10) * 10
	while g < e do
		self:_track(
			part({
				Name = "Grid",
				Size = Vector3.new(W - 0.4, 0.06, 0.3),
				CFrame = CFrame.new(0, Y + 0.03, -g),
				Color = pal.Primary,
				Material = NEON,
				Transparency = 0.6,
			}),
			e
		)
		g += 10
	end
end

function TrackStreamer:_buildFloor(from: number, to: number)
	if to - from < 0.05 then
		return
	end
	local s = from
	while to - s > 0.05 do
		local boundary = (math.floor(s / BUCKET) + 1) * BUCKET
		local e = math.min(to, boundary)
		self:_floorPiece(s, e)
		s = e
	end
	table.insert(self._floorRanges, { from = from, to = to })
end

-- ================= RINTANGAN =================

function TrackStreamer:_buildGap(f)
	local endD = f.z + f.length + 1
	local group = self:_newGroup(f.z, f.z + f.length)

	-- garis kuning di kedua bibir jurang
	for _, info in ipairs({ { f.z - 0.4 }, { f.z + f.length + 0.4 } }) do
		self:_track(
			part({
				Name = "GapLip",
				Size = Vector3.new(W, 0.12, 0.8),
				CFrame = CFrame.new(0, Y + 0.06, -info[1]),
				Color = GameConfig.GapColor,
				Material = NEON,
			}),
			endD,
			group
		)
	end
	-- garis peringatan sebelum jurang
	for i, back in ipairs({ 4, 7.5 }) do
		self:_track(
			part({
				Name = "GapWarn",
				Size = Vector3.new(W * 0.7, 0.08, 0.5),
				CFrame = CFrame.new(0, Y + 0.04, -(f.z - back)),
				Color = GameConfig.GapColor,
				Material = NEON,
				Transparency = 0.25 + i * 0.2,
			}),
			endD,
			group
		)
	end

	local mid = f.z + f.length / 2
	if f.long and f.z < GameConfig.TutorialUntil * 1.6 then
		self:_label(mid, "LOMPAT + DASH ⚡", Color3.fromRGB(120, 230, 255), endD, group)
	elseif not f.long and f.z < GameConfig.TutorialUntil then
		self:_label(mid, "LOMPAT ⬆", GameConfig.GapColor, endD, group)
	end
end

function TrackStreamer:_buildWall(f)
	local len = f.length
	local endD = f.z + len
	local cz = -(f.z + len / 2)
	local group = self:_newGroup(f.z, endD)
	local hazard = GameConfig.HazardColor

	self:_track(
		part({
			Name = "WallBody",
			Size = Vector3.new(W, 3.2, len),
			CFrame = CFrame.new(0, Y + 1.6, cz),
			Color = Color3.fromRGB(28, 10, 24),
		}),
		endD,
		group
	)
	local top = self:_track(
		part({
			Name = "WallTop",
			Size = Vector3.new(W + 0.2, 0.5, len + 0.2),
			CFrame = CFrame.new(0, Y + 3.45, cz),
			Color = hazard,
			Material = NEON,
		}),
		endD,
		group
	)
	local light = Instance.new("PointLight")
	light.Color = hazard
	light.Range = 14
	light.Brightness = 3
	light.Parent = top

	-- garis miring ala tanda bahaya
	for i = -2, 2 do
		self:_track(
			part({
				Name = "WallStripe",
				Size = Vector3.new(0.35, 2.6, len + 0.1),
				CFrame = CFrame.new(i * (W / 5), Y + 1.55, cz) * CFrame.Angles(0, 0, math.rad(25)),
				Color = hazard,
				Material = NEON,
				Transparency = 0.15,
			}),
			endD,
			group
		)
	end

	self:_hazard(Vector3.new(W, 3.0, len - 0.4), CFrame.new(0, Y + 1.5, cz), endD, group)
	if f.z < 400 then
		self:_label(f.z, "LOMPAT ⬆", Color3.fromRGB(255, 255, 255), endD, group)
	end
end

function TrackStreamer:_buildLaser(f)
	local endD = f.z + f.length
	local cz = -(f.z + f.length / 2)
	local group = self:_newGroup(f.z, endD)
	local red = Color3.fromRGB(255, 30, 60)

	for _, side in ipairs({ -1, 1 }) do
		self:_track(
			part({
				Name = "LaserPost",
				Size = Vector3.new(1, 4.2, 1),
				CFrame = CFrame.new(side * (W / 2 + 0.5), Y + 2.1, cz),
				Color = Color3.fromRGB(35, 35, 45),
				Material = Enum.Material.Metal,
			}),
			endD,
			group
		)
		self:_track(
			part({
				Name = "LaserCap",
				Size = Vector3.new(1.1, 0.3, 1.1),
				CFrame = CFrame.new(side * (W / 2 + 0.5), Y + 4.35, cz),
				Color = red,
				Material = NEON,
			}),
			endD,
			group
		)
	end

	local beams = {}
	for _, h in ipairs({ 0.9, 2.1, 3.3 }) do
		local beam = self:_track(
			part({
				Name = "LaserBeam",
				Size = Vector3.new(W + 0.6, 0.22, 0.22),
				CFrame = CFrame.new(0, Y + h, cz),
				Color = red,
				Material = NEON,
			}),
			endD,
			group
		)
		self:_track(
			part({
				Name = "LaserGlow",
				Size = Vector3.new(W, 0.6, 0.6),
				CFrame = CFrame.new(0, Y + h, cz),
				Color = red,
				Material = NEON,
				Transparency = 0.8,
			}),
			endD,
			group
		)
		table.insert(beams, beam)
	end
	table.insert(self._animated, { kind = "Laser", beams = beams })

	self:_hazard(Vector3.new(W, 3.2, 1.4), CFrame.new(0, Y + 1.9, cz), endD, group)
end

function TrackStreamer:_buildCrusher(f)
	local endD = f.z + f.length
	local cz = -(f.z + f.length / 2)
	local group = self:_newGroup(f.z, endD)
	local orange = GameConfig.CrusherColor

	local block = self:_track(
		part({
			Name = "CrusherBlock",
			Size = Vector3.new(W + 1, 6, f.length),
			CFrame = CFrame.new(0, Y + CRUSH_UP + 3, cz),
			Color = Color3.fromRGB(40, 40, 52),
			Material = Enum.Material.DiamondPlate,
		}),
		endD,
		group
	)
	local stripe = self:_track(
		part({
			Name = "CrusherEdge",
			Size = Vector3.new(W + 1.1, 0.5, f.length + 0.1),
			CFrame = CFrame.new(0, Y + CRUSH_UP + 0.25, cz),
			Color = orange,
			Material = NEON,
		}),
		endD,
		group
	)
	for _, side in ipairs({ -1, 1 }) do
		self:_track(
			part({
				Name = "CrusherPillar",
				Size = Vector3.new(1.4, 18, 1.4),
				CFrame = CFrame.new(side * (W / 2 + 1.6), Y + 9, cz),
				Color = Color3.fromRGB(30, 30, 38),
				Material = Enum.Material.Metal,
			}),
			endD,
			group
		)
		self:_track(
			part({
				Name = "CrusherPillarGlow",
				Size = Vector3.new(0.3, 18, 0.3),
				CFrame = CFrame.new(side * (W / 2 + 0.85), Y + 9, cz),
				Color = orange,
				Material = NEON,
			}),
			endD,
			group
		)
	end
	-- bayangan peringatan di lantai
	self:_track(
		part({
			Name = "CrusherWarn",
			Size = Vector3.new(W, 0.07, f.length + 1),
			CFrame = CFrame.new(0, Y + 0.04, cz),
			Color = orange,
			Material = NEON,
			Transparency = 0.55,
		}),
		endD,
		group
	)

	local hitbox = self:_hazard(
		Vector3.new(W, 5.6, f.length - 0.6),
		CFrame.new(0, Y + CRUSH_UP + 3, cz),
		endD,
		group
	)
	table.insert(self._animated, {
		kind = "Crusher",
		block = block,
		stripe = stripe,
		hitbox = hitbox,
		cz = cz,
		phase = f.phase or 0,
	})
end

-- ================= DEKORASI =================

function TrackStreamer:_buildDecor(from: number, to: number)
	local rng = self._decoRng
	local mid = (from + to) / 2
	local pal = GameConfig.GetPalette(math.max(mid, 0))

	-- gedung kota cyber di kiri & kanan
	for _, side in ipairs({ -1, 1 }) do
		for _ = 1, rng:NextInteger(1, 2) do
			local d = rng:NextNumber(from, to)
			local w = rng:NextNumber(8, 18)
			local depth = rng:NextNumber(8, 20)
			local h = rng:NextNumber(20, 110)
			local x = side * rng:NextNumber(26, 75)
			local height = h + 120
			self:_track(
				part({
					Name = "Building",
					Size = Vector3.new(w, height, depth),
					CFrame = CFrame.new(x, Y - 120 + height / 2, -d),
					Color = Color3.fromRGB(10, 10, 20),
				}),
				to
			)
			for b = 1, rng:NextInteger(2, 4) do
				self:_track(
					part({
						Name = "BuildingBand",
						Size = Vector3.new(w + 0.2, 0.35, depth + 0.2),
						CFrame = CFrame.new(x, Y + h - b * rng:NextNumber(6, 14), -d),
						Color = if rng:NextNumber() < 0.5 then pal.Primary else pal.Secondary,
						Material = NEON,
						Transparency = 0.15,
					}),
					to
				)
			end
			self:_track(
				part({
					Name = "BuildingCap",
					Size = Vector3.new(w + 0.3, 0.5, depth + 0.3),
					CFrame = CFrame.new(x, Y + h + 0.25, -d),
					Color = pal.Secondary,
					Material = NEON,
				}),
				to
			)
		end
	end

	-- gerbang neon tiap 120 studs
	if math.floor(from / BUCKET) % 2 == 0 then
		local ad = from + 30
		for _, side in ipairs({ -1, 1 }) do
			self:_track(
				part({
					Name = "ArchPillar",
					Size = Vector3.new(1.2, 15, 1.2),
					CFrame = CFrame.new(side * (W / 2 + 2.5), Y + 7.5, -ad),
					Color = pal.Primary,
					Material = NEON,
				}),
				to
			)
		end
		self:_track(
			part({
				Name = "ArchBeam",
				Size = Vector3.new(W + 6.2, 1, 1.2),
				CFrame = CFrame.new(0, Y + 15, -ad),
				Color = pal.Primary,
				Material = NEON,
			}),
			to
		)
	end

	-- grid synthwave jauh di bawah lintasan
	local gy = Y - 70
	for _, x in ipairs({ -160, -120, -80, -40, 40, 80, 120, 160 }) do
		self:_track(
			part({
				Name = "GroundLine",
				Size = Vector3.new(0.6, 0.6, to - from),
				CFrame = CFrame.new(x, gy, -mid),
				Color = pal.Secondary,
				Material = NEON,
				Transparency = 0.35,
			}),
			to
		)
	end
	for gd = from, to - 1, 30 do
		self:_track(
			part({
				Name = "GroundLine",
				Size = Vector3.new(360, 0.6, 0.6),
				CFrame = CFrame.new(0, gy, -gd),
				Color = pal.Secondary,
				Material = NEON,
				Transparency = 0.35,
			}),
			to
		)
	end
end

-- ================= LOOP =================

function TrackStreamer:Update(playerD: number)
	local ahead = playerD + GameConfig.ViewDistance
	while self._gen.cursor < ahead do
		local features = self._gen:Next()
		for _, f in ipairs(features) do
			if f.kind == "Gap" then
				self:_buildFloor(self._floorTo, f.z)
				self:_buildGap(f)
				self._floorTo = f.z + f.length
			elseif f.kind == "Wall" then
				self:_buildWall(f)
			elseif f.kind == "Laser" then
				self:_buildLaser(f)
			elseif f.kind == "Crusher" then
				self:_buildCrusher(f)
			end
		end
		self:_buildFloor(self._floorTo, self._gen.cursor)
		self._floorTo = math.max(self._floorTo, self._gen.cursor)
	end

	while self._decorTo < ahead do
		self:_buildDecor(self._decorTo, self._decorTo + BUCKET)
		self._decorTo += BUCKET
	end

	-- hapus bagian di belakang pemain
	local maxBucket = math.floor((playerD - GameConfig.CleanupBehind) / BUCKET) - 1
	for k = self._cleanedBucket, maxBucket do
		local bucket = self._buckets[k]
		if bucket then
			for _, inst in ipairs(bucket) do
				inst:Destroy()
			end
			self._buckets[k] = nil
		end
	end
	self._cleanedBucket = math.max(self._cleanedBucket, maxBucket + 1)
end

-- Animasi laser berkedip & crusher naik-turun (dipanggil tiap frame)
function TrackStreamer:Animate(t: number)
	for i = #self._animated, 1, -1 do
		local a = self._animated[i]
		if a.kind == "Crusher" then
			if not a.block.Parent then
				table.remove(self._animated, i)
			else
				local u = ((t / CRUSH_PERIOD) + a.phase) % 1
				local lift = crusherLift(u)
				a.block.CFrame = CFrame.new(0, Y + lift + 3, a.cz)
				a.stripe.CFrame = CFrame.new(0, Y + lift + 0.25, a.cz)
				a.hitbox.CFrame = CFrame.new(0, Y + lift + 3, a.cz)
			end
		elseif a.kind == "Laser" then
			if not a.beams[1].Parent then
				table.remove(self._animated, i)
			else
				for j, beam in ipairs(a.beams) do
					beam.Transparency = 0.1 + 0.12 * math.sin(t * 25 + j * 2)
				end
			end
		end
	end
end

-- Siapkan posisi aman untuk revive: hapus rintangan terdekat + pasang jembatan
function TrackStreamer:PrepareRevive(d: number): number
	local safeD = math.max(0, d - 4)
	local from, to = safeD - 6, safeD + 60

	for i = #self._groups, 1, -1 do
		local g = self._groups[i]
		if g.to >= from and g.from <= to then
			for _, inst in ipairs(g.insts) do
				inst:Destroy()
			end
			table.remove(self._groups, i)
		end
	end

	local pal = GameConfig.GetPalette(safeD)
	self:_track(
		part({
			Name = "ReviveBridge",
			Size = Vector3.new(W, 1, to - from),
			CFrame = CFrame.new(0, Y - 0.5, -((from + to) / 2)),
			Color = pal.Primary,
			Material = NEON,
			Transparency = 0.45,
			CanCollide = true,
			CanQuery = true,
		}),
		to
	)
	return safeD
end

function TrackStreamer:Destroy()
	self.model:Destroy()
	self._buckets = {}
	self._animated = {}
	self._groups = {}
end

return TrackStreamer
