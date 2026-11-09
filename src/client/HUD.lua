--[[
	HUD.lua
	Seluruh UI dibuat lewat kode. Gaya: panel krem lembut, teks gelap,
	satu warna aksen. Semua teks dari Locale (ikut bahasa pemain) dan
	petunjuk kontrol ikut perangkat (keyboard / layar sentuh / gamepad).

	Didesain di 1280x720, lalu diskalakan otomatis untuk HP, tablet, PC, TV.
	Konten diletakkan di area aman layar (tidak tertutup notch HP).
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Locale = require(Shared:WaitForChild("Locale"))

local HUD = {}
HUD.__index = HUD

local FONT_TITLE = Enum.Font.FredokaOne
local FONT_BODY = Enum.Font.BuilderSansBold
local FONT_NUM = Enum.Font.BuilderSansExtraBold

local WHITE = Color3.fromRGB(255, 255, 255)
local PANEL = Color3.fromRGB(252, 249, 243)
local INK = Color3.fromRGB(58, 62, 80)
local MUTED = Color3.fromRGB(128, 130, 146)
local LINE = Color3.fromRGB(226, 220, 208)
local CORAL = Color3.fromRGB(232, 128, 110)
local SKY = Color3.fromRGB(110, 160, 215)
local GOLD = Color3.fromRGB(226, 182, 96)
local SHADOW = Color3.fromRGB(40, 44, 64)

-- ===== helper =====
local function new(className: string, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(r: number)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function textStroke(color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function borderStroke(color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function tween(inst: Instance, time: number, props, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- label dengan ukuran teks otomatis (maxSize) agar muat di semua bahasa
local function label(props, maxSize: number?)
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = INK,
		Font = FONT_BODY,
		TextScaled = true,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 30),
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local l = new("TextLabel", base)
	new("UITextSizeConstraint", { MaxTextSize = maxSize or 28, MinTextSize = 8, Parent = l })
	return l
end

local function panel(props)
	local base = {
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local f = new("Frame", base, { corner(20), borderStroke(LINE, 1.5) })
	return f
end

local function button(color: Color3, size: UDim2, textSize: number)
	local scale = new("UIScale")
	local b = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = size,
		Text = "",
		Font = FONT_BODY,
		TextScaled = true,
		TextColor3 = WHITE,
		Selectable = true,
	}, {
		corner(14),
		scale,
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		new("UITextSizeConstraint", { MaxTextSize = textSize, MinTextSize = 8 }),
	})
	borderStroke(color:Lerp(SHADOW, 0.25), 2, 0.2).Parent = b
	b.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.04 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.08, { Scale = 0.96 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.SelectionGained:Connect(function()
		tween(scale, 0.12, { Scale = 1.04 })
	end)
	b.SelectionLost:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	return b
end

local function keycap(parent: Instance)
	local cap = new("TextLabel", {
		Name = "Keycap",
		BackgroundColor3 = WHITE,
		Size = UDim2.fromOffset(104, 40),
		Font = FONT_NUM,
		TextScaled = true,
		TextColor3 = INK,
		Text = "",
		Parent = parent,
	}, {
		corner(10),
		borderStroke(LINE, 2),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
		new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 }),
	})
	return cap
end

-- ===== konstruksi =====
function HUD.new()
	local self = setmetatable({}, HUD)
	self._scales = {}
	self._t = 0
	self._best = 0
	self._device = "kbm"
	self._entries = {}
	self._overData = nil
	self._muted = false
	self._perks = { doubleScore = false, rainbowTrail = false }

	self.OnPlay = nil
	self.OnRevive = nil
	self.OnBuyDouble = nil
	self.OnBuyRainbow = nil
	self.OnToggleSound = nil
	self.OnClick = nil

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- lapisan latar (full layar, termasuk area notch)
	self.bgGui = new("ScreenGui", {
		Name = "OBC_Background",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		AutoLocalize = false,
		DisplayOrder = 9,
		Parent = playerGui,
	})
	self.dim = new("Frame", {
		Name = "Dim",
		BackgroundColor3 = SHADOW,
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Parent = self.bgGui,
	}, {
		new("UIGradient", {
			Rotation = 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.55, 0.85),
				NumberSequenceKeypoint.new(1, 0.4),
			}),
		}),
	})
	self.flash = new("Frame", {
		Name = "Flash",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = self.bgGui,
	})

	-- lapisan konten (area aman)
	self.gui = new("ScreenGui", {
		Name = "OBC_HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		AutoLocalize = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = playerGui,
	})

	self:_buildRunHud()
	self:_buildMenu()
	self:_buildGameOver()
	self:_buildLeaderboard()
	self:_buildSoundToggle()

	local function rescale()
		local vp = Workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.45, 1.6)
		for _, sc in ipairs(self._scales) do
			sc.Scale = s
		end
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	Locale.Changed:Connect(function()
		self:Refresh()
	end)

	self:Refresh()
	self:HideAll()
	return self
