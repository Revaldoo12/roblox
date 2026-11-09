--[[
	Ambience.lua
	Membuat dunia terasa hidup:
	  - Kawanan burung yang sesekali terbang melintas sambil mengepakkan sayap
	  - Serbuk bunga / kelopak melayang pelan di sekitar kamera
	    (di malam hari bercahaya lembut seperti kunang-kunang)
	Semua lokal di client. Di perangkat ringan jumlahnya dikurangi.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Ambience = {}
Ambience.__index = Ambience

local Y = GameConfig.TrackY
local BIRD_COLOR = Color3.fromRGB(70, 74, 92)
local BIRD_SPEED = 26
local FLOAT_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

function Ambience.new(lowDetail: boolean?)
	local self = setmetatable({}, Ambience)
	self._low = lowDetail == true
	self._rng = Random.new()
	self._flocks = {}
	self._nextFlock = os.clock() + 3

	self.folder = Instance.new("Folder")
	self.folder.Name = "OBC_Ambience"
	self.folder.Parent = Workspace

	local area = part({
		Name = "FloatArea",
		Size = Vector3.new(70, 26, 70),
		Transparency = 1,
		Parent = self.folder,
	})
	self.floatArea = area
	local kps = {}
	for i, c in ipairs(GameConfig.Colors.Flags) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#GameConfig.Colors.Flags - 1), c:Lerp(Color3.new(1, 1, 1), 0.4)))
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = FLOAT_TEXTURE
	e.Color = ColorSequence.new(kps)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, 0.22),
		NumberSequenceKeypoint.new(0.85, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.25)
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = if self._low then 4 else 10
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0.6, -0.4, 0)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.15
	e.LightInfluence = 0.6
	e.Parent = area
	self.floaters = e
	return self
end

-- night = 0..1 (1 = malam): serbuk jadi bercahaya
function Ambience:SetNight(night: number)
	self.floaters.LightEmission = 0.15 + 0.75 * night
	self.floaters.LightInfluence = 0.6 * (1 - night)
end

function Ambience:_spawnFlock(playerD: number)
	local rng = self._rng
	local dir = if rng:NextNumber() < 0.5 then 1 else -1
	local startX = -dir * rng:NextNumber(110, 150)
	local z = -(playerD + rng:NextNumber(90, 190))
	local y = Y + rng:NextNumber(14, 40)
	local count = if self._low then 3 else rng:NextInteger(3, 6)

	local flock = { birds = {}, dir = dir, born = os.clock() }
	for i = 1, count do
		-- formasi V
		local row = math.floor(i / 2)
		local sideSign = if i % 2 == 0 then 1 else -1
		local offset = Vector3.new(-dir * row * 3, rng:NextNumber(-0.6, 0.6), sideSign * row * 3)
		local scale = rng:NextNumber(0.8, 1.1)
		local body = part({
			Name = "Bird",
			Size = Vector3.new(1.3, 0.45, 0.5) * scale,
			Color = BIRD_COLOR,
			Parent = self.folder,
		})
		local wingL = part({ Name = "Wing", Size = Vector3.new(0.6, 0.08, 1.6) * scale, Color = BIRD_COLOR, Parent = self.folder })
		local wingR = part({ Name = "Wing", Size = Vector3.new(0.6, 0.08, 1.6) * scale, Color = BIRD_COLOR, Parent = self.folder })
		table.insert(flock.birds, {
			body = body,
			wingL = wingL,
			wingR = wingR,
			origin = Vector3.new(startX, y, z) + offset,
			phase = rng:NextNumber(0, 6.28),
			scale = scale,
		})
	end
	table.insert(self._flocks, flock)
end

function Ambience:Update(camCF: CFrame, playerD: number, active: boolean)
	local now = os.clock()
	self.floatArea.CFrame = CFrame.new(camCF.Position + camCF.LookVector * 24)

	if active and now >= self._nextFlock and #self._flocks < 2 then
		self:_spawnFlock(playerD)
		self._nextFlock = now + self._rng:NextNumber(7, 14) * (if self._low then 1.6 else 1)
	end

	for fi = #self._flocks, 1, -1 do
		local flock = self._flocks[fi]
		local age = now - flock.born
		local done = age > 12
		for _, b in ipairs(flock.birds) do
			if done then
				b.body:Destroy()
				b.wingL:Destroy()
				b.wingR:Destroy()
			else
				local pos = b.origin + Vector3.new(flock.dir * BIRD_SPEED * age, math.sin(age * 1.3 + b.phase) * 0.8, 0)
				-- badan menghadap arah terbang (sumbu X)
				local cf = CFrame.lookAt(pos, pos + Vector3.new(flock.dir, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0)
				local flap = math.sin(now * 11 + b.phase) * 0.7
				local s = b.scale
				b.body.CFrame = cf
				b.wingL.CFrame = cf * CFrame.new(0, 0, -0.2 * s) * CFrame.Angles(flap, 0, 0) * CFrame.new(0, 0, -0.8 * s)
				b.wingR.CFrame = cf * CFrame.new(0, 0, 0.2 * s) * CFrame.Angles(-flap, 0, 0) * CFrame.new(0, 0, 0.8 * s)
			end
		end
		if done then
			table.remove(self._flocks, fi)
		end
	end
end

function Ambience:ClearBirds()
	for _, flock in ipairs(self._flocks) do
		for _, b in ipairs(flock.birds) do
			b.body:Destroy()
			b.wingL:Destroy()
			b.wingR:Destroy()
		end
	end
	self._flocks = {}
end

return Ambience
