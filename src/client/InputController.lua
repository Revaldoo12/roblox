--!strict
--[[
	InputController.lua
	------------------------------------------------------------
	INTI dari "One Button Chaos": menangkap SATU input dari platform mana pun
	(PC: Space/klik kiri, Mobile: tap layar, Gamepad: tombol A)
	dan mengubahnya menjadi satu sinyal "Action".

	Semua perangkat memakai satu tombol yang sama. Inilah DNA game-nya.
--]]

local UserInputService = game:GetService("UserInputService")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local InputController = {}
InputController.__index = InputController

function InputController.new()
	local self = setmetatable({}, InputController)
	self._lastActionTime = 0
	self._callbacks = {} :: { () -> () }
	self._connections = {} :: { RBXScriptConnection }
	self._enabled = false
	return self
end

-- Daftarkan fungsi yang dipanggil setiap kali tombol ditekan
function InputController:OnAction(callback: () -> ())
	table.insert(self._callbacks, callback)
end

function InputController:_fire()
	local now = os.clock()
	if now - self._lastActionTime < GameConfig.ActionCooldown then
		return -- anti-spam
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
	-- Keyboard: Space, atau klik kiri mouse
	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if
				input.KeyCode == Enum.KeyCode.Space
				or input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA -- gamepad
			then
				self:_fire()
			end
		end)
	)
end

function InputController:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._callbacks)
end

return InputController
