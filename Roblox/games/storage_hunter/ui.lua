local UI = {}
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local function getSafeGuiParent()
    local success, parent = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function UI.Init(Config, DB, Modules)
    local parentGui = getSafeGuiParent()
    local existing = parentGui:FindFirstChild("GenesisObsidianUI")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisObsidianUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = parentGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 780, 0, 520)
    MainFrame.Position = UDim2.new(0.5, -390, 0.5, -260)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Thickness = 1.5
    MainStroke.Color = Color3.fromRGB(35, 35, 45)
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
    TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 10)
    TopCorner.Parent = TopBar

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(0, 240, 1, 0)
    Title.Position = UDim2.new(0, 16, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = "GENESIS  |  Storage Hunters"
    Title.TextColor3 = Color3.fromRGB(240, 240, 245)
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
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
    ContentArea.Name = "ContentArea"
    ContentArea.Size = UDim2.new(1, 0, 1, -42)
    ContentArea.Position = UDim2.new(0, 0, 0, 42)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = MainFrame

    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 160, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
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
    ViewContainer.Name = "ViewContainer"
    ViewContainer.Size = UDim2.new(1, -160, 1, 0)
    ViewContainer.Position = UDim2.new(0, 160, 0, 0)
    ViewContainer.BackgroundTransparency = 1
    ViewContainer.Parent = ContentArea

    local tabs = {
        {Name = "Info", Icon = "rbxassetid://10723415903"},
        {Name = "Farming", Icon = "rbxassetid://10723415903"},
        {Name = "Management", Icon = "rbxassetid://10723415903"},
        {Name = "Utilities", Icon = "rbxassetid://10723415903"},
        {Name = "Setting", Icon = "rbxassetid://10723415903"}
    }

    local tabButtons = {}
    local tabPages = {}

    local function createAccordionCard(parent, titleText)
        local card = Instance.new("Frame")
        card.Name = titleText .. "Card"
        card.Size = UDim2.new(1, 0, 0, 36)
        card.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.Parent = parent

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Thickness = 1
        cardStroke.Color = Color3.fromRGB(35, 35, 45)
        cardStroke.Parent = card

        local header = Instance.new("TextButton")
        header.Name = "Header"
        header.Size = UDim2.new(1, 0, 0, 36)
        header.BackgroundTransparency = 1
        header.Font = Enum.Font.GothamBold
        header.Text = "   " .. titleText
        header.TextColor3 = Color3.fromRGB(230, 230, 235)
        header.TextSize = 13
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = card

        local arrow = Instance.new("TextLabel")
        arrow.Name = "Arrow"
        arrow.Size = UDim2.new(0, 30, 1, 0)
        arrow.Position = UDim2.new(1, -30, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Font = Enum.Font.GothamBold
        arrow.Text = "v"
        arrow.TextColor3 = Color3.fromRGB(150, 150, 160)
        arrow.TextSize = 12
        arrow.Parent = header

        local content = Instance.new("Frame")
        content.Name = "Content"
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
                local neededHeight = contentList.AbsoluteContentSize.Y + 48
                TweenService:Create(card, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, neededHeight)}):Play()
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

        return content
    end

    local function createToggle(parent, labelText, configKey, defaultValue)
        local row = Instance.new("Frame")
        row.Name = labelText .. "Row"
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -45, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 38, 0, 20)
        btn.Position = UDim2.new(1, -38, 0.5, -10)
        btn.BackgroundColor3 = Config.Get(configKey, defaultValue) and Color3.fromRGB(30, 180, 90) or Color3.fromRGB(45, 45, 55)
        btn.Text = ""
        btn.Parent = row

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = btn

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = Config.Get(configKey, defaultValue) and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
        knob.Parent = btn

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        btn.MouseButton1Click:Connect(function()
            local cur = Config.Get(configKey, defaultValue)
            local nxt = not cur
            Config.Set(configKey, nxt)
            Config.Save()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = nxt and Color3.fromRGB(30, 180, 90) or Color3.fromRGB(45, 45, 55)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = nxt and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        end)
    end

    local function createButton(parent, labelText, onClick)
        local btn = Instance.new("TextButton")
        btn.Name = labelText .. "Btn"
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
        btn.Font = Enum.Font.GothamBold
        btn.Text = labelText
        btn.TextColor3 = Color3.fromRGB(230, 230, 240)
        btn.TextSize = 12
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if onClick then onClick() end
        end)
    end

    for idx, tabInfo in ipairs(tabs) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = tabInfo.Name .. "TabBtn"
        tabBtn.Size = UDim2.new(1, 0, 0, 34)
        tabBtn.BackgroundColor3 = idx == 1 and Color3.fromRGB(30, 30, 42) or Color3.fromRGB(20, 20, 28)
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.Text = "  " .. tabInfo.Name
        tabBtn.TextColor3 = idx == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160)
        tabBtn.TextSize = 13
        tabBtn.TextXAlignment = Enum.TextXAlignment.Left
        tabBtn.Parent = Sidebar

        local tabBtnCorner = Instance.new("UICorner")
        tabBtnCorner.CornerRadius = UDim.new(0, 6)
        tabBtnCorner.Parent = tabBtn

        local page = Instance.new("ScrollingFrame")
        page.Name = tabInfo.Name .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
        page.Visible = (idx == 1)
        page.Parent = ViewContainer

        local pageList = Instance.new("UIListLayout")
        pageList.FillDirection = Enum.FillDirection.Vertical
        pageList.SortOrder = Enum.SortOrder.LayoutOrder
        pageList.Padding = UDim.new(0, 8)
        pageList.Parent = page

        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingTop = UDim.new(0, 8)
        pagePad.PaddingBottom = UDim.new(0, 12)
        pagePad.PaddingLeft = UDim.new(0, 10)
        pagePad.PaddingRight = UDim.new(0, 10)
        pagePad.Parent = page

        pageList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, pageList.AbsoluteContentSize.Y + 24)
        end)

        tabButtons[tabInfo.Name] = tabBtn
        tabPages[tabInfo.Name] = page

        tabBtn.MouseButton1Click:Connect(function()
            for name, btn in pairs(tabButtons) do
                btn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
                btn.TextColor3 = Color3.fromRGB(150, 150, 160)
            end
            for name, p in pairs(tabPages) do
                p.Visible = false
            end
            tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            page.Visible = true
        end)
    end

    local infoPage = tabPages["Info"]
    local infoCard = createAccordionCard(infoPage, "System & Account Details")
    local accLbl = Instance.new("TextLabel")
    accLbl.Size = UDim2.new(1, 0, 0, 20)
    accLbl.BackgroundTransparency = 1
    accLbl.Font = Enum.Font.GothamMedium
    accLbl.Text = "Player: " .. LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")"
    accLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    accLbl.TextSize = 12
    accLbl.TextXAlignment = Enum.TextXAlignment.Left
    accLbl.Parent = infoCard

    local gameLbl = Instance.new("TextLabel")
    gameLbl.Size = UDim2.new(1, 0, 0, 20)
    gameLbl.BackgroundTransparency = 1
    gameLbl.Font = Enum.Font.GothamMedium
    gameLbl.Text = "Place ID: " .. tostring(game.PlaceId) .. " | Job ID: " .. string.sub(game.JobId, 1, 8) .. "..."
    gameLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    gameLbl.TextSize = 12
    gameLbl.TextXAlignment = Enum.TextXAlignment.Left
    gameLbl.Parent = infoCard

    local farmingPage = tabPages["Farming"]
    local generalCard = createAccordionCard(farmingPage, "General Automation")
    createToggle(generalCard, "Stop All Automation", "StopAllAutomation", false)
    createToggle(generalCard, "Auto Play (Start Screen)", "AutoPlay", true)
    createToggle(generalCard, "Auto Claim Available Plot", "AutoClaimPlot", true)

    local auctionCard = createAccordionCard(farmingPage, "Auctions & Bidding Engine")
    createToggle(auctionCard, "Auto Start Auction", "AutoStartAuction", false)
    createToggle(auctionCard, "Auto Bid", "AutoBid", false)
    createToggle(auctionCard, "Stop NPC Bid", "StopNPCBid", false)
    createToggle(auctionCard, "Auto X-Ray", "AutoXRay", false)
    createToggle(auctionCard, "Auto Calculator", "AutoCalculator", false)
    createToggle(auctionCard, "Auto Kick Top Bidder", "AutoKickTopBidder", false)

    local lootCard = createAccordionCard(farmingPage, "Loot & Safes")
    createToggle(lootCard, "Auto Collect World Loot", "AutoCollectWorldLoot", false)
    createToggle(lootCard, "Instant Collect (No Wind-Up)", "InstantCollect", true)
    createToggle(lootCard, "Auto Claim Auction Winnings", "AutoClaimAuctionWinnings", true)
    createToggle(lootCard, "Auto Open Safes (Locksmith)", "AutoOpenSafes", false)
    createToggle(lootCard, "Auto Picklock Safes", "AutoPicklockSafes", false)

    local fishingCard = createAccordionCard(farmingPage, "Fishing Automation")
    createToggle(fishingCard, "Auto Fish", "AutoFish", false)
    createToggle(fishingCard, "Speed Up Fishing", "SpeedUpFishing", false)
    createToggle(fishingCard, "Auto Reel", "AutoReel", false)

    local processingCard = createAccordionCard(farmingPage, "Processing (Wash, Repair, Grade)")
    createToggle(processingCard, "Auto Wash Items", "AutoWashItems", false)
    createToggle(processingCard, "Auto Repair Items", "AutoRepairItems", false)
    createToggle(processingCard, "Auto Grade Items (PSA)", "AutoGradeItems", false)
    createToggle(processingCard, "Auto Collect Finished Processing", "AutoCollectFinishedProcessing", true)

    local managePage = tabPages["Management"]
    local shopCard = createAccordionCard(managePage, "Shop Management")
    createToggle(shopCard, "Auto Sell (Quick Sell)", "AutoSell", false)
    createToggle(shopCard, "Auto Stock Shop Shelves", "AutoStockShopShelves", false)
    createToggle(shopCard, "Auto Accept NPC Offers", "AutoAcceptNPCOffers", false)
    createToggle(shopCard, "Auto Expand Shelf Slots", "AutoExpandShelfSlots", false)

    local rewardCard = createAccordionCard(managePage, "Rewards & Purchases")
    createToggle(rewardCard, "Auto Claim Daily Reward", "AutoClaimDailyReward", true)
    createToggle(rewardCard, "Auto Claim Achievements", "AutoClaimAchievements", true)
    createToggle(rewardCard, "Auto Claim Museum Rewards", "AutoClaimMuseumRewards", true)
    createToggle(rewardCard, "Auto Claim Club Quests", "AutoClaimClubQuests", true)
    createToggle(rewardCard, "Auto Buy Luck Energy Drinks", "AutoBuyLuckEnergyDrinks", false)

    local questsCard = createAccordionCard(managePage, "Quests & Reactor")
    createToggle(questsCard, "Enable Auto Quest Engine", "EnableAutoQuestEngine", false)
    createToggle(questsCard, "Auto Get Quests", "AutoGetQuests", false)
    createToggle(questsCard, "Auto Claim Quest Rewards", "AutoClaimQuestRewards", true)
    createToggle(questsCard, "Auto Install Reactor Parts", "AutoInstallReactorParts", false)

    local indexCard = createAccordionCard(managePage, "Collection Index")
    createToggle(indexCard, "Enable Auto Index Completion", "EnableAutoIndexCompletion", false)

    local utilPage = tabPages["Utilities"]
    local moveCard = createAccordionCard(utilPage, "Movement & Controls")
    createToggle(moveCard, "WalkSpeed Toggle (100)", "WalkSpeedToggle", false)
    createToggle(moveCard, "JumpPower Toggle (50)", "JumpPowerToggle", false)
    createToggle(moveCard, "Infinite Jump", "InfiniteJump", false)
    createToggle(moveCard, "Noclip", "Noclip", false)

    local tpCard = createAccordionCard(utilPage, "Teleport Network (23 POIs)")
    createButton(tpCard, "Teleport to Cleaning Shop", function()
        Modules.Utilities.TeleportTo("Item Cleaning Services (Wash)")
    end)
    createButton(tpCard, "Teleport to Repair Shop", function()
        Modules.Utilities.TeleportTo("Repair Shop")
    end)
    createButton(tpCard, "Teleport to Grading Store", function()
        Modules.Utilities.TeleportTo("Grading Store")
    end)
    createButton(tpCard, "Teleport to My Plot / Shop", function()
        Modules.Utilities.TeleportTo("My Plot / Shop")
    end)

    local optCard = createAccordionCard(utilPage, "Optimization & FPS")
    createToggle(optCard, "Delete Containers", "DeleteContainers", false)
    createToggle(optCard, "Delete Trees & Foliage", "DeleteTrees", false)
    createToggle(optCard, "Delete NPCs", "DeleteNPCs", false)
    createToggle(optCard, "Enable FPS Cap (360)", "EnableFPSCap", false)

    local settingPage = tabPages["Setting"]
    local menuCard = createAccordionCard(settingPage, "Menu & Anti-AFK")
    createToggle(menuCard, "Anti-AFK Guard", "AntiAFK", true)
    createButton(menuCard, "Export Config to Clipboard", function()
        Config.ExportClipboard()
    end)
    createButton(menuCard, "Unload Genesis Hub", function()
        ScreenGui:Destroy()
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftControl then
            MainFrame.Visible = not MainFrame.Visible
        end
    end)
end

return UI
