--[[
	InputController.lua
	Satu tombol untuk semua perangkat:
	  PC      : Spasi, W, Panah Atas, atau klik kiri
	  HP/Tablet: ketuk di mana saja
	  Gamepad : A atau R2 (Xbox, PlayStation, gamepad lain)

	Juga mendeteksi perangkat yang sedang dipakai ("kbm" | "touch" | "pad")
	supaya teks petunjuk di layar selalu sesuai.
--]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local InputController = {}
InputController.__index = InputController

local ACTION_KEYS = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonR2] = true,
}

local GAMEPAD_TYPES = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}

local function deviceFromInputType(t: Enum.UserInputType): string?
	if t == Enum.UserInputType.Touch then
		return "touch"
	elseif GAMEPAD_TYPES[t] then
		return "pad"
	elseif
		t == Enum.UserInputType.Keyboard
		or t == Enum.UserInputType.MouseButton1
		or t == Enum.UserInputType.MouseButton2
		or t == Enum.UserInputType.MouseMovement
		or t == Enum.UserInputType.MouseWheel
	then
		return "kbm"
	end
	return nil
end

local function initialDevice(): string
	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok and preferred then
		if preferred == Enum.PreferredInput.Touch then
			return "touch"
		elseif preferred == Enum.PreferredInput.Gamepad then
			return "pad"
		elseif preferred == Enum.PreferredInput.KeyboardAndMouse then
			return "kbm"
		end
	end
	local fromLast = deviceFromInputType(UserInputService:GetLastInputType())
	if fromLast then
		return fromLast
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "pad"
	end
	return "kbm"
end

function InputController.new()
	local self = setmetatable({}, InputController)
	self._lastActionTime = 0
	self._callbacks = {} :: { () -> () }
	self._deviceCallbacks = {} :: { (string) -> () }
	self._connections = {} :: { RBXScriptConnection }
	self._enabled = false
	self.device = initialDevice()
	return self
end

-- Perangkat dengan performa terbatas (HP/tablet) -> detail visual dikurangi
function InputController.IsLowEndDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function InputController:OnAction(callback: () -> ())
	table.insert(self._callbacks, callback)
end

function InputController:OnDeviceChanged(callback: (string) -> ())
	table.insert(self._deviceCallbacks, callback)
end

function InputController:_setDevice(device: string?)
	if device and device ~= self.device then
		self.device = device
		for _, cb in ipairs(self._deviceCallbacks) do
			task.spawn(cb, device)
		end
	end
end

function InputController:_fire()
	local now = os.clock()
	if now - self._lastActionTime < GameConfig.ActionCooldown then
		return
	end
	self._lastActionTime = now
	if not self._enabled then
		return
	end
	for _, cb in ipairs(self._callbacks) do
		cb()
	end
end

function InputController:Enable()
	self._enabled = true
end

function InputController:Disable()
	self._enabled = false
end

function InputController:Start()
	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			self:_setDevice(deviceFromInputType(input.UserInputType))
			if gameProcessed then
				return -- mis. menekan tombol UI atau mengetik di chat
			end
			if
				ACTION_KEYS[input.KeyCode]
				or input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self:_fire()
			end
		end)
	)
	table.insert(
		self._connections,
		UserInputService.LastInputTypeChanged:Connect(function(t)
			self:_setDevice(deviceFromInputType(t))
		end)
	)
end

function InputController:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._callbacks)
	table.clear(self._deviceCallbacks)
end

return InputController
