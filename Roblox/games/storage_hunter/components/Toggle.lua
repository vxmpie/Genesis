local Toggle = {}
Toggle.__index = Toggle

function Toggle.new(parent, labelText, storeKey, Store, order)
    local self = setmetatable({}, Toggle)
    self._connections = {}
    self.Value = Store and Store.Get(storeKey) or false

    local Row = Instance.new("Frame")
    Row.Name = (labelText or "Toggle") .. "Row"
    Row.Size = UDim2.new(1, 0, 0, 30)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = order or 1
    Row.Parent = parent
    self.Frame = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -55, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(225, 225, 235)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 46, 0, 22)
    Btn.Position = UDim2.new(1, -46, 0.5, -11)
    Btn.Text = ""
    Btn.AutoButtonColor = false
    Btn.Parent = Row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(1, 0)
    bCorner.Parent = Btn

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 16, 0, 16)
    Circle.Parent = Btn

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(1, 0)
    cCorner.Parent = Circle

    local function render(val)
        self.Value = val
        if val then
            Btn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
            Circle.Position = UDim2.new(1, -19, 0.5, -8)
            Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
            Circle.Position = UDim2.new(0, 3, 0.5, -8)
            Circle.BackgroundColor3 = Color3.fromRGB(150, 150, 160)
        end
    end

    render(self.Value)

    local conn = Btn.MouseButton1Click:Connect(function()
        local newVal = not self.Value
        render(newVal)
        if Store and storeKey then
            Store.Set(storeKey, newVal)
        end
    end)
    table.insert(self._connections, conn)

    if Store and storeKey then
        local unsub = Store.Subscribe(storeKey, function(newVal)
            render(newVal)
        end)
        self._unsubscribe = unsub
    end

    return self
end

function Toggle:Destroy()
    if self._unsubscribe then
        self._unsubscribe()
    end
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    if self.Frame then
        self.Frame:Destroy()
    end
end

return Toggle
