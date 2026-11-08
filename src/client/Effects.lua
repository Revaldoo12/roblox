--[[
	Effects.lua
	Semua "juice": suara, partikel lompat/dash/crash, trail neon,
	cahaya karakter, serpihan ledakan, dan partikel angin saat ngebut.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Effects = {}
Effects.__index = Effects

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightEmission = 1
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function rainbowSequence()
	local kps = {}
	for i = 0, 6 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	return ColorSequence.new(kps)
end

function Effects.new()
	local self = setmetatable({}, Effects)
	self._rng = Random.new()
	self.palette = GameConfig.Palettes[1]
	self.rainbow = false

	-- suara
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
	end

	-- titik emitter yang dipindah-pindah
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
		Color = ColorSequence.new(Color3.fromRGB(220, 220, 255)),
		LightEmission = 0.4,
		Size = NumberSequence.new(0.9, 0),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(80, 10),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -30, 0),
		Drag = 4,
	})
	self.sparks = emitter(fx, {
		Texture = SPARK_TEXTURE,
		Size = NumberSequence.new(0.7, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(18, 40),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
	self.boom = emitter(fx, {
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(0.3, 6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(10, 25),
		SpreadAngle = Vector2.new(180, 180),
		Color = ColorSequence.new(GameConfig.HazardColor, Color3.fromRGB(255, 180, 60)),
		Drag = 5,
	})

	-- partikel angin di depan kamera
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
		Size = NumberSequence.new(0.12),
		Squash = NumberSequence.new(2.5),
		Transparency = NumberSequence.new(0.35, 1),
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(60, 90),
		EmissionDirection = Enum.NormalId.Back,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
	})
	self.running = false
	return self
end

function Effects:Play(name: string, pitch: number?)
	local s = self.sounds[name]
	if s then
		s.PlaybackSpeed = pitch or 1
		s:Play()
	end
end

function Effects:_emitAt(e: ParticleEmitter, pos: Vector3, count: number)
	self.fx.CFrame = CFrame.new(pos)
	e:Emit(count)
end

function Effects:AttachCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local a0 = Instance.new("Attachment")
	a0.Name = "OBC_TrailTop"
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "OBC_TrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.22
	trail.MinLength = 0.1
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = root
	self.trail = trail

	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = root
	self.light = light

	self:_applyColors()
end

function Effects:_applyColors()
	if not self.trail then
		return
	end
	if self.rainbow then
		self.trail.Color = rainbowSequence()
		self.light.Color = Color3.fromRGB(255, 255, 255)
	else
		self.trail.Color = ColorSequence.new(self.palette.Primary, self.palette.Secondary)
		self.light.Color = self.palette.Primary
	end
end

function Effects:SetPalette(pal)
	self.palette = pal
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
	self:_emitAt(self.dust, pos - Vector3.new(0, 2.8, 0), 14)
	self:Play("Jump", self._rng:NextNumber(0.95, 1.1))
end

function Effects:Land(pos: Vector3)
	self:_emitAt(self.dust, pos - Vector3.new(0, 2.8, 0), 8)
	self:Play("Land", self._rng:NextNumber(0.9, 1.1))
end

function Effects:Dash(pos: Vector3)
	self.sparks.Color = ColorSequence.new(self.palette.Primary, self.palette.Secondary)
	self:_emitAt(self.sparks, pos, 28)
	self:Play("Dash", self._rng:NextNumber(1.0, 1.15))
	if self.trail then
		local trail = self.trail
		trail.Lifetime = 0.5
		trail.Transparency = NumberSequence.new(0, 1)
		task.delay(GameConfig.DashDuration + 0.1, function()
			if trail.Parent then
				trail.Lifetime = 0.22
				trail.Transparency = NumberSequence.new(0.25, 1)
			end
		end)
	end
end

function Effects:Crash(pos: Vector3)
	self:_emitAt(self.boom, pos, 40)
	self.sparks.Color = ColorSequence.new(GameConfig.HazardColor, Color3.new(1, 1, 1))
	self:_emitAt(self.sparks, pos, 60)
	self:Play("Crash", self._rng:NextNumber(0.9, 1.05))

	local rng = self._rng
	for i = 1, 14 do
		local s = Instance.new("Part")
		s.Name = "Shard"
		s.Size = Vector3.one * rng:NextNumber(0.4, 0.9)
		s.Material = Enum.Material.Neon
		s.Color = if i % 2 == 0 then GameConfig.HazardColor else self.palette.Primary
		s.CFrame = CFrame.new(pos + rng:NextUnitVector())
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0)
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Parent = Workspace
		s.AssemblyLinearVelocity =
			Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(15, 45), rng:NextNumber(-35, 10))
		s.AssemblyAngularVelocity = rng:NextUnitVector() * 20
		Debris:AddItem(s, 2.5)
	end
end

-- dipanggil tiap frame
function Effects:Update(_dt: number, camCF: CFrame, speedRatio: number)
	self.windPart.CFrame = camCF * CFrame.new(0, 0, -35)
	if self.running then
		self.wind.Rate = 20 + speedRatio * speedRatio * 140
	else
		self.wind.Rate = 0
	end
end

return Effects