end

function HUD:_scaled(frame: Instance)
	local sc = new("UIScale", { Parent = frame })
	table.insert(self._scales, sc)
	return frame
end

function HUD:_click(fn)
	if self.OnClick then
		self.OnClick()
	end
	if fn then
		fn()
	end
end

function HUD:_buildRunHud()
	local run = new("Frame", { Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.gui })
	self.run = run

	local box = self:_scaled(new("Frame", {
		Name = "ScoreBox",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(420, 150),
		Parent = run,
	}))

	self.scoreScale = new("UIScale")
	self.score = label({
		Name = "Score",
		Text = "0",
		Font = FONT_NUM,
		TextColor3 = WHITE,
		Size = UDim2.new(1, 0, 0, 84),
		Parent = box,
	}, 84)
	textStroke(SHADOW, 3, 0.55).Parent = self.score
	self.scoreScale.Parent = self.score

	self.bestRun = label({
		Name = "Best",
		TextColor3 = WHITE,
		Font = FONT_BODY,
		Position = UDim2.new(0, 0, 0, 84),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = box,
	}, 20)
	textStroke(SHADOW, 2, 0.6).Parent = self.bestRun

	self.multBadge = new("TextLabel", {
		Name = "Mult",
		BackgroundColor3 = GOLD,
		Position = UDim2.new(1, -70, 0, 24),
		Size = UDim2.fromOffset(58, 32),
		Text = "2x",
		Font = FONT_NUM,
		TextSize = 22,
		TextColor3 = WHITE,
		Visible = false,
		Parent = box,
	}, { corner(10) })

	local bar = new("Frame", {
		Name = "SpeedBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(220, 8),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.6,
		Parent = box,
	}, { corner(4) })
	self.speedFill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = WHITE,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { corner(4) })

	-- popup (zona / milestone)
	local popBox = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 70),
		Parent = self.gui,
	}))
	self.popupScale = new("UIScale")
	self.popup = label({
		Name = "Popup",
		Font = FONT_TITLE,
		TextColor3 = WHITE,
		Size = UDim2.fromScale(1, 1),
		TextTransparency = 1,
		Parent = popBox,
	}, 46)
	self.popupStroke = textStroke(SHADOW, 3, 1)
	self.popupStroke.Parent = self.popup
	self.popupScale.Parent = self.popup

	-- hitung mundur
	local cdBox = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(600, 180),
		Parent = self.gui,
	}))
	self.cdScale = new("UIScale")
	self.countdown = label({
		Name = "Countdown",
		Font = FONT_TITLE,
		TextColor3 = WHITE,
		Size = UDim2.fromScale(1, 1),
		TextTransparency = 1,
		Parent = cdBox,
	}, 140)
	self.cdStroke = textStroke(SHADOW, 4, 1)
	self.cdStroke.Parent = self.countdown
	self.cdScale.Parent = self.countdown
