local UserInputService = game:GetService("UserInputService")

local Slider = {}
Slider.__index = Slider

function Slider.new(parent, labelText, minVal, maxVal, stepVal, storeKey, suffix, Store, order)
    local self = setmetatable({}, Slider)
    self._connections = {}
    self.Min = minVal or 0
    self.Max = maxVal or 100
    self.Step = stepVal or 1
    self.Suffix = suffix or ""
    self.Value = Store and Store.Get(storeKey) or self.Min

    local Frame = Instance.new("Frame")
    Frame.Name = (labelText or "Slider") .. "Frame"
    Frame.Size = UDim2.new(1, 0, 0, 48)
    Frame.BackgroundTransparency = 1
    Frame.LayoutOrder = order or 1
    Frame.Parent = parent
    self.Frame = Frame

    local TopRow = Instance.new("Frame")
    TopRow.Size = UDim2.new(1, 0, 0, 20)
    TopRow.BackgroundTransparency = 1
    TopRow.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.7, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(220, 220, 230)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = TopRow

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0.3, 0, 1, 0)
    ValueLabel.Position = UDim2.new(0.7, 0, 0, 0)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Text = tostring(self.Value) .. self.Suffix
    ValueLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.TextSize = 12
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.Parent = TopRow

    local Track = Instance.new("TextButton")
    Track.Size = UDim2.new(1, 0, 0, 8)
    Track.Position = UDim2.new(0, 0, 0, 28)
    Track.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    Track.Text = ""
    Track.AutoButtonColor = false
    Track.Parent = Frame

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = Track

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(0, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    Fill.BorderSizePixel = 0
    Fill.Parent = Track

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(1, 0)
    fCorner.Parent = Fill

    local function updateVisual(val)
        local pct = math.clamp((val - self.Min) / (self.Max - self.Min), 0, 1)
        Fill.Size = UDim2.new(pct, 0, 1, 0)
        ValueLabel.Text = tostring(val) .. self.Suffix
    end

    updateVisual(self.Value)

    local dragging = false

    local function setValueFromX(x)
        local absPos = Track.AbsolutePosition.X
        local absSize = Track.AbsoluteSize.X
        if absSize <= 0 then return end
        local pct = math.clamp((x - absPos) / absSize, 0, 1)
        local rawVal = self.Min + (self.Max - self.Min) * pct
        local stepped = math.floor(rawVal / self.Step + 0.5) * self.Step
        if self.Step >= 1 then
            stepped = math.floor(stepped)
        else
            stepped = tonumber(string.format("%.2f", stepped))
        end
        self.Value = stepped
        updateVisual(stepped)
        if Store and storeKey then
            Store.Set(storeKey, stepped)
        end
    end

    local c1 = Track.MouseButton1Down:Connect(function()
        dragging = true
        setValueFromX(UserInputService:GetMouseLocation().X)
    end)
    table.insert(self._connections, c1)

    local c2 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    table.insert(self._connections, c2)

    local c3 = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setValueFromX(input.Position.X)
        end
    end)
    table.insert(self._connections, c3)

    return self
end

function Slider:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    if self.Frame then
        self.Frame:Destroy()
    end
end

return Slider
