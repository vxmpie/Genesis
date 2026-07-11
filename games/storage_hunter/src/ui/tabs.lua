local UI = {}

function UI.createTab(Sidebar, ContentArea, Tabs, name, order)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -20)
    scroll.Position = UDim2.new(0, 10, 0, 10)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
    scroll.Visible = false
    scroll.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = scroll

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 42)
    btn.Position = UDim2.new(0, 10, 0, 70 + (order * 50))
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    btn.TextColor3 = Color3.fromRGB(150, 150, 160)
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(40, 40, 50)
    stroke.Thickness = 1

    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do 
            t.scroll.Visible = false 
            t.btn.TextColor3 = Color3.fromRGB(150, 150, 160)
            t.btn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
            t.stroke.Color = Color3.fromRGB(40, 40, 50)
        end
        scroll.Visible = true
        btn.TextColor3 = Color3.fromRGB(255, 60, 60)
        btn.BackgroundColor3 = Color3.fromRGB(35, 25, 30)
        stroke.Color = Color3.fromRGB(255, 60, 60)
    end)

    table.insert(Tabs, {scroll = scroll, btn = btn, stroke = stroke})
    return scroll
end

function UI.createHeader(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.upper(text)
    lbl.TextColor3 = Color3.fromRGB(100, 100, 115)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
end

function UI.createToggle(parent, text, defaultState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 20, 0, 20)
    box.Position = UDim2.new(1, -30, 0.5, -10)
    box.BackgroundColor3 = defaultState and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(45, 45, 55)
    box.Text = ""
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 15, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local state = defaultState
    local function toggle()
        state = not state
        box.BackgroundColor3 = state and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(45, 45, 55)
        callback(state)
    end
    box.MouseButton1Click:Connect(toggle)
    
    local hiddenBtn = Instance.new("TextButton")
    hiddenBtn.Size = UDim2.new(1, -40, 1, 0)
    hiddenBtn.BackgroundTransparency = 1
    hiddenBtn.Text = ""
    hiddenBtn.Parent = frame
    hiddenBtn.MouseButton1Click:Connect(toggle)
end

function UI.createInput(parent, text, placeholder, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 15, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.4, 0, 0, 30)
    box.Position = UDim2.new(1, -15 - (box.Size.X.Scale * frame.AbsoluteSize.X or 150), 0.5, -15)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderText = placeholder
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.Text = ""
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke", box)
    stroke.Color = Color3.fromRGB(50, 50, 60)
    stroke.Thickness = 1

    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
    
    box:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        box.Position = UDim2.new(1, -15 - box.AbsoluteSize.X, 0.5, -15)
    end)
    return box
end

function UI.createActionButton(parent, text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = color or Color3.fromRGB(45, 45, 55)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

return UI