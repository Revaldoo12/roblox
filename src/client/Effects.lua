--[[
	Effects.lua
	Efek lembut bertema langit: suara, debu lompat/mendarat, kepulan awan saat
	dash, kepulan debu + pecahan batu saat menabrak, jejak angin tipis,
	dan garis angin saat ngebut. Bisa dibisukan lewat SetMuted.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local C = GameConfig.Colors

local Effects = {}
Effects.__index = Effects

local PUFF_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightEmission = 0
	e.LightInfluence = 1
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function pastelRainbow()
	local kps = {}
	for i = 0, 6 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.35, 1)))
	end
	return ColorSequence.new(kps)
end

function Effects.new(lowDetail: boolean?)
	local self = setmetatable({}, Effects)
	self._rng = Random.new()
	self._low = lowDetail == true
	self.accent = GameConfig.Zones[1].Accent
	self.rainbow = false
	self.muted = false

	self.sounds = {}
	for name, info in pairs(GameConfig.Sounds) do
		local s = Instance.new("Sound")
		s.Name = "OBC_" .. name
		s.SoundId = info.Id
		s.Volume = info.Volume
		s.Parent = SoundService
		self.sounds[name] = s
	end
	if GameConfig.MusicId ~= "" then
		local m = Instance.new("Sound")
		m.Name = "OBC_Music"
		m.SoundId = GameConfig.MusicId
		m.Volume = GameConfig.MusicVolume
		m.Looped = true
		m.Parent = SoundService
		m:Play()
		self.music = m
	end

	local fx = Instance.new("Part")
	fx.Name = "OBC_FX"
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.Transparency = 1
	fx.Size = Vector3.new(0.2, 0.2, 0.2)
	fx.Parent = Workspace
	self.fx = fx

	self.dust = emitter(fx, {
		Texture = PUFF_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(236, 226, 206)),
		Size = NumberSequence.new(0.8, 2.2),
		Transparency = NumberSequence.new(0.45, 1),
		Lifetime = NumberRange.new(0.35, 0.55),
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(80, 15),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -6, 0),
		Drag = 5,
		Rotation = NumberRange.new(0, 360),
	})
	self.puff = emitter(fx, {
		Texture = PUFF_TEXTURE,
		Color = ColorSequence.new(C.Cloud),
		Size = NumberSequence.new(1.6, 4),
		Transparency = NumberSequence.new(0.35, 1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(4, 12),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Back,
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
	})
	self.boom = emitter(fx, {
		Texture = PUFF_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(240, 232, 220), Color3.fromRGB(200, 190, 180)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(0.4, 5),
			NumberSequenceKeypoint.new(1, 6),
		}),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(6, 16),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
	})

	-- garis angin tipis di depan kamera
	local windPart = Instance.new("Part")
	windPart.Name = "OBC_Wind"
	windPart.Anchored = true
	windPart.CanCollide = false
	windPart.CanQuery = false
	windPart.CanTouch = false
	windPart.Transparency = 1
	windPart.Size = Vector3.new(40, 18, 4)
	windPart.Parent = Workspace
	self.windPart = windPart
	self.wind = emitter(windPart, {
		Enabled = true,
		Rate = 0,
		Size = NumberSequence.new(0.08),
		Squash = NumberSequence.new(3),
		Transparency = NumberSequence.new(0.7, 1),
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(60, 90),
		EmissionDirection = Enum.NormalId.Back,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		LightInfluence = 0,
	})
	self.running = false
	return self
end

function Effects:SetMuted(muted: boolean)
	self.muted = muted
	if self.music then
		self.music.Volume = if muted then 0 else GameConfig.MusicVolume
	end
end

function Effects:Play(name: string, pitch: number?)
	if self.muted then
		return
	end
	local s = self.sounds[name]
	if s then
		s.PlaybackSpeed = pitch or 1
		s:Play()
	end
end

function Effects:_emitAt(e: ParticleEmitter, pos: Vector3, count: number)
	self.fx.CFrame = CFrame.new(pos)
	e:Emit(if self._low then math.ceil(count * 0.6) else count)
end

