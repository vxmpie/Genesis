local Obsidian = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local function getGuiParent()
    local success, parent = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

Obsidian.Themes = {
    Monochrome = {
        Background = Color3.fromRGB(15, 15, 20),
        TopBar = Color3.fromRGB(20, 20, 26),
        Sidebar = Color3.fromRGB(18, 18, 24),
        CardBackground = Color3.fromRGB(22, 22, 30),
        CardBorder = Color3.fromRGB(35, 35, 45),
        Accent = Color3.fromRGB(240, 240, 245),
        Text = Color3.fromRGB(230, 230, 235),
        SubText = Color3.fromRGB(150, 150, 160),
        ToggleActive = Color3.fromRGB(220, 220, 225),
        ToggleInactive = Color3.fromRGB(45, 45, 55),
        KnobActive = Color3.fromRGB(20, 20, 25),
        KnobInactive = Color3.fromRGB(200, 200, 200)
    }
}

function Obsidian:CreateWindow(options)
    options = options or {}
    local TitleText = options.Title or "GENESIS"
    local SubTitleText = options.SubTitle or "v1.0"
    local TabWidth = options.TabWidth or 160
    local CurrentTheme = Obsidian.Themes.Monochrome

    local parent = getGuiParent()
    local existing = parent:FindFirstChild("ObsidianUI")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ObsidianUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = parent

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 800, 0, 540)
    MainFrame.Position = UDim2.new(0.5, -400, 0.5, -270)
    MainFrame.BackgroundColor3 = CurrentTheme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Thickness = 1.5
    MainStroke.Color = CurrentTheme.CardBorder
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
    TopBar.Size = UDim2.new(1, 0, 0, 42)
    TopBar.BackgroundColor3 = CurrentTheme.TopBar
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 10)
    TopCorner.Parent = TopBar

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(0, 300, 1, 0)
    TitleLbl.Position = UDim2.new(0, 16, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.Text = TitleText .. "  " .. SubTitleText
    TitleLbl.TextColor3 = CurrentTheme.Accent
    TitleLbl.TextSize = 14
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    CloseBtn.TextSize = 12
    CloseBtn.Parent = TopBar

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local ContentArea = Instance.new("Frame")
    ContentArea.Size = UDim2.new(1, 0, 1, -42)
    ContentArea.Position = UDim2.new(0, 0, 0, 42)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = MainFrame

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, TabWidth, 1, 0)
    Sidebar.BackgroundColor3 = CurrentTheme.Sidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = ContentArea

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.FillDirection = Enum.FillDirection.Vertical
    SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarList.Padding = UDim.new(0, 4)
    SidebarList.Parent = Sidebar

    local SidebarPad = Instance.new("UIPadding")
    SidebarPad.PaddingTop = UDim.new(0, 8)
    SidebarPad.PaddingLeft = UDim.new(0, 8)
    SidebarPad.PaddingRight = UDim.new(0, 8)
    SidebarPad.Parent = Sidebar

    local ViewContainer = Instance.new("Frame")
    ViewContainer.Size = UDim2.new(1, -TabWidth, 1, 0)
    ViewContainer.Position = UDim2.new(0, TabWidth, 0, 0)
    ViewContainer.BackgroundTransparency = 1
    ViewContainer.Parent = ContentArea

    local Window = {
        Tabs = {},
        ActiveTab = nil,
        ScreenGui = ScreenGui,
        MainFrame = MainFrame
    }

    function Window:AddTab(tabName, glyph)
        glyph = glyph or "[*]"
        local Tab = {
            Name = tabName,
            LeftGroups = {},
            RightGroups = {}
        }

        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, 0, 0, 34)
        TabBtn.BackgroundColor3 = #Window.Tabs == 0 and Color3.fromRGB(30, 30, 42) or Color3.fromRGB(20, 20, 28)
        TabBtn.Font = Enum.Font.GothamBold
        TabBtn.Text = "  " .. glyph .. "  " .. tabName
        TabBtn.TextColor3 = #Window.Tabs == 0 and CurrentTheme.Accent or CurrentTheme.SubText
        TabBtn.TextSize = 13
        TabBtn.TextXAlignment = Enum.TextXAlignment.Left
        TabBtn.Parent = Sidebar

        local TabBtnCorner = Instance.new("UICorner")
        TabBtnCorner.CornerRadius = UDim.new(0, 6)
        TabBtnCorner.Parent = TabBtn

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.ScrollBarThickness = 4
        TabPage.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
        TabPage.Visible = (#Window.Tabs == 0)
        TabPage.Parent = ViewContainer

        local ColumnsFrame = Instance.new("Frame")
        ColumnsFrame.Size = UDim2.new(1, 0, 1, 0)
        ColumnsFrame.BackgroundTransparency = 1
        ColumnsFrame.Parent = TabPage

        local LeftCol = Instance.new("Frame")
        LeftCol.Size = UDim2.new(0.5, -6, 1, 0)
        LeftCol.Position = UDim2.new(0, 8, 0, 8)
        LeftCol.BackgroundTransparency = 1
        LeftCol.Parent = ColumnsFrame

        local LeftList = Instance.new("UIListLayout")
        LeftList.FillDirection = Enum.FillDirection.Vertical
        LeftList.SortOrder = Enum.SortOrder.LayoutOrder
        LeftList.Padding = UDim.new(0, 8)
        LeftList.Parent = LeftCol

        local RightCol = Instance.new("Frame")
        RightCol.Size = UDim2.new(0.5, -14, 1, 0)
        RightCol.Position = UDim2.new(0.5, 6, 0, 8)
        RightCol.BackgroundTransparency = 1
        RightCol.Parent = ColumnsFrame

        local RightList = Instance.new("UIListLayout")
        RightList.FillDirection = Enum.FillDirection.Vertical
        RightList.SortOrder = Enum.SortOrder.LayoutOrder
        RightList.Padding = UDim.new(0, 8)
        RightList.Parent = RightCol

        local function updateCanvas()
            local leftH = LeftList.AbsoluteContentSize.Y
            local rightH = RightList.AbsoluteContentSize.Y
            local maxH = math.max(leftH, rightH)
            TabPage.CanvasSize = UDim2.new(0, 0, 0, maxH + 30)
        end
        LeftList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        RightList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

        TabBtn.MouseButton1Click:Connect(function()
            for _, t in ipairs(Window.Tabs) do
                t.Button.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
                t.Button.TextColor3 = CurrentTheme.SubText
                t.Page.Visible = false
            end
            TabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            TabBtn.TextColor3 = CurrentTheme.Accent
            TabPage.Visible = true
            Window.ActiveTab = Tab
        end)

        Tab.Button = TabBtn
        Tab.Page = TabPage

        local function createGroupbox(parentCol, groupTitle)
            local Groupbox = {}
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 36)
            card.BackgroundColor3 = CurrentTheme.CardBackground
            card.BorderSizePixel = 0
            card.ClipsDescendants = true
            card.Parent = parentCol

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 8)
            cardCorner.Parent = card

            local cardStroke = Instance.new("UIStroke")
            cardStroke.Thickness = 1
            cardStroke.Color = CurrentTheme.CardBorder
            cardStroke.Parent = card

            local header = Instance.new("TextButton")
            header.Size = UDim2.new(1, 0, 0, 36)
            header.BackgroundTransparency = 1
            header.Font = Enum.Font.GothamBold
            header.Text = "   [+] " .. groupTitle
            header.TextColor3 = CurrentTheme.Text
            header.TextSize = 13
            header.TextXAlignment = Enum.TextXAlignment.Left
            header.Parent = card

            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 30, 1, 0)
            arrow.Position = UDim2.new(1, -30, 0, 0)
            arrow.BackgroundTransparency = 1
            arrow.Font = Enum.Font.GothamBold
            arrow.Text = "v"
            arrow.TextColor3 = CurrentTheme.SubText
            arrow.TextSize = 12
            arrow.Parent = header

            local content = Instance.new("Frame")
            content.Size = UDim2.new(1, 0, 0, 0)
            content.Position = UDim2.new(0, 0, 0, 36)
            content.BackgroundTransparency = 1
            content.Parent = card

            local contentList = Instance.new("UIListLayout")
            contentList.FillDirection = Enum.FillDirection.Vertical
            contentList.SortOrder = Enum.SortOrder.LayoutOrder
            contentList.Padding = UDim.new(0, 6)
            contentList.Parent = content

            local contentPad = Instance.new("UIPadding")
            contentPad.PaddingTop = UDim.new(0, 6)
            contentPad.PaddingBottom = UDim.new(0, 8)
            contentPad.PaddingLeft = UDim.new(0, 10)
            contentPad.PaddingRight = UDim.new(0, 10)
            contentPad.Parent = content

            local isOpen = false
            local function toggleCard()
                isOpen = not isOpen
                arrow.Text = isOpen and "^" or "v"
                if isOpen then
                    local neededH = contentList.AbsoluteContentSize.Y + 48
                    TweenService:Create(card, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, neededH)}):Play()
                else
                    TweenService:Create(card, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 36)}):Play()
                end
            end
            header.MouseButton1Click:Connect(toggleCard)

            contentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                if isOpen then
                    card.Size = UDim2.new(1, 0, 0, contentList.AbsoluteContentSize.Y + 48)
                end
            end)

            function Groupbox:AddToggle(flag, opt)
                opt = opt or {}
                local text = opt.Text or flag
                local default = opt.Default or false
                local callback = opt.Callback or function() end

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 26)
                row.BackgroundTransparency = 1
                row.Parent = content

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, -45, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamMedium
                lbl.Text = text
                lbl.TextColor3 = CurrentTheme.Text
                lbl.TextSize = 12
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = row

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0, 38, 0, 20)
                btn.Position = UDim2.new(1, -38, 0.5, -10)
                btn.BackgroundColor3 = default and CurrentTheme.ToggleActive or CurrentTheme.ToggleInactive
                btn.Text = ""
                btn.Parent = row

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 10)
                corner.Parent = btn

                local knob = Instance.new("Frame")
                knob.Size = UDim2.new(0, 16, 0, 16)
                knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                knob.BackgroundColor3 = default and CurrentTheme.KnobActive or CurrentTheme.KnobInactive
                knob.Parent = btn

                local knobCorner = Instance.new("UICorner")
                knobCorner.CornerRadius = UDim.new(1, 0)
                knobCorner.Parent = knob

                local state = default
                btn.MouseButton1Click:Connect(function()
                    state = not state
                    TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = state and CurrentTheme.ToggleActive or CurrentTheme.ToggleInactive}):Play()
                    TweenService:Create(knob, TweenInfo.new(0.15), {
                        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                        BackgroundColor3 = state and CurrentTheme.KnobActive or CurrentTheme.KnobInactive
                    }):Play()
                    callback(state)
                end)
            end

            function Groupbox:AddButton(opt)
                opt = opt or {}
                local text = opt.Text or "Button"
                local callback = opt.Callback or function() end

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 28)
                btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
                btn.Font = Enum.Font.GothamBold
                btn.Text = text
                btn.TextColor3 = CurrentTheme.Text
                btn.TextSize = 12
                btn.Parent = content

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 6)
                corner.Parent = btn

                btn.MouseButton1Click:Connect(callback)
            end

            function Groupbox:AddLabel(text)
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 0, 22)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamMedium
                lbl.Text = text
                lbl.TextColor3 = CurrentTheme.SubText
                lbl.TextSize = 12
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = content
                return lbl
            end

            function Groupbox:AddInput(flag, opt)
                opt = opt or {}
                local text = opt.Text or flag
                local default = opt.Default or ""
                local callback = opt.Callback or function() end

                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1, 0, 0, 28)
                box.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
                box.Font = Enum.Font.GothamMedium
                box.Text = tostring(default)
                box.PlaceholderText = text
                box.TextColor3 = CurrentTheme.Text
                box.PlaceholderColor3 = CurrentTheme.SubText
                box.TextSize = 12
                box.Parent = content

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 6)
                corner.Parent = box

                box.FocusLost:Connect(function()
                    callback(box.Text)
                end)
            end

            return Groupbox
        end

        function Tab:AddLeftGroupbox(title)
            return createGroupbox(LeftCol, title)
        end

        function Tab:AddRightGroupbox(title)
            return createGroupbox(RightCol, title)
        end

        table.insert(Window.Tabs, Tab)
        return Tab
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftControl then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)

    return Window
end

return Obsidian
