--!strict
--[[
	HUD.lua
	------------------------------------------------------------
	Membuat tampilan skor + petunjuk "TAP / SPACE" secara programatik,
	jadi kamu tidak perlu menyusun ScreenGui manual di Studio.
	Minimalis & jelas = cocok untuk clip pendek.
--]]

local Players = game:GetService("Players")

local HUD = {}
HUD.__index = HUD

local function makeLabel(parent: Instance, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = parent
	return label
end

function HUD.new()
	local self = setmetatable({}, HUD)

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "OneButtonChaosHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- SKOR besar di atas tengah
	local score = makeLabel(gui, "Score")
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0.04, 0)
	score.Size = UDim2.new(0.3, 0, 0.1, 0)
	score.Text = "0"
	self.scoreLabel = score

	-- Hint kontrol di bawah
	local hint = makeLabel(gui, "Hint")
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 0.95, 0)
	hint.Size = UDim2.new(0.5, 0, 0.06, 0)
	hint.TextColor3 = Color3.fromRGB(255, 220, 120)
	hint.Text = "TAP / SPACE untuk beraksi!"
	self.hintLabel = hint

	-- Banner "GAME OVER" (tersembunyi awalnya)
	local banner = makeLabel(gui, "Banner")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, 0.4, 0)
	banner.Size = UDim2.new(0.6, 0, 0.14, 0)
	banner.TextColor3 = Color3.fromRGB(255, 90, 90)
	banner.Visible = false
	self.bannerLabel = banner

	-- Panel LEADERBOARD global di kiri atas
	local board = Instance.new("Frame")
	board.Name = "Leaderboard"
	board.AnchorPoint = Vector2.new(0, 0)
	board.Position = UDim2.new(0.02, 0, 0.1, 0)
	board.Size = UDim2.new(0.22, 0, 0.42, 0)
	board.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	board.BackgroundTransparency = 0.25
	board.BorderSizePixel = 0
	board.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = board

	local boardTitle = makeLabel(board, "Title")
	boardTitle.Position = UDim2.new(0, 0, 0, 0)
	boardTitle.Size = UDim2.new(1, 0, 0.12, 0)
	boardTitle.TextColor3 = Color3.fromRGB(120, 220, 255)
	boardTitle.Text = "🏆 TOP PLAYERS"

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0.04, 0, 0.14, 0)
	list.Size = UDim2.new(0.92, 0, 0.84, 0)
	list.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list

	self.leaderboardList = list

	self.gui = gui
	return self
end

-- Perbarui panel leaderboard dari data server: { {name=, score=}, ... }
function HUD:SetLeaderboard(entries: { { name: string, score: number } })
	local list = self.leaderboardList
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local maxShow = math.min(#entries, 10)
	for i = 1, maxShow do
		local entry = entries[i]
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextColor3 = Color3.fromRGB(235, 235, 245)
		row.TextStrokeTransparency = 0.6
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Size = UDim2.new(1, 0, 0.09, 0)
		row.Text = ("%d. %s — %d"):format(i, entry.name, entry.score)
		row.Parent = list
	end
end

function HUD:SetScore(value: number)
	self.scoreLabel.Text = tostring(value)
end

function HUD:ShowGameOver(finalScore: number, best: number?)
	self.bannerLabel.Visible = true
	self.bannerLabel.Text = ("GAME OVER\nSkor: %d"):format(finalScore)
	if best then
		self.hintLabel.Text = ("Best: %d  •  TAP untuk main lagi"):format(best)
	else
		self.hintLabel.Text = "TAP untuk main lagi"
	end
end

function HUD:Reset()
	self.bannerLabel.Visible = false
	self.hintLabel.Text = "TAP / SPACE untuk beraksi!"
	self:SetScore(0)
end

return HUD