end

function HUD:_howToRow(parent: Instance, order: number)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order,
		Parent = parent,
	})
	local cap = keycap(row)
	cap.Position = UDim2.fromOffset(0, 2)
	local situation = label({
		Font = FONT_BODY,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(120, 0),
		Size = UDim2.new(0.5, -70, 1, 0),
		Parent = row,
	}, 18)
	local action = label({
		Font = FONT_TITLE,
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.5, -60, 1, 0),
		Parent = row,
	}, 26)
	return cap, situation, action
end

function HUD:_buildMenu()
	local menu = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.gui })
	self.menu = menu

	local content = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.fromOffset(520, 600),
		Parent = menu,
	}))

	local top = label({
		Text = "ONE BUTTON",
		Font = FONT_TITLE,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = content,
	}, 50)
	textStroke(SHADOW, 3, 0.5).Parent = top

	self.titleScale = new("UIScale")
	local titleHolder = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 120),
		Parent = content,
	})
	-- bayangan judul (teks yang sama digeser)
	label({
		Text = "CHAOS",
		Font = FONT_TITLE,
		TextColor3 = CORAL:Lerp(SHADOW, 0.25),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(4, 6),
		Size = UDim2.fromScale(1, 1),
		Parent = titleHolder,
	}, 124)
	self.title = label({
		Text = "CHAOS",
		Font = FONT_TITLE,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 1),
		Parent = titleHolder,
	}, 124)
	self.titleScale.Parent = titleHolder

	self.tagline = label({
		Font = FONT_BODY,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(2, 172),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = content,
	}, 24)
	textStroke(SHADOW, 2, 0.6).Parent = self.tagline

	-- kartu cara bermain
	local card = panel({
		Position = UDim2.fromOffset(0, 220),
		Size = UDim2.new(1, 0, 0, 140),
		Parent = content,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
		PaddingTop = UDim.new(0, 18),
		PaddingBottom = UDim.new(0, 18),
		Parent = card,
	})
	new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	self.cap1, self.sit1, self.act1 = self:_howToRow(card, 1)
	self.cap2, self.sit2, self.act2 = self:_howToRow(card, 2)

	-- ajakan mulai
	self.promptPill = new("Frame", {
		BackgroundColor3 = CORAL,
		Position = UDim2.fromOffset(0, 384),
		Size = UDim2.new(1, 0, 0, 58),
		Parent = content,
	}, { corner(29) })
	self.prompt = label({
		Font = FONT_BODY,
		TextColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 1, -20),
		Parent = self.promptPill,
	}, 24)

	self.bestMenu = label({
		Font = FONT_BODY,
		TextColor3 = WHITE,
		Position = UDim2.fromOffset(0, 452),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = content,
	}, 22)
	textStroke(SHADOW, 2, 0.6).Parent = self.bestMenu

	local shop = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 500),
		Size = UDim2.new(1, 0, 0, 50),
		Parent = content,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
		}),
	})
	self.buyDouble = button(GOLD, UDim2.new(0.5, -6, 1, 0), 22)
	self.buyDouble.Parent = shop
	self.buyDouble.Activated:Connect(function()
		self:_click(self.OnBuyDouble)
	end)
	self.buyRainbow = button(SKY, UDim2.new(0.5, -6, 1, 0), 22)
	self.buyRainbow.Parent = shop
	self.buyRainbow.Activated:Connect(function()
		self:_click(self.OnBuyRainbow)
	end)
	self:_updateShop()
end

