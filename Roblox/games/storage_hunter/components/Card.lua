local Card = {}
Card.__index = Card

function Card.new(parent, titleText, iconText, order)
    local self = setmetatable({}, Card)
    self._collapsed = false

    local Frame = Instance.new("Frame")
    Frame.Name = (titleText or "Card") .. "Card"
    Frame.Size = UDim2.new(1, 0, 0, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    Frame.AutomaticSize = Enum.AutomaticSize.Y
    Frame.LayoutOrder = order or 1
    Frame.Parent = parent
    self.Frame = Frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = Frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(34, 34, 42)
    stroke.Thickness = 1
    stroke.Parent = Frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = Frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = Frame

    if titleText then
        local Header = Instance.new("TextButton")
        Header.Name = "Header"
        Header.Size = UDim2.new(1, 0, 0, 22)
        Header.BackgroundTransparency = 1
        Header.Text = ""
        Header.LayoutOrder = 0
        Header.Parent = Frame

        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size = UDim2.new(1, -25, 1, 0)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Text = (iconText and (iconText .. "  ") or "") .. titleText:upper()
        TitleLabel.TextColor3 = Color3.fromRGB(255, 65, 65)
        TitleLabel.Font = Enum.Font.GothamBlack
        TitleLabel.TextSize = 12
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.Parent = Header

        local Chevron = Instance.new("TextLabel")
        Chevron.Size = UDim2.new(0, 20, 1, 0)
        Chevron.Position = UDim2.new(1, -20, 0, 0)
        Chevron.BackgroundTransparency = 1
        Chevron.Text = "▼"
        Chevron.TextColor3 = Color3.fromRGB(150, 150, 170)
        Chevron.Font = Enum.Font.GothamBold
        Chevron.TextSize = 10
        Chevron.Parent = Header

        local Content = Instance.new("Frame")
        Content.Name = "Content"
        Content.Size = UDim2.new(1, 0, 0, 0)
        Content.BackgroundTransparency = 1
        Content.AutomaticSize = Enum.AutomaticSize.Y
        Content.LayoutOrder = 1
        Content.Parent = Frame
        self.Content = Content

        local cLayout = Instance.new("UIListLayout")
        cLayout.SortOrder = Enum.SortOrder.LayoutOrder
        cLayout.Padding = UDim.new(0, 8)
        cLayout.Parent = Content

        Header.MouseButton1Click:Connect(function()
            self._collapsed = not self._collapsed
            Content.Visible = not self._collapsed
            Chevron.Text = self._collapsed and "▲" or "▼"
        end)
    else
        self.Content = Frame
    end

    return self
end

function Card:Destroy()
    if self.Frame then
        self.Frame:Destroy()
    end
end

return Card
