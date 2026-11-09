--[[
	CameraController.lua
	Kamera sinematik:
	  Menu  - mengorbit pelan di sekitar karakter
	  Run   - di belakang-atas, FOV melebar sesuai kecepatan, "punch" saat dash
	  Crash - menjauh & menatap titik tabrakan, dengan guncangan
--]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new()
	local self = setmetatable({}, CameraController)
	self.mode = "Menu"
	self.modeTime = 0
	self.root = nil
	self.cf = Workspace.CurrentCamera.CFrame
	self.fov = 70
	self.punch = 0
	self.shake = 0
	self.speedRatio = 0
	self.smoothY = GameConfig.TrackY + 3
	self.t = 0
	self.crashPoint = nil

	RunService:BindToRenderStep("OBC_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:_update(dt)
	end)
	return self
end

function CameraController:SetTarget(root: BasePart)
	self.root = root
	self.smoothY = root.Position.Y
end

function CameraController:SetMode(mode: string, data: Vector3?)
	self.mode = mode
	self.modeTime = 0
	if mode == "Crash" then
		self.crashPoint = data
	end
end

function CameraController:SetSpeedRatio(r: number)
	self.speedRatio = r
end

function CameraController:Punch(amount: number)
	self.punch = math.max(self.punch, amount)
end

function CameraController:Shake(amount: number)
	self.shake = math.max(self.shake, amount)
end

function CameraController:_update(dt: number)
	local cam = Workspace.CurrentCamera
	local root = self.root
	if not root or not root.Parent then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	self.t += dt
	self.modeTime += dt

	local p = root.Position
	local desired: CFrame
	local k: number
	local fovTarget: number

	if self.mode == "Run" then
		self.smoothY += (p.Y - self.smoothY) * (1 - math.exp(-dt * 6))
		local r = self.speedRatio
		local camPos = Vector3.new(p.X * 0.4, self.smoothY + 7 + r * 1.5, p.Z + 16 + r * 5)
		local look = Vector3.new(0, self.smoothY + 2, p.Z - 30)
		desired = CFrame.lookAt(camPos, look)
		k = if self.modeTime < 0.8 then 5 else 14
		fovTarget = 70 + r * 12
	elseif self.mode == "Crash" then
		local cp = self.crashPoint or p
		desired = CFrame.lookAt(cp + Vector3.new(9, 8 + self.modeTime * 0.6, 16), cp)
		k = 3
		fovTarget = 60
	else -- Menu
		local a = 0.6 + math.sin(self.t * 0.35) * 0.5
		local camPos = p + Vector3.new(math.sin(a) * 15, 5, math.cos(a) * 15)
		desired = CFrame.lookAt(camPos, p + Vector3.new(0, 1.5, -6))
		k = 4
		fovTarget = 65
	end

	self.cf = self.cf:Lerp(desired, 1 - math.exp(-dt * k))
	self.punch *= math.exp(-dt * 6)
	self.fov += (fovTarget + self.punch - self.fov) * (1 - math.exp(-dt * 8))

	local shakeCF = CFrame.identity
	if self.shake > 0.01 then
		local s = self.shake
		shakeCF = CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			* CFrame.Angles(0, 0, (math.random() - 0.5) * s * 0.05)
		self.shake *= math.exp(-dt * 7)
	end

	cam.CFrame = self.cf * shakeCF
	cam.FieldOfView = self.fov
end

return CameraController