function Effects:AttachCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	for _, name in ipairs({ "OBC_TrailTop", "OBC_TrailBottom", "OBC_Trail" }) do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "OBC_TrailTop"
	a0.Position = Vector3.new(0, 0.8, 0.6)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "OBC_TrailBottom"
	a1.Position = Vector3.new(0, -0.8, 0.6)
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "OBC_Trail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.16
	trail.MinLength = 0.1
	trail.LightEmission = 0
	trail.LightInfluence = 0.6
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.7, 1)
	trail.WidthScale = NumberSequence.new(0.6, 0.1)
	trail.Parent = root
	self.trail = trail

	-- debu tipis di kaki saat berlari
	local old = root:FindFirstChild("OBC_Feet")
	if old then
		old:Destroy()
	end
	local feet = Instance.new("Attachment")
	feet.Name = "OBC_Feet"
	feet.Position = Vector3.new(0, -2.9, 0.4)
	feet.Parent = root
	self.runDust = emitter(feet, {
		Enabled = true,
		Rate = 0,
		Texture = PUFF_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(236, 226, 206)),
		Size = NumberSequence.new(0.5, 1.6),
		Transparency = NumberSequence.new(0.6, 1),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Back,
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
	})
	self:_applyColors()
end

-- dipanggil tiap frame: debu hanya saat menapak tanah sambil berlari
function Effects:SetRunDust(onGround: boolean, speedRatio: number)
	if self.runDust then
		self.runDust.Rate = if onGround then (6 + speedRatio * 14) * (if self._low then 0.5 else 1) else 0
	end
end

function Effects:_applyColors()
	if not self.trail then
		return
	end
	if self.rainbow then
		self.trail.Color = pastelRainbow()
	else
		self.trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), self.accent)
	end
end

function Effects:SetAccent(color: Color3)
	self.accent = color
	self:_applyColors()
end

function Effects:SetRainbow(on: boolean)
	self.rainbow = on
	self:_applyColors()
end

function Effects:SetRunning(on: boolean)
	self.running = on
end

function Effects:Jump(pos: Vector3)
	self:_emitAt(self.dust, pos - Vector3.new(0, 2.9, 0), 6)
	self:Play("Jump", self._rng:NextNumber(0.95, 1.08))
end

function Effects:Land(pos: Vector3)
	self:_emitAt(self.dust, pos - Vector3.new(0, 2.9, 0), 4)
	self:Play("Land", self._rng:NextNumber(0.9, 1.1))
end

function Effects:Dash(pos: Vector3)
	self:_emitAt(self.puff, pos + Vector3.new(0, 0, 1.5), 8)
	self:Play("Dash", self._rng:NextNumber(1.0, 1.1))
	if self.trail then
		local trail = self.trail
		trail.Lifetime = 0.32
		trail.Transparency = NumberSequence.new(0.4, 1)
		task.delay(GameConfig.DashDuration + 0.1, function()
			if trail.Parent then
				trail.Lifetime = 0.16
				trail.Transparency = NumberSequence.new(0.7, 1)
			end
		end)
	end
end

function Effects:Crash(pos: Vector3)
	self:_emitAt(self.boom, pos, 14)
	self:Play("Crash", self._rng:NextNumber(0.9, 1.0))

	local rng = self._rng
	local count = if self._low then 4 else 7
	for i = 1, count do
		local s = Instance.new("Part")
		s.Name = "Pebble"
		s.Size = Vector3.one * rng:NextNumber(0.35, 0.8)
		s.Material = Enum.Material.SmoothPlastic
		s.Color = if i % 2 == 0 then C.Rock else C.PathA
		s.CFrame = CFrame.new(pos + rng:NextUnitVector())
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0)
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Parent = Workspace
		s.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(12, 32), rng:NextNumber(-25, 8))
		s.AssemblyAngularVelocity = rng:NextUnitVector() * 12
		Debris:AddItem(s, 2)
	end
end

function Effects:Update(_dt: number, camCF: CFrame, speedRatio: number)
	self.windPart.CFrame = camCF * CFrame.new(0, 0, -35)
	if self.running then
		self.wind.Rate = (2 + speedRatio * speedRatio * 22) * (if self._low then 0.5 else 1)
	else
		self.wind.Rate = 0
	end
end

return Effects