function HUD:_buildGameOver()
	local over = new("Frame", { Name = "GameOver", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.gui })
	self.over = over

	local holder = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.fromOffset(460, 470),
		Parent = over,
	}))
	self.cardScale = new("UIScale")
	local card = panel({ Name = "Card", Size = UDim2.fromScale(1, 1), Parent = holder })
	self.cardScale.Parent = card

	self.overTitle = label({
		Font = FONT_TITLE,
		TextColor3 = INK,
		Position = UDim2.fromOffset(20, 22),
		Size = UDim2.new(1, -40, 0, 46),
		Parent = card,
	}, 42)
	self.reason = label({
		Font = FONT_BODY,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 0, 24),
		Parent = card,
	}, 20)

	new("Frame", {
		BackgroundColor3 = LINE,
		Position = UDim2.new(0, 40, 0, 108),
		Size = UDim2.new(1, -80, 0, 2),
		BorderSizePixel = 0,
		Parent = card,
	})

	self.overScore = label({
		Text = "0",
		Font = FONT_NUM,
		TextColor3 = INK,
		Position = UDim2.fromOffset(20, 118),
		Size = UDim2.new(1, -40, 0, 84),
		Parent = card,
	}, 80)
	self.overUnit = label({
		Font = FONT_BODY,
		TextColor3 = MUTED,
		Position = UDim2.fromOffset(20, 198),
		Size = UDim2.new(1, -40, 0, 22),
		Parent = card,
	}, 20)
	self.official = label({
		Text = "",
		Font = FONT_BODY,
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(20, 222),
		Size = UDim2.new(1, -40, 0, 22),
		Parent = card,
	}, 20)
	self.overBest = label({
		Font = FONT_BODY,
		TextColor3 = INK,
		Position = UDim2.fromOffset(20, 246),
		Size = UDim2.new(1, -40, 0, 24),
		Parent = card,
	}, 22)

	self.newBest = new("Frame", {
		Name = "NewBest",
		BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 126),
		Size = UDim2.fromOffset(150, 34),
		Rotation = 6,
		Visible = false,
		Parent = card,
	}, { corner(17) })
	self.newBestText = label({
		Font = FONT_TITLE,
		TextColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -8),
		Parent = self.newBest,
	}, 20)

	local stack = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 290),
		Size = UDim2.new(1, -48, 0, 126),
		Parent = card,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.playBtn = button(CORAL, UDim2.new(1, 0, 0, 58), 26)
	self.playBtn.LayoutOrder = 1
	self.playBtn.Parent = stack
	self.playBtn.Activated:Connect(function()
		self:_click(self.OnPlay)
	end)

	self.revive = button(SKY, UDim2.new(1, 0, 0, 48), 20)
	self.revive.LayoutOrder = 2
	self.revive.Parent = stack
	self.revive.Activated:Connect(function()
		self:_click(self.OnRevive)
	end)

	self.retryHint = label({
		Font = FONT_BODY,
		TextColor3 = MUTED,
		Position = UDim2.new(0, 20, 1, -38),
		Size = UDim2.new(1, -40, 0, 22),
		Parent = card,
	}, 18)
end

function HUD:_buildLeaderboard()
	local board = self:_scaled(panel({
		Name = "Leaderboard",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -36, 0.5, 0),
		Size = UDim2.fromOffset(300, 420),
		Parent = self.gui,
	}))
	self.board = board

	self.boardTitle = label({
		Font = FONT_TITLE,
		TextColor3 = INK,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 32),
		Parent = board,
	}, 26)
	new("Frame", {
		BackgroundColor3 = LINE,
		Position = UDim2.new(0, 20, 0, 54),
		Size = UDim2.new(1, -40, 0, 2),
		BorderSizePixel = 0,
		Parent = board,
	})
	self.boardList = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 1, -80),
		Parent = board,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

function HUD:_buildSoundToggle()
	local holder = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -36, 0, 64),
		Size = UDim2.fromOffset(190, 40),
		Parent = self.gui,
	}))
	self.soundHolder = holder
	self.soundBtn = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromScale(1, 1),
		Font = FONT_BODY,
		TextScaled = true,
		TextColor3 = INK,
		Text = "",
		Parent = holder,
	}, {
		corner(20),
		borderStroke(LINE, 1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
		new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 }),
	})
	self.soundBtn.Activated:Connect(function()
		self:_click(self.OnToggleSound)
	end)
