--[[
	RunnerAnimator.lua
	Animasi karakter R6 yang dikendalikan game (bukan script Animate bawaan),
	supaya kecepatan lari ikut kecepatan karakter dan pose lompat/jatuh tepat.
	Memakai animasi standar R6 milik Roblox.
--]]

local RunnerAnimator = {}
RunnerAnimator.__index = RunnerAnimator

local IDS = {
	Idle = "rbxassetid://180435571",
	Run = "rbxassetid://180426354",
	Jump = "rbxassetid://125750702",
	Fall = "rbxassetid://180436148",
}

-- kecepatan karakter saat animasi lari R6 diputar dengan speed 1
local BASE_RUN_SPEED = 16

function RunnerAnimator.new(character: Model, humanoid: Humanoid)
	local self = setmetatable({}, RunnerAnimator)
	self.tracks = {}
	self.current = nil :: string?

	-- matikan script Animate bawaan agar tidak bentrok
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	for name, id in pairs(IDS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = if name == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			track.Looped = name ~= "Jump"
			self.tracks[name] = track
		end
	end
	return self
end

function RunnerAnimator:Play(name: string, fade: number?, speed: number?)
	local track = self.tracks[name]
	if not track then
		return
	end
	if self.current ~= name then
		local prev = self.current and self.tracks[self.current]
		if prev then
			prev:Stop(fade or 0.15)
		end
		track:Play(fade or 0.15)
		self.current = name
	end
	if speed then
		track:AdjustSpeed(speed)
	end
end

-- state: "Idle" | "Run" | "Jump" | "Fall"; horizontalSpeed dipakai untuk tempo lari
function RunnerAnimator:Update(state: string, horizontalSpeed: number)
	if state == "Run" then
		self:Play("Run", 0.12, math.clamp(horizontalSpeed / BASE_RUN_SPEED, 0.8, 2.6))
	elseif state == "Jump" then
		self:Play("Jump", 0.08, 1)
	elseif state == "Fall" then
		self:Play("Fall", 0.25, 1)
	else
		self:Play("Idle", 0.25, 1)
	end
end

function RunnerAnimator:Destroy()
	for _, track in pairs(self.tracks) do
		track:Stop(0)
		track:Destroy()
	end
	self.tracks = {}
end

return RunnerAnimator
