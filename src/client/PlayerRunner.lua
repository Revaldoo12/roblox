--[[
	PlayerRunner.lua
	Karakter lari otomatis. Satu tombol, aksi tergantung situasi:
	  - Di tanah (atau baru saja lewat tepi) -> LOMPAT
	  - Di udara                              -> DASH (melesat + melayang, 1x per lompatan)
	Ada coyote time & jump buffer supaya kontrol terasa responsif dan "adil".
--]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrackGenerator = require(Shared:WaitForChild("TrackGenerator"))
local RunnerAnimator = require(script.Parent:WaitForChild("RunnerAnimator"))

local PlayerRunner = {}
PlayerRunner.__index = PlayerRunner

local START_DISTANCE = -8 -- berdiri di platform start, sebelum lintasan

local DISABLED_STATES = {
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.GettingUp,
}

function PlayerRunner.new(character: Model)
	local self = setmetatable({}, PlayerRunner)
	self.character = character
	self.humanoid = character:WaitForChild("Humanoid") :: Humanoid
	self.root = character:WaitForChild("HumanoidRootPart") :: BasePart
	self.state = "Idle"
	self.distance = 0
	self.speed = GameConfig.StartSpeed
	self.dashUsed = false
	self.dashEnd = 0
	self.lastJump = -10
	self.lastGrounded = 0
	self.jumpBufferUntil = 0
	self.wasGrounded = true
	self._saved = nil

	-- callback yang dipasang oleh Main
	self.OnJump = nil
	self.OnDash = nil
	self.OnLand = nil
	self.OnCrash = nil

	local h = self.humanoid
	h.UseJumpPower = true
	h.JumpPower = GameConfig.JumpPower
	h.AutoRotate = false
	for _, st in ipairs(DISABLED_STATES) do
		h:SetStateEnabled(st, false)
	end

	self.animator = RunnerAnimator.new(character, h)

	self._overlap = OverlapParams.new()
	self._overlap.FilterType = Enum.RaycastFilterType.Include
	self._overlap.MaxParts = 4
	return self
end

function PlayerRunner:SetHazardFolder(folder: Instance)
	self._overlap.FilterDescendantsInstances = { folder }
end

function PlayerRunner:_rootHeight(): number
	if self.humanoid.RigType == Enum.HumanoidRigType.R15 then
		return self.humanoid.HipHeight + self.root.Size.Y / 2
	end
	return 3
end

function PlayerRunner:_placeAt(distance: number)
	self.root.Anchored = true
	self.root.AssemblyLinearVelocity = Vector3.zero
	self.character:PivotTo(CFrame.new(0, GameConfig.TrackY + self:_rootHeight() + 0.05, -distance))
end

function PlayerRunner:_hide()
	if self._saved then
		return
	end
	self._saved = {}
	for _, d in ipairs(self.character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			self._saved[d] = d.Transparency
			d.Transparency = 1
		end
	end
end

function PlayerRunner:_show()
	if not self._saved then
		return
	end
	for inst, t in pairs(self._saved) do
		if inst.Parent then
			inst.Transparency = t
		end
	end
	self._saved = nil
end

function PlayerRunner:ResetToStart()
	self:_show()
	self.state = "Idle"
	self.distance = 0
	self.speed = GameConfig.StartSpeed
	self.dashUsed = false
	self.dashEnd = 0
	self:_placeAt(START_DISTANCE)
end

function PlayerRunner:Revive(atDistance: number)
	self:_show()
	self.state = "Idle"
	self.dashUsed = false
	self.dashEnd = 0
	self:_placeAt(atDistance)
end

function PlayerRunner:Run()
	self.state = "Running"
	self.root.Anchored = false
	self.lastGrounded = os.clock()
	self.wasGrounded = true
	self.speed = TrackGenerator.SpeedAt(self.distance)
	self.root.AssemblyLinearVelocity = Vector3.new(0, 0, -self.speed)
end

function PlayerRunner:_jump(now: number)
	local v = self.root.AssemblyLinearVelocity
	self.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	self.root.AssemblyLinearVelocity = Vector3.new(v.X, GameConfig.JumpPower, v.Z)
	self.lastJump = now
	self.wasGrounded = false
	if self.OnJump then
		self.OnJump(self.root.Position)
	end
end

function PlayerRunner:_isGrounded(now: number): boolean
	return self.humanoid.FloorMaterial ~= Enum.Material.Air and (now - self.lastJump) > 0.12
end

-- Satu-satunya input game
function PlayerRunner:DoAction(): string?
	if self.state ~= "Running" then
		return nil
	end
	local now = os.clock()
	local coyote = (now - self.lastGrounded) < GameConfig.CoyoteTime and (now - self.lastJump) > 0.25
	if self:_isGrounded(now) or coyote then
		self:_jump(now)
		return "Jump"
	end
	if not self.dashUsed then
		self.dashUsed = true
		self.dashEnd = now + GameConfig.DashDuration
		if self.OnDash then
			self.OnDash(self.root.Position)
		end
		return "Dash"
	end
	self.jumpBufferUntil = now + GameConfig.JumpBuffer
	return "Buffered"
end

function PlayerRunner:_crash(reason: string, pos: Vector3)
	self.state = "Crashed"
	self.root.Anchored = true
	self:_hide()
	if self.OnCrash then
		self.OnCrash(reason, pos)
	end
end

function PlayerRunner:Update(_dt: number)
	if self.state ~= "Running" then
		return
	end
	local now = os.clock()
	local root, h = self.root, self.humanoid
	local pos = root.Position

	self.distance = math.max(self.distance, -pos.Z)
	self.speed = TrackGenerator.SpeedAt(self.distance)

	local grounded = self:_isGrounded(now)
	if grounded then
		self.lastGrounded = now
		self.dashUsed = false
		if not self.wasGrounded and self.OnLand then
			self.OnLand(pos)
		end
		self.wasGrounded = true
		if now < self.jumpBufferUntil then
			self.jumpBufferUntil = 0
			self:_jump(now)
		end
	else
		self.wasGrounded = false
	end

	local dashing = now < self.dashEnd
	local forward = self.speed + (if dashing then GameConfig.DashSpeedBonus else 0)
	h.WalkSpeed = forward
	h:Move(Vector3.new(0, 0, -1), false)

	local vy = root.AssemblyLinearVelocity.Y
	if dashing then
		vy = math.max(vy, 0) -- melayang: tidak jatuh selama dash
	end
	root.AssemblyLinearVelocity = Vector3.new(-pos.X * 6, vy, -forward)

	if pos.Y < GameConfig.KillY then
		self:_crash("fall", pos)
		return
	end
	local box = root.CFrame * CFrame.new(0, -0.6, 0)
	local hits = Workspace:GetPartBoundsInBox(box, Vector3.new(2, 4.6, 2), self._overlap)
	if #hits > 0 then
		self:_crash("hit", pos)
	end
end

function PlayerRunner:GetScore(): number
	return math.floor(self.distance)
end

function PlayerRunner:GetSpeedRatio(): number
	return math.clamp(
		(self.speed - GameConfig.StartSpeed) / (GameConfig.MaxSpeed - GameConfig.StartSpeed),
		0,
		1
	)
end

function PlayerRunner:IsOnGround(): boolean
	return self.state == "Running" and self:_isGrounded(os.clock())
end

-- Dipanggil tiap frame di semua state (menu, countdown, lari, crash)
function PlayerRunner:UpdateAnimation()
	if self.state ~= "Running" then
		self.animator:Update("Idle", 0)
		return
	end
	local now = os.clock()
	if self:_isGrounded(now) then
		self.animator:Update("Run", self.speed)
	elseif self.root.AssemblyLinearVelocity.Y > 2 or now < self.dashEnd then
		self.animator:Update("Jump", 0)
	else
		self.animator:Update("Fall", 0)
	end
end

function PlayerRunner:Destroy()
	self.animator:Destroy()
	self.state = "Dead"
	self.OnJump, self.OnDash, self.OnLand, self.OnCrash = nil, nil, nil, nil
end

return PlayerRunner
