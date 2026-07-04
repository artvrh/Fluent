local ButtonManager = {}
local Button = {}
Button.__index = Button

ButtonManager.Buttons = {}
if getgenv then
	getgenv().ButtonManager = ButtonManager
end

Button.Type = "Toggle"
Button.Text = "Auto Crouch"
Button.On = function() end
Button.Off = function() end
Button.OnClick = function() end

function ButtonManager:CreateButton(config)
	local self = setmetatable(config or {}, Button)
	self:Init()
	table.insert(ButtonManager.Buttons, self)
	return self
end

function Button:UpdateTheme() end

function Button:Destroy()
	if self.AnimationConnection then
		pcall(function()
			self.AnimationConnection:Disconnect()
		end)
	end

	if self.InputChangedConnection then
		pcall(function()
			self.InputChangedConnection:Disconnect()
		end)
	end

	if self.ScreenGui then
		pcall(function()
			self.ScreenGui:Destroy()
		end)
	end

	local idx = table.find(ButtonManager.Buttons, self)
	if idx then
		table.remove(ButtonManager.Buttons, idx)
	end

	local Library = getgenv().Fluent
	if Library and Library.CustomButtons then
		local cIdx = table.find(Library.CustomButtons, self)
		if cIdx then
			table.remove(Library.CustomButtons, cIdx)
		end
	end
end

function Button:Init()
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "Button"
	ScreenGui.ResetOnSpawn = false

	local parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	pcall(function()
		if gethui then
			parent = gethui()
		elseif game:GetService("CoreGui") then
			parent = game:GetService("CoreGui")
		end
	end)
	ScreenGui.Parent = parent
	self.ScreenGui = ScreenGui

	local DragFrame = Instance.new("Frame")
	DragFrame.Name = "DragFrame"
	DragFrame.Size = UDim2.new(0, 230, 0, 52)
	DragFrame.Position = UDim2.new(0.5, -115, 0.4, -26)
	DragFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	DragFrame.BackgroundTransparency = 0.4
	DragFrame.Parent = ScreenGui
	self.DragFrame = DragFrame

	local UIGradient = Instance.new("UIGradient")
	local colorSequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 40, 70)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 40, 70)),
	})
	UIGradient.Color = colorSequence
	UIGradient.Parent = DragFrame
	self.UIGradient = UIGradient

	local t = 0
	self.AnimationConnection = RunService.RenderStepped:Connect(function(dt)
		t = t + dt * 0.5
		UIGradient.Rotation = (t * 25) % 360
	end)

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0.5, 0)
	UICorner.Parent = DragFrame

	local UIStroke = Instance.new("UIStroke")
	UIStroke.Color = Color3.fromRGB(40, 175, 255)
	UIStroke.Thickness = 2.5
	UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	UIStroke.Parent = DragFrame
	self.UIStroke = UIStroke

	local ToggleButton = Instance.new("TextButton")
	ToggleButton.Name = "ToggleButton"
	ToggleButton.Size = UDim2.new(1, 0, 1, 0)
	ToggleButton.BackgroundTransparency = 1
	ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	ToggleButton.Font = Enum.Font.SourceSansBold
	ToggleButton.TextSize = 21
	ToggleButton.AutoButtonColor = false
	ToggleButton.Parent = DragFrame
	self.ToggleButton = ToggleButton

	if self.Type == "Click" then
		ToggleButton.Text = self.Text
		ToggleButton.MouseButton1Click:Connect(function()
			task.spawn(function()
				self.OnClick()
			end)
		end)
	else
		local isOn = false
		ToggleButton.Text = self.Text .. ": OFF"
		ToggleButton.MouseButton1Click:Connect(function()
			isOn = not isOn
			if isOn then
				ToggleButton.Text = self.Text .. ": ON"
				task.spawn(function()
					self.On()
				end)
			else
				ToggleButton.Text = self.Text .. ": OFF"
				task.spawn(function()
					self.Off()
				end)
			end
		end)
	end

	local dragging = false
	local dragInput
	local dragStart
	local startPos

	local function update(input)
		local delta = input.Position - dragStart
		DragFrame.Position =
			UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end

	ToggleButton.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = DragFrame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	ToggleButton.InputChanged:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragInput = input
		end
	end)

	self.InputChangedConnection = UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)

	local Fluent = getgenv().Fluent
	if Fluent then
		Fluent.CustomButtons = Fluent.CustomButtons or {}
		table.insert(Fluent.CustomButtons, self)

		if Fluent.GUI then
			local ancestryConnection
			ancestryConnection = Fluent.GUI.AncestryChanged:Connect(function(_, parent)
				if not parent then
					ancestryConnection:Disconnect()
					self:Destroy()
				end
			end)
		end
	end
end

return ButtonManager