end

-- ===== teks (bahasa & perangkat) =====

function HUD:_deviceKey(prefix: string): string
	return Locale.Get(prefix .. "_" .. self._device)
end

function HUD:_updateShop()
	local passes = GameConfig.GamePassIds
	self.buyDouble.Visible = passes.DoubleScore ~= 0 and not self._perks.doubleScore
	self.buyRainbow.Visible = passes.RainbowTrail ~= 0 and not self._perks.rainbowTrail
end

function HUD:Refresh()
	self.tagline.Text = Locale.Get("tagline")
	self.prompt.Text = self:_deviceKey("start")
	for _, cap in ipairs({ self.cap1, self.cap2 }) do
		cap.Text = self:_deviceKey("key")
	end
	self.sit1.Text = Locale.Get("on_ground")
	self.act1.Text = Locale.Get("jump")
	self.sit2.Text = Locale.Get("in_air")
	self.act2.Text = Locale.Get("dash")

	self.buyDouble.Text = Locale.Get("shop_double")
	self.buyRainbow.Text = Locale.Get("shop_trail")

	self.overTitle.Text = Locale.Get("game_over")
	self.overUnit.Text = Locale.Get("unit")
	self.newBestText.Text = Locale.Get("new_best")
	self.playBtn.Text = Locale.Get("play_again")
	self.revive.Text = Locale.Get("revive")
	self.retryHint.Text = self:_deviceKey("retry")
	if self._overData then
		self.reason.Text = Locale.Get(if self._overData.reason == "fall" then "reason_fall" else "reason_hit")
	end

	self.boardTitle.Text = Locale.Get("top_players")
	self.soundBtn.Text = Locale.Get(if self._muted then "sound_off" else "sound_on")
	self:SetBest(self._best)
	self:SetLeaderboard(self._entries)
end

function HUD:SetDevice(device: string)
	self._device = device
	self:Refresh()
end

function HUD:SetMuted(muted: boolean)
	self._muted = muted
	self.soundBtn.Text = Locale.Get(if muted then "sound_off" else "sound_on")
end

-- ===== state layar =====

function HUD:HideAll()
	self.run.Visible = false
	self.menu.Visible = false
	self.over.Visible = false
	self.board.Visible = false
	self.soundHolder.Visible = false
	self.dim.Visible = false
end

function HUD:ShowMenu(best: number)
	self:HideAll()
	self.menu.Visible = true
	self.board.Visible = true
	self.soundHolder.Visible = true
	self.dim.Visible = true
	self._overData = nil
	self:SetBest(best)
end

function HUD:ShowRun()
	self:HideAll()
	self.run.Visible = true
	self._overData = nil
	self:SetScore(0)
	self:SetSpeedRatio(0)
end

