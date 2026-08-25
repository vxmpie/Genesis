local Dropdown = {}
Dropdown.__index = Dropdown

function Dropdown.new(parent, labelText, options, isMulti, storeKey, Store, order)
    local self = setmetatable({}, Dropdown)
    self._connections = {}
    self._open = false
    self.Options = options or {}
    self.IsMulti = isMulti or false

    local currentVal = Store and Store.Get(storeKey)
    if self.IsMulti then
        self.Selected = type(currentVal) == "table" and currentVal or {}
    else
        self.Selected = currentVal or (self.Options[1] or "")
    end

    local Frame = Instance.new("Frame")
    Frame.Name = (labelText or "Dropdown") .. "Frame"
    Frame.Size = UDim2.new(1, 0, 0, 0)
    Frame.BackgroundTransparency = 1
    Frame.AutomaticSize = Enum.AutomaticSize.Y
    Frame.LayoutOrder = order or 1
    Frame.Parent = parent
    self.Frame = Frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = Frame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 18)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(220, 220, 230)
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.LayoutOrder = 1
    Label.Parent = Frame

    local MainBtn = Instance.new("TextButton")
    MainBtn.Size = UDim2.new(1, 0, 0, 32)
    MainBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    MainBtn.Text = ""
    MainBtn.AutoButtonColor = false
    MainBtn.LayoutOrder = 2
    MainBtn.Parent = Frame

    local mbCorner = Instance.new("UICorner")
    mbCorner.CornerRadius = UDim.new(0, 6)
    mbCorner.Parent = MainBtn

    local mbStroke = Instance.new("UIStroke")
    mbStroke.Color = Color3.fromRGB(45, 45, 55)
    mbStroke.Thickness = 1
    mbStroke.Parent = MainBtn

    local DisplayText = Instance.new("TextLabel")
    DisplayText.Size = UDim2.new(1, -30, 1, 0)
    DisplayText.Position = UDim2.new(0, 10, 0, 0)
    DisplayText.BackgroundTransparency = 1
    DisplayText.TextColor3 = Color3.fromRGB(255, 255, 255)
    DisplayText.Font = Enum.Font.GothamBold
    DisplayText.TextSize = 12
    DisplayText.TextXAlignment = Enum.TextXAlignment.Left
    DisplayText.TextTruncate = Enum.TextTruncate.AtEnd
    DisplayText.Parent = MainBtn

    local Arrow = Instance.new("TextLabel")
    Arrow.Size = UDim2.new(0, 20, 1, 0)
    Arrow.Position = UDim2.new(1, -25, 0, 0)
    Arrow.BackgroundTransparency = 1
    Arrow.Text = "▼"
    Arrow.TextColor3 = Color3.fromRGB(150, 150, 160)
    Arrow.Font = Enum.Font.GothamBold
    Arrow.TextSize = 10
    Arrow.Parent = MainBtn

    local ListScroll = Instance.new("ScrollingFrame")
    ListScroll.Size = UDim2.new(1, 0, 0, 120)
    ListScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    ListScroll.BorderSizePixel = 0
    ListScroll.ScrollBarThickness = 3
    ListScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ListScroll.Visible = false
    ListScroll.LayoutOrder = 3
    ListScroll.Parent = Frame

    local lsCorner = Instance.new("UICorner")
    lsCorner.CornerRadius = UDim.new(0, 6)
    lsCorner.Parent = ListScroll

    local lsStroke = Instance.new("UIStroke")
    lsStroke.Color = Color3.fromRGB(45, 45, 55)
    lsStroke.Thickness = 1
    lsStroke.Parent = ListScroll

    local lsLayout = Instance.new("UIListLayout")
    lsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    lsLayout.Padding = UDim.new(0, 2)
    lsLayout.Parent = ListScroll

    local function updateDisplayText()
        if self.IsMulti then
            local count = 0
            local names = {}
            for k, v in pairs(self.Selected) do
                if v == true then
                    count = count + 1
                    table.insert(names, k)
                end
            end
            if count == 0 then
                DisplayText.Text = "None selected"
            elseif count == 1 then
                DisplayText.Text = names[1]
            else
                DisplayText.Text = count .. " items selected"
            end
        else
            DisplayText.Text = tostring(self.Selected)
        end
    end

    local itemButtons = {}

    local function renderItems()
        for _, b in ipairs(itemButtons) do
            b:Destroy()
        end
        itemButtons = {}

        for idx, opt in ipairs(self.Options) do
            local itemBtn = Instance.new("TextButton")
            itemBtn.Size = UDim2.new(1, 0, 0, 26)
            itemBtn.BackgroundTransparency = 1
            itemBtn.Font = Enum.Font.GothamMedium
            itemBtn.TextSize = 12
            itemBtn.TextXAlignment = Enum.TextXAlignment.Left
            itemBtn.AutoButtonColor = false
            itemBtn.LayoutOrder = idx
            itemBtn.Parent = ListScroll

            local isSelected = false
            if self.IsMulti then
                isSelected = (self.Selected[opt] == true)
                itemBtn.Text = "   " .. (isSelected and "☑  " or "☐  ") .. opt
                itemBtn.TextColor3 = isSelected and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(180, 180, 190)
            else
                isSelected = (self.Selected == opt)
                itemBtn.Text = "   " .. (isSelected and "●  " or "○  ") .. opt
                itemBtn.TextColor3 = isSelected and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(180, 180, 190)
            end

            itemBtn.MouseButton1Click:Connect(function()
                if self.IsMulti then
                    self.Selected[opt] = not self.Selected[opt]
                    if Store and storeKey then
                        Store.Set(storeKey, self.Selected)
                    end
                    renderItems()
                    updateDisplayText()
                else
                    self.Selected = opt
                    if Store and storeKey then
                        Store.Set(storeKey, self.Selected)
                    end
                    renderItems()
                    updateDisplayText()
                    self._open = false
                    ListScroll.Visible = false
                    Arrow.Text = "▼"
                end
            end)

            table.insert(itemButtons, itemBtn)
        end
    end

    updateDisplayText()
    renderItems()

    local toggleConn = MainBtn.MouseButton1Click:Connect(function()
        self._open = not self._open
        ListScroll.Visible = self._open
        Arrow.Text = self._open and "▲" or "▼"
    end)
    table.insert(self._connections, toggleConn)

    return self
end

function Dropdown:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    if self.Frame then
        self.Frame:Destroy()
    end
end

return Dropdown
