--[[
	TrackStreamer.lua
	Membangun jalan ENDLESS di atas awan secara lokal di depan pemain
	dan menghapus bagian di belakang.

	Rintangan (warna lembut, mudah dibaca):
	  Peti kayu        -> lompat
	  Pagar tanaman    -> lompat
	  Jurang           -> lompat (panjang: lompat + dash), ditandai bendera
	  Balok batu       -> turun-naik, lewat saat di atas

	Hitbox rintangan terpisah dari visual (sedikit lebih kecil = adil)
	dan disimpan di folder Hazards untuk deteksi tabrakan.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrackGenerator = require(Shared:WaitForChild("TrackGenerator"))
local Locale = require(Shared:WaitForChild("Locale"))

local TrackStreamer = {}
TrackStreamer.__index = TrackStreamer

local BUCKET = 60
local TILE = 10
local Y = GameConfig.TrackY
local W = GameConfig.TrackWidth
local C = GameConfig.Colors
local SMOOTH = Enum.Material.SmoothPlastic
local WOOD = Enum.Material.Wood

local CRUSH_PERIOD = 2.4
local CRUSH_UP = 9.5
local CRUSH_FRAME_Y = Y + CRUSH_UP + 12

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = SMOOTH
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

-- part berbentuk elips (bola yang bisa dipipihkan)
local function blob(props)
	local p = part(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
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

function TrackStreamer.new(seed: number, lowDetail: boolean?)
	local self = setmetatable({}, TrackStreamer)
	self._gen = TrackGenerator.new(seed)
	self._decoRng = Random.new(seed + 7919)
	self._low = lowDetail == true
	self._view = if self._low then GameConfig.ViewDistanceLow else GameConfig.ViewDistance
	self._buckets = {}
	self._cleanedBucket = -2
	self._floorTo = 0
	self._decorTo = -BUCKET
	self._groups = {}
	self._animated = {}

	self.model = Instance.new("Folder")
	self.model.Name = "OBC_LocalTrack"
	self.hazardFolder = Instance.new("Folder")
	self.hazardFolder.Name = "Hazards"
	self.hazardFolder.Parent = self.model

	-- lautan awan di bawah, ikut bergerak bersama pemain
	self.cloudSea = part({
		Name = "CloudSea",
		Size = Vector3.new(2048, 2, 2048),
		CFrame = CFrame.new(0, Y - 62, -600),
		Color = C.Cloud,
		Parent = self.model,
	})
	self.cloudSeaHaze = part({
		Name = "CloudSeaHaze",
		Size = Vector3.new(2048, 1, 2048),
		CFrame = CFrame.new(0, Y - 52, -600),
		Color = C.CloudShade,
		Transparency = 0.55,
		Parent = self.model,
	})

	self.model.Parent = Workspace
	return self
end

-- Simpan instance ke bucket (dihapus saat sudah lewat) dan opsional ke grup rintangan
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
	bb.AutoLocalize = false
	bb.Size = UDim2.fromOffset(300, 60)
	bb.LightInfluence = 0
	bb.MaxDistance = 240
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.AutoLocalize = false
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.Parent = bb
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = Color3.fromRGB(70, 60, 60)
	s.Transparency = 0.3
	s.Parent = t
	self:_track(anchor, endD, group)
end

-- ================= JALAN =================

function TrackStreamer:_tile(s: number, e: number, endKey: number)
	local len = e - s
	local mid = (s + e) / 2
	local colorIndex = math.floor((s + 0.01) / TILE) % 2
	self:_track(
		part({
			Name = "Path",
			Size = Vector3.new(W, 1.6, len),
			CFrame = CFrame.new(0, Y - 0.8, -mid),
			Color = if colorIndex == 0 then C.PathA else C.PathB,
			CanCollide = true,
			CanQuery = true,
			CastShadow = false,
		}),
		endKey
	)
end

function TrackStreamer:_floorPiece(s: number, e: number)
	local len = e - s
	local mid = (s + e) / 2

	-- ubin batu bergantian warna tiap 10 studs
	local t = s
	while e - t > 0.05 do
		local nextT = math.min(e, (math.floor((t + 0.01) / TILE) + 1) * TILE)
		self:_tile(t, nextT, e)
		t = nextT
	end

	-- sisi bawah (batu) memberi kesan jalan melayang
	self:_track(
		part({
			Name = "Underside",
			Size = Vector3.new(W - 1.2, 2.4, len),
			CFrame = CFrame.new(0, Y - 2.8, -mid),
			Color = C.Rock,
		}),
		e
	)

	for _, side in ipairs({ -1, 1 }) do
		-- batu tepi
		self:_track(
			part({
				Name = "Curb",
				Size = Vector3.new(0.7, 0.35, len),
				CFrame = CFrame.new(side * (W / 2 - 0.35), Y + 0.17, -mid),
				Color = C.PathEdge,
			}),
			e
		)
		-- tali pagar
		if len > 2 then
			self:_track(
				part({
					Name = "Rope",
					Size = Vector3.new(0.14, 0.14, len),
					CFrame = CFrame.new(side * (W / 2 - 0.35), Y + 1.9, -mid),
					Color = C.Rope,
				}),
				e
			)
		end
	end

	-- tiang pagar tiap 12 studs, lentera tiap 48 studs
	local post = math.ceil(s / 12) * 12
	while post <= e - 0.5 do
		for _, side in ipairs({ -1, 1 }) do
			local isLantern = post % 48 == 0 and ((post / 48) % 2 == 0) == (side == 1)
			local h = if isLantern then 4.2 else 2.3
			self:_track(
				part({
					Name = "FencePost",
					Size = Vector3.new(0.45, h, 0.45),
					CFrame = CFrame.new(side * (W / 2 - 0.35), Y + h / 2, -post),
					Color = C.WoodDark,
					Material = WOOD,
				}),
				e
			)
			if isLantern then
				local lamp = self:_track(
					part({
						Name = "Lantern",
						Size = Vector3.new(0.8, 0.9, 0.8),
						CFrame = CFrame.new(side * (W / 2 - 0.35), Y + 4.6, -post),
						Color = Color3.fromRGB(255, 214, 150),
						Material = Enum.Material.Neon,
						Transparency = 0.15,
					}),
					e
				)
				self:_track(
					part({
						Name = "LanternCap",
						Size = Vector3.new(1, 0.25, 1),
						CFrame = CFrame.new(side * (W / 2 - 0.35), Y + 5.15, -post),
						Color = C.WoodDark,
					}),
					e
				)
				if not self._low then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 205, 150)
					light.Range = 14
					light.Brightness = 0.7
					light.Shadows = false
					light.Parent = lamp
				end
			end
		end
		post += 12
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
end

-- ================= RINTANGAN =================

function TrackStreamer:_buildGap(f)
	local endD = f.z + f.length + 1
	local group = self:_newGroup(f.z, f.z + f.length)

	-- garis amber lembut di kedua bibir jurang
	for _, d in ipairs({ f.z - 0.5, f.z + f.length + 0.5 }) do
		self:_track(
			part({
				Name = "GapLip",
				Size = Vector3.new(W, 0.12, 1),
				CFrame = CFrame.new(0, Y + 0.06, -d),
				Color = C.Warning,
			}),
			endD,
			group
		)
	end

	-- tiang bendera di kedua sisi sebelum jurang
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (W / 2 + 0.6)
		local d = f.z - 1.5
		self:_track(
			part({
				Name = "FlagPole",
				Size = Vector3.new(0.3, 5, 0.3),
				CFrame = CFrame.new(x, Y + 2.5, -d),
				Color = C.WoodDark,
				Material = WOOD,
			}),
			endD,
			group
		)
		self:_track(
			part({
				Name = "Flag",
				Size = Vector3.new(0.08, 1.3, 1.8),
				CFrame = CFrame.new(x, Y + 4.2, -(d - 0.9)),
				Color = C.Warning,
			}),
			endD,
			group
		)
	end

	-- batu-batu kecil yang "patah" melayang di bawah bibir jurang
	local rng = self._decoRng
	for _ = 1, if self._low then 1 else 3 do
		local d = f.z + rng:NextNumber(0, f.length)
		local s = rng:NextNumber(0.8, 1.8)
		self:_track(
			part({
				Name = "Debris",
				Size = Vector3.new(s, s * 0.7, s),
				CFrame = CFrame.new(rng:NextNumber(-W / 2, W / 2), Y - rng:NextNumber(4, 10), -d)
					* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0),
				Color = C.Rock,
			}),
			endD,
			group
		)
	end

	local mid = f.z + f.length / 2
	if f.long and f.z < GameConfig.TutorialUntil * 1.6 then
		self:_label(mid, Locale.Get("jump_dash"), Color3.fromRGB(235, 245, 255), endD, group)
	elseif not f.long and f.z < GameConfig.TutorialUntil then
		self:_label(mid, Locale.Get("jump"), Color3.fromRGB(255, 244, 225), endD, group)
	end
end

-- Peti kayu (dipakai untuk fitur "Wall")
function TrackStreamer:_buildCrates(f)
	local len = f.length
	local endD = f.z + len
	local cz = -(f.z + len / 2)
	local group = self:_newGroup(f.z, endD)
	local crateW = (W - 0.6) / 3
	local h = 3.2

	for i = -1, 1 do
		local x = i * (crateW + 0.15)
		local tint = C.Wood:Lerp(C.WoodDark, (i + 1) * 0.12)
		self:_track(
			part({
				Name = "Crate",
				Size = Vector3.new(crateW, h, len),
				CFrame = CFrame.new(x, Y + h / 2, cz),
				Color = tint,
				Material = WOOD,
				CastShadow = true,
			}),
			endD,
			group
		)
		-- bingkai atas & bawah
		for _, yy in ipairs({ 0.25, h - 0.25 }) do
			self:_track(
				part({
					Name = "CrateBand",
					Size = Vector3.new(crateW + 0.06, 0.4, len + 0.12),
					CFrame = CFrame.new(x, Y + yy, cz),
					Color = C.WoodDark,
					Material = WOOD,
				}),
				endD,
				group
			)
		end
		-- papan silang di sisi depan
		self:_track(
			part({
				Name = "CratePlank",
				Size = Vector3.new(0.35, h * 1.05, 0.12),
				CFrame = CFrame.new(x, Y + h / 2, cz + len / 2 + 0.04) * CFrame.Angles(0, 0, math.atan(crateW / h)),
				Color = C.WoodDark,
				Material = WOOD,
			}),
			endD,
			group
		)
	end

	self:_hazard(Vector3.new(W, 3.0, len - 0.4), CFrame.new(0, Y + 1.5, cz), endD, group)
	if f.z < 400 then
		self:_label(f.z, Locale.Get("jump"), Color3.fromRGB(255, 244, 225), endD, group)
	end
end

-- Pagar tanaman (dipakai untuk fitur "Laser")
function TrackStreamer:_buildHedge(f)
	local len = math.max(f.length, 2)
	local endD = f.z + len
	local cz = -(f.z + len / 2)
	local group = self:_newGroup(f.z, endD)

	self:_track(
		part({
			Name = "HedgeBody",
			Size = Vector3.new(W, 2.4, len),
			CFrame = CFrame.new(0, Y + 1.2, cz),
			Color = C.GrassDark,
			CastShadow = true,
		}),
		endD,
		group
	)
	local rng = self._decoRng
	local bumps = if self._low then 4 else 6
	for i = 0, bumps - 1 do
		local x = -W / 2 + (i + 0.5) * (W / bumps)
		local bump = blob({
			Name = "HedgeBump",
			Size = Vector3.new(W / bumps + 1.2, 1.8, len + 0.8),
			CFrame = CFrame.new(x, Y + 2.5 + rng:NextNumber(-0.1, 0.15), cz),
			Color = if i % 2 == 0 then C.Leaf else C.LeafLight,
		})
		self:_track(bump, endD, group)
	end
	-- bunga kecil
	if not self._low then
		for i = 1, 5 do
			self:_track(
				blob({
					Name = "Flower",
					Size = Vector3.new(0.55, 0.55, 0.55),
					CFrame = CFrame.new(rng:NextNumber(-W / 2 + 1, W / 2 - 1), Y + 3.25, cz + len / 2 + 0.2),
					Color = C.Flags[(i % #C.Flags) + 1],
				}),
				endD,
				group
			)
		end
	end

	self:_hazard(Vector3.new(W, 3.0, len), CFrame.new(0, Y + 1.5, cz), endD, group)
end

-- Balok batu yang menghantam (fitur "Crusher")
function TrackStreamer:_buildCrusher(f)
	local endD = f.z + f.length
	local cz = -(f.z + f.length / 2)
	local group = self:_newGroup(f.z, endD)

	-- rangka kayu
	for _, side in ipairs({ -1, 1 }) do
		self:_track(
			part({
				Name = "CrusherPost",
				Size = Vector3.new(1.3, CRUSH_FRAME_Y - Y, 1.3),
				CFrame = CFrame.new(side * (W / 2 + 1.4), (Y + CRUSH_FRAME_Y) / 2, cz),
				Color = C.WoodDark,
				Material = WOOD,
				CastShadow = true,
			}),
			endD,
			group
		)
	end
	self:_track(
		part({
			Name = "CrusherBeam",
			Size = Vector3.new(W + 4.2, 1.3, 1.6),
			CFrame = CFrame.new(0, CRUSH_FRAME_Y, cz),
			Color = C.Wood,
			Material = WOOD,
			CastShadow = true,
		}),
		endD,
		group
	)

	local block = self:_track(
		part({
			Name = "CrusherBlock",
			Size = Vector3.new(W + 0.6, 6, f.length),
			CFrame = CFrame.new(0, Y + CRUSH_UP + 3, cz),
			Color = C.Stone,
			Material = Enum.Material.Slate,
			CastShadow = true,
		}),
		endD,
		group
	)
	local trim = self:_track(
		part({
			Name = "CrusherTrim",
			Size = Vector3.new(W + 0.7, 0.6, f.length + 0.1),
			CFrame = CFrame.new(0, Y + CRUSH_UP + 0.3, cz),
			Color = C.StoneTrim,
		}),
		endD,
		group
	)
	local ropes = {}
	for _, x in ipairs({ -W / 3, W / 3 }) do
		table.insert(
			ropes,
			self:_track(
				part({
					Name = "CrusherRope",
					Size = Vector3.new(0.25, 1, 0.25),
					CFrame = CFrame.new(x, CRUSH_FRAME_Y, cz),
					Color = C.Rope,
				}),
				endD,
				group
			)
		)
	end
	-- bayangan di lantai: makin gelap saat balok turun
	local shadow = self:_track(
		part({
			Name = "CrusherShadow",
			Size = Vector3.new(W - 0.4, 0.05, f.length),
			CFrame = CFrame.new(0, Y + 0.03, cz),
			Color = Color3.fromRGB(90, 80, 80),
			Transparency = 0.8,
		}),
		endD,
		group
	)

	local hitbox =
		self:_hazard(Vector3.new(W, 5.6, f.length - 0.6), CFrame.new(0, Y + CRUSH_UP + 3, cz), endD, group)
	table.insert(self._animated, {
		kind = "Crusher",
		block = block,
		trim = trim,
		ropes = ropes,
		shadow = shadow,
		hitbox = hitbox,
		cz = cz,
		phase = f.phase or 0,
	})
end

-- ================= DEKORASI LANGIT =================

function TrackStreamer:_cloud(center: Vector3, scale: number, endD: number)
	local rng = self._decoRng
	local puffs = if self._low then 2 else rng:NextInteger(3, 5)
	for i = 1, puffs do
		local s = scale * rng:NextNumber(0.6, 1)
		local offset = Vector3.new((i - puffs / 2) * scale * 0.55, rng:NextNumber(-0.15, 0.25) * scale, rng:NextNumber(-0.3, 0.3) * scale)
		self:_track(
			blob({
				Name = "Cloud",
				Size = Vector3.new(s * 1.3, s * 0.65, s),
				CFrame = CFrame.new(center + offset),
				Color = if i % 2 == 0 then C.CloudShade else C.Cloud,
			}),
			endD
		)
	end
end

function TrackStreamer:_island(center: Vector3, scale: number, endD: number)
	local rng = self._decoRng
	local s = scale
	self:_track(
		part({
			Name = "IslandGrass",
			Size = Vector3.new(10, 1.6, 10) * s,
			CFrame = CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = C.Grass,
		}),
		endD
	)
	self:_track(
		part({
			Name = "IslandRock",
			Size = Vector3.new(8.5, 4, 8.5) * s,
			CFrame = CFrame.new(center - Vector3.new(0, 2.8 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = C.Rock,
		}),
		endD
	)
	self:_track(
		part({
			Name = "IslandTip",
			Size = Vector3.new(4.5, 4, 4.5) * s,
			CFrame = CFrame.new(center - Vector3.new(0, 6.4 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = C.RockDark,
		}),
		endD
	)
	if rng:NextNumber() < 0.75 then
		local tx = center + Vector3.new(rng:NextNumber(-2, 2) * s, 0, rng:NextNumber(-2, 2) * s)
		self:_track(
			part({
				Name = "Trunk",
				Size = Vector3.new(0.9, 4.5, 0.9) * s,
				CFrame = CFrame.new(tx + Vector3.new(0, 3 * s, 0)),
				Color = C.WoodDark,
			}),
			endD
		)
		self:_track(
			blob({
				Name = "Leaves",
				Size = Vector3.new(5.5, 5, 5.5) * s,
				CFrame = CFrame.new(tx + Vector3.new(0, 6.6 * s, 0)),
				Color = if rng:NextNumber() < 0.5 then C.Leaf else C.LeafLight,
			}),
			endD
		)
	end
end

function TrackStreamer:_balloon(center: Vector3, endD: number)
	local rng = self._decoRng
	local color = C.Balloon[rng:NextInteger(1, #C.Balloon)]
	local env = self:_track(
		blob({
			Name = "Balloon",
			Size = Vector3.new(11, 13, 11),
			CFrame = CFrame.new(center),
			Color = color,
		}),
		endD
	)
	local band = self:_track(
		blob({
			Name = "BalloonBand",
			Size = Vector3.new(11.3, 3, 11.3),
			CFrame = CFrame.new(center + Vector3.new(0, 1, 0)),
			Color = C.Cloud,
		}),
		endD
	)
	local basket = self:_track(
		part({
			Name = "Basket",
			Size = Vector3.new(2.6, 2, 2.6),
			CFrame = CFrame.new(center - Vector3.new(0, 9.5, 0)),
			Color = C.Wood,
			Material = WOOD,
		}),
		endD
	)
	table.insert(self._animated, {
		kind = "Balloon",
		parts = { env, band, basket },
		base = { env.CFrame, band.CFrame, basket.CFrame },
		phase = rng:NextNumber(0, 6.28),
	})
end

function TrackStreamer:_buildDecor(from: number, to: number)
	local rng = self._decoRng
	local low = self._low

	-- awan di kiri & kanan, berbagai jarak
	for _, side in ipairs({ -1, 1 }) do
		for _ = 1, if low then 1 else 2 do
			local d = rng:NextNumber(from, to)
			local x = side * rng:NextNumber(28, 140)
			local y = Y + rng:NextNumber(-30, 30)
			self:_cloud(Vector3.new(x, y, -d), rng:NextNumber(8, 20), to)
		end
	end
	-- awan kecil di bawah jalan
	if not low or rng:NextNumber() < 0.5 then
		self:_cloud(Vector3.new(rng:NextNumber(-20, 20), Y - rng:NextNumber(16, 34), -rng:NextNumber(from, to)), rng:NextNumber(7, 12), to)
	end
	-- pulau melayang
	if rng:NextNumber() < (if low then 0.35 else 0.6) then
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		self:_island(
			Vector3.new(side * rng:NextNumber(34, 110), Y + rng:NextNumber(-22, 18), -rng:NextNumber(from, to)),
			rng:NextNumber(0.8, 1.8),
			to
		)
	end
	-- balon udara
	if not low and rng:NextNumber() < 0.18 then
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		self:_balloon(Vector3.new(side * rng:NextNumber(45, 120), Y + rng:NextNumber(10, 45), -rng:NextNumber(from, to)), to)
	end
end

-- ================= LOOP =================

function TrackStreamer:Update(playerD: number)
	local ahead = playerD + self._view
	while self._gen.cursor < ahead do
		local features = self._gen:Next()
		for _, f in ipairs(features) do
			if f.kind == "Gap" then
				self:_buildFloor(self._floorTo, f.z)
				self:_buildGap(f)
				self._floorTo = f.z + f.length
			elseif f.kind == "Wall" then
				self:_buildCrates(f)
			elseif f.kind == "Laser" then
				self:_buildHedge(f)
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

	-- lautan awan ikut pemain
	local seaZ = -(playerD + 500)
	self.cloudSea.CFrame = CFrame.new(0, Y - 62, seaZ)
	self.cloudSeaHaze.CFrame = CFrame.new(0, Y - 52, seaZ)

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

	-- buang grup rintangan yang sudah terhapus
	for i = #self._groups, 1, -1 do
		local g = self._groups[i]
		if g.to < playerD - GameConfig.CleanupBehind - BUCKET then
			table.remove(self._groups, i)
		end
	end
end

-- Animasi balok batu & balon (dipanggil tiap frame)
function TrackStreamer:Animate(t: number)
	for i = #self._animated, 1, -1 do
		local a = self._animated[i]
		if a.kind == "Crusher" then
			if not a.block.Parent then
				table.remove(self._animated, i)
			else
				local u = ((t / CRUSH_PERIOD) + a.phase) % 1
				local lift = crusherLift(u)
				local blockCF = CFrame.new(0, Y + lift + 3, a.cz)
				a.block.CFrame = blockCF
				a.hitbox.CFrame = blockCF
				a.trim.CFrame = CFrame.new(0, Y + lift + 0.3, a.cz)
				local ropeBottom = Y + lift + 6
				local ropeLen = math.max(CRUSH_FRAME_Y - ropeBottom, 0.2)
				for _, rope in ipairs(a.ropes) do
					rope.Size = Vector3.new(0.25, ropeLen, 0.25)
					rope.CFrame = CFrame.new(rope.Position.X, ropeBottom + ropeLen / 2, a.cz)
				end
				a.shadow.Transparency = 0.45 + 0.45 * (lift / CRUSH_UP)
			end
		elseif a.kind == "Balloon" then
			if not a.parts[1].Parent then
				table.remove(self._animated, i)
			else
				local bob = CFrame.new(0, math.sin(t * 0.6 + a.phase) * 1.5, 0)
				for j, p in ipairs(a.parts) do
					p.CFrame = bob * a.base[j]
				end
			end
		end
	end
end

-- Siapkan posisi aman untuk revive: hapus rintangan terdekat + pasang jembatan kayu
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

	self:_track(
		part({
			Name = "ReviveBridge",
			Size = Vector3.new(W, 0.8, to - from),
			CFrame = CFrame.new(0, Y - 0.4, -((from + to) / 2)),
			Color = C.Wood,
			Material = WOOD,
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