function HUD:ShowGameOver(data)
	self:HideAll()
	self.over.Visible = true
	self.board.Visible = true
	self.soundHolder.Visible = true
	self.dim.Visible = true
	self._overData = data

	self.reason.Text = Locale.Get(if data.reason == "fall" then "reason_fall" else "reason_hit")
	self.official.Text = ""
	self.revive.Visible = data.canRevive
	self.newBest.Visible = data.newBest
	self:SetBest(data.best)

	self.cardScale.Scale = 0.85
	tween(self.cardScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	-- skor menghitung naik
	local nv = Instance.new("NumberValue")
	nv.Changed:Connect(function(v)
		self.overScore.Text = tostring(math.floor(v))
	end)
	self.overScore.Text = "0"
	local t = tween(nv, 0.7, { Value = data.score }, Enum.EasingStyle.Cubic)
	t.Completed:Connect(function()
		self.overScore.Text = tostring(data.score)
		nv:Destroy()
	end)
end

-- ===== nilai =====

function HUD:SetOfficialScore(official: number, doubled: boolean)
	if doubled and self.over.Visible then
		self.official.Text = Locale.Get("double_note", official)
	end
end

function HUD:SetScore(n: number)
	self.score.Text = tostring(n)
end

function HUD:SetBest(n: number)
	self._best = n
	local text = Locale.Get("best_value", n)
	self.bestRun.Text = text
	self.bestMenu.Text = text
	self.overBest.Text = text
end

function HUD:SetSpeedRatio(r: number)
	self.speedFill.Size = UDim2.fromScale(math.clamp(r, 0.02, 1), 1)
end

function HUD:SetAccent(color: Color3)
	tween(self.speedFill, 1, { BackgroundColor3 = WHITE:Lerp(color, 0.6) })
end

function HUD:SetPerks(perks)
	self._perks = perks
	self.multBadge.Visible = perks.doubleScore == true
	self:_updateShop()
end

function HUD:PulseScore()
	self.scoreScale.Scale = 1.25
	tween(self.scoreScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HUD:Popup(text: string)
	local p = self.popup
	p.Text = text
	p.TextTransparency = 0
	self.popupStroke.Transparency = 0.5
	self.popupScale.Scale = 0.7
	tween(self.popupScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local myText = text
	task.delay(1.6, function()
		if p.Text == myText then
			tween(p, 0.5, { TextTransparency = 1 })
			tween(self.popupStroke, 0.5, { Transparency = 1 })
		end
	end)
end

function HUD:Countdown(text: string)
	local c = self.countdown
	c.Text = text
	c.TextTransparency = 0
	self.cdStroke.Transparency = 0.45
	self.cdScale.Scale = 1.5
	tween(self.cdScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.42, function()
		if c.Text == text then
			tween(c, 0.15, { TextTransparency = 1 })
			tween(self.cdStroke, 0.15, { Transparency = 1 })
		end
	end)
end

function HUD:Flash()
	self.flash.BackgroundTransparency = 0.7
	tween(self.flash, 0.5, { BackgroundTransparency = 1 })
end

local RANK_COLORS = { GOLD, Color3.fromRGB(150, 160, 180), Color3.fromRGB(200, 140, 110) }

function HUD:SetLeaderboard(entries)
	self._entries = entries
	for _, c in ipairs(self.boardList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if #entries == 0 then
		label({
			Text = Locale.Get("board_empty"),
			Font = FONT_BODY,
			TextColor3 = MUTED,
			Size = UDim2.new(1, 0, 0, 56),
			Parent = self.boardList,
		}, 18)
		return
	end
	for i = 1, math.min(#entries, 10) do
		local e = entries[i]
		local row = new("Frame", {
			LayoutOrder = i,
			BackgroundColor3 = LINE,
			BackgroundTransparency = if i % 2 == 0 then 1 else 0.6,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = self.boardList,
		}, { corner(8) })
		label({
			Text = tostring(i),
			Font = FONT_NUM,
			TextColor3 = RANK_COLORS[i] or MUTED,
			Size = UDim2.new(0, 30, 1, -6),
			Position = UDim2.fromOffset(0, 3),
			Parent = row,
		}, 18)
		label({
			Text = tostring(e.name),
			Font = FONT_BODY,
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Position = UDim2.fromOffset(34, 4),
			Size = UDim2.new(1, -120, 1, -8),
			Parent = row,
		}, 16)
		label({
			Text = tostring(e.score),
			Font = FONT_NUM,
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 4),
			Size = UDim2.new(0, 76, 1, -8),
			Parent = row,
		}, 16)
	end
end

-- animasi idle (judul bernapas, tombol mulai berdenyut)
function HUD:Update(dt: number)
	self._t += dt
	if self.menu.Visible then
		self.titleScale.Scale = 1 + math.sin(self._t * 2) * 0.02
		self.promptPill.BackgroundTransparency = 0.08 + 0.1 * (0.5 + 0.5 * math.sin(self._t * 3))
	end
end

return HUD
