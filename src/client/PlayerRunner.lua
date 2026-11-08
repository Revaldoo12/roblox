--!strict
--[[
	PlayerRunner.lua
	------------------------------------------------------------
	Mengelola karakter pemain yang lari otomatis.
	Satu aksi (dari InputController) bersifat CONTEXT-SENSITIVE:
	  - Di tanah  -> Jump
	  - Di udara  -> Dash (dorongan ke depan)
	Inilah yang membuat satu tombol terasa "chaos" tapi tetap dalam kendali.
--]]

local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local PlayerRunner = {}
PlayerRunner.__index = PlayerRunner

function PlayerRunner.new(character: Model)
	local self = setmetatable({}, PlayerRunner)
	self.character = character
	self.humanoid = character:WaitForChild("Humanoid") :: Humanoid
	self.root = character:WaitForChild("HumanoidRootPart") :: BasePart

	self.speed = GameConfig.StartSpeed
	self.distance = 0
	self.isDashing = false
	self._dashEndTime = 0
	self._alive = true
	self._heartbeat = nil :: RBXScriptConnection?
	return self
end

-- Dipanggil tiap frame untuk menggerakkan karakter maju otomatis
function PlayerRunner:_update(dt: number)
	if not self._alive then
		return
	end

	-- naikkan kecepatan seiring waktu (difficulty ramp)
	self.speed = math.min(GameConfig.MaxSpeed, self.speed + GameConfig.SpeedRampPerSecond * dt)

	-- hitung kecepatan maju (dash memberi boost sementara)
	local forwardSpeed = self.speed
	if self.isDashing then
		if os.clock() >= self._dashEndTime then
			self.isDashing = false
		else
			forwardSpeed += GameConfig.DashSpeed
		end
	end

	-- gerakkan karakter ke arah depan (sumbu +Z dunia, sesuaikan dengan map-mu)
	local moveDir = Vector3.new(0, 0, -1)
	self.humanoid:Move(moveDir, false)
	self.humanoid.WalkSpeed = forwardSpeed

	self.distance += forwardSpeed * dt
end

-- Aksi context-sensitive dari satu tombol
function PlayerRunner:DoAction(): string
	if not self._alive then
		return ""
	end

	local state = self.humanoid:GetState()
	local onGround = state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed

	if onGround then
		-- di tanah -> lompat
		self.humanoid.JumpPower = GameConfig.JumpPower
		self.humanoid.Jump = true
		return GameConfig.ActionType.Jump
	else
		-- di udara -> dash
		if not self.isDashing then
			self.isDashing = true
			self._dashEndTime = os.clock() + GameConfig.DashDuration
		end
		return GameConfig.ActionType.Dash
	end
end

function PlayerRunner:GetScore(): number
	return math.floor(self.distance)
end

function PlayerRunner:Start()
	self._heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end)

	-- deteksi mati (jatuh)
	self.humanoid.Died:Connect(function()
		self:Stop()
	end)
end

function PlayerRunner:IsAlive(): boolean
	return self._alive
end

function PlayerRunner:Stop()
	self._alive = false
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
end

return PlayerRunner
