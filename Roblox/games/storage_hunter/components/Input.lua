local Input = {}
Input.__index = Input

function Input.new(parent, labelText, storeKey, isNumber, Store, order)
    local self = setmetatable({}, Input)
    self._connections = {}
    self.IsNumber = isNumber or false
    self.Value = Store and Store.Get(storeKey) or ""

    local Row = Instance.new("Frame")
    Row.Name = (labelText or "Input") .. "Row"
    Row.Size = UDim2.new(1, 0, 0, 32)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = order or 1
    Row.Parent = parent
    self.Frame = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -110, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(225, 225, 235)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0, 100, 0, 24)
    Box.Position = UDim2.new(1, -100, 0.5, -12)
    Box.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.Text = tostring(self.Value)
    Box.Font = Enum.Font.GothamBold
    Box.TextSize = 12
    Box.ClearTextOnFocus = false
    Box.Parent = Row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 5)
    bCorner.Parent = Box

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Color3.fromRGB(45, 45, 55)
    bStroke.Thickness = 1
    bStroke.Parent = Box

    local conn = Box.FocusLost:Connect(function()
        local text = Box.Text
        local finalVal = text
        if self.IsNumber then
            finalVal = tonumber(text) or 0
            Box.Text = tostring(finalVal)
        end
        self.Value = finalVal
        if Store and storeKey then
            Store.Set(storeKey, finalVal)
        end
    end)
    table.insert(self._connections, conn)

    if Store and storeKey then
        local unsub = Store.Subscribe(storeKey, function(newVal)
            self.Value = newVal
            Box.Text = tostring(newVal)
        end)
        self._unsubscribe = unsub
    end

    return self
end

function Input:Destroy()
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

return Input
