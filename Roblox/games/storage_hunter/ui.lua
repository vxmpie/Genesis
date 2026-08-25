local UI = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local function getGuiParent()
    local success, parent = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function UI.Create(Config, WashModule, AntiAFK)
    local parent = getGuiParent()
    local existing = parent:FindFirstChild("GenesisCustomUI")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisCustomUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 9999
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Parent = parent

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 480, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -240, 0.5, -210)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Thickness = 1.5
    MainStroke.Color = Color3.fromRGB(38, 38, 50)
    MainStroke.Parent = MainFrame

    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 10)
    TopCorner.Parent = TopBar

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -50, 1, 0)
    TitleLbl.Position = UDim2.new(0, 16, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.Text = "[+] GENESIS  |  Storage Hunters"
    TitleLbl.TextColor3 = Color3.fromRGB(240, 240, 245)
    TitleLbl.TextSize = 13
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    CloseBtn.TextSize = 12
    CloseBtn.Parent = TopBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local ScrollContainer = Instance.new("ScrollingFrame")
    ScrollContainer.Size = UDim2.new(1, -20, 1, -54)
    ScrollContainer.Position = UDim2.new(0, 10, 0, 48)
    ScrollContainer.BackgroundTransparency = 1
    ScrollContainer.ScrollBarThickness = 4
    ScrollContainer.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 70)
    ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, 460)
    ScrollContainer.Parent = MainFrame

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.FillDirection = Enum.FillDirection.Vertical
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Padding = UDim.new(0, 10)
    ContentLayout.Parent = ScrollContainer

    local function createCard(title)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 36)
        card.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.Parent = ScrollContainer

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Thickness = 1
        cardStroke.Color = Color3.fromRGB(35, 35, 45)
        cardStroke.Parent = card

        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 36)
        header.BackgroundTransparency = 1
        header.Font = Enum.Font.GothamBold
        header.Text = "   [*] " .. title
        header.TextColor3 = Color3.fromRGB(230, 230, 235)
        header.TextSize = 13
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = card

        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 30, 1, 0)
        arrow.Position = UDim2.new(1, -30, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Font = Enum.Font.GothamBold
        arrow.Text = "^"
        arrow.TextColor3 = Color3.fromRGB(150, 150, 160)
        arrow.TextSize = 12
        arrow.Parent = header

        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, 0, 0, 0)
        content.Position = UDim2.new(0, 0, 0, 36)
        content.BackgroundTransparency = 1
        content.Parent = card

        local contentLayout = Instance.new("UIListLayout")
        contentLayout.FillDirection = Enum.FillDirection.Vertical
        contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        contentLayout.Padding = UDim.new(0, 6)
        contentLayout.Parent = content

        local contentPad = Instance.new("UIPadding")
        contentPad.PaddingTop = UDim.new(0, 6)
        contentPad.PaddingBottom = UDim.new(0, 10)
        contentPad.PaddingLeft = UDim.new(0, 12)
        contentPad.PaddingRight = UDim.new(0, 12)
        contentPad.Parent = content

        local isOpen = true
        local function updateCardSize()
            if isOpen then
                local h = contentLayout.AbsoluteContentSize.Y + 50
                card.Size = UDim2.new(1, 0, 0, h)
                arrow.Text = "^"
            else
                card.Size = UDim2.new(1, 0, 0, 36)
                arrow.Text = "v"
            end
        end

        header.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            updateCardSize()
        end)

        contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCardSize)

        local CardObj = {
            Content = content,
            Card = card
        }

        function CardObj:AddToggle(text, default, callback)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 26)
            row.BackgroundTransparency = 1
            row.Parent = content

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -45, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(220, 220, 225)
            lbl.TextSize = 12
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = row

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 38, 0, 20)
            btn.Position = UDim2.new(1, -38, 0.5, -10)
            btn.BackgroundColor3 = default and Color3.fromRGB(220, 220, 225) or Color3.fromRGB(45, 45, 55)
            btn.Text = ""
            btn.Parent = row

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 10)
            btnCorner.Parent = btn

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            knob.BackgroundColor3 = default and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(200, 200, 200)
            knob.Parent = btn

            local knobCorner = Instance.new("UICorner")
            knobCorner.CornerRadius = UDim.new(1, 0)
            knobCorner.Parent = knob

            local state = default
            btn.MouseButton1Click:Connect(function()
                state = not state
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = state and Color3.fromRGB(220, 220, 225) or Color3.fromRGB(45, 45, 55)
                }):Play()
                TweenService:Create(knob, TweenInfo.new(0.15), {
                    Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                    BackgroundColor3 = state and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(200, 200, 200)
                }):Play()
                callback(state)
            end)
        end

        function CardObj:AddButton(text, callback)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
            btn.Font = Enum.Font.GothamBold
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(230, 230, 235)
            btn.TextSize = 12
            btn.Parent = content

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn

            btn.MouseButton1Click:Connect(callback)
        end

        function CardObj:AddLabel(text)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 20)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamMedium
            lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(150, 150, 160)
            lbl.TextSize = 12
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = content
            return lbl
        end

        return CardObj
    end

    local washCard = createCard("Auto Wash Automation")
    washCard:AddToggle("Enable Auto Wash Loop", Config.Get("AutoWash", false), function(val)
        Config.Set("AutoWash", val)
        Config.Save()
        if val then
            WashModule.StartAutoWashLoop(Config.GetState())
        else
            WashModule.StopAutoWashLoop()
        end
    end)
    washCard:AddButton("Instant Quick Wash (1-Shot)", function()
        WashModule.ProcessWash(Config.GetState())
    end)

    local rarityCard = createCard("Wash Rarities Filter")
    local state = Config.GetState()
    local rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Lost", "Exclusive"}
    for _, r in ipairs(rarities) do
        local isAllowed = (state.WashRarities and state.WashRarities[r] ~= nil) and state.WashRarities[r] or true
        rarityCard:AddToggle(r .. " Items", isAllowed, function(val)
            if not state.WashRarities then state.WashRarities = {} end
            state.WashRarities[r] = val
            Config.Save()
        end)
    end

    local safetyCard = createCard("Safety & System Guard")
    safetyCard:AddToggle("Anti-AFK (ตรวจตัวยืนนิ่ง)", Config.Get("AntiAFK", true), function(val)
        Config.Set("AntiAFK", val)
        Config.Save()
    end)
    safetyCard:AddButton("Unload Genesis", function()
        WashModule.StopAutoWashLoop()
        AntiAFK.Destroy()
        ScreenGui:Destroy()
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftControl then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "GENESIS",
            Text = "Genesis Custom UI Loaded! Press LeftControl to Toggle.",
            Duration = 5
        })
    end)
end

return UI
