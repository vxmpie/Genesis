local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local UI = {}

local RARITY_COLORS = {
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(80, 220, 100),
    Rare = Color3.fromRGB(60, 150, 255),
    Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 180, 40),
    Mythic = Color3.fromRGB(255, 60, 120),
    Exotic = Color3.fromRGB(0, 230, 230),
    Secret = Color3.fromRGB(255, 220, 80),
}

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Secret" }

local AUCTION_AREAS = {
    "Shipyard", "Jurassic", "Business Bay", "Farmyard", "Back Alley", 
    "Lucky Beach", "Alien Invasion", "Power Plant", "Cargo Ship", "Junk Yard"
}

function UI.Create(Store, EventBus, Components, Modules)
    local Card = Components.Card
    local Toggle = Components.Toggle
    local Slider = Components.Slider
    local Dropdown = Components.Dropdown
    local Input = Components.Input

    local ResetModule = Modules.ResetModule
    local AuctionModule = Modules.AuctionModule
    local WashModule = Modules.WashModule
    local RepairModule = Modules.RepairModule
    local GradingModule = Modules.GradingModule
    local LocksmithModule = Modules.LocksmithModule
    local StockModule = Modules.StockModule
    local RewardsModule = Modules.RewardsModule
    local TeleportModule = Modules.TeleportModule
    local UtilsModule = Modules.UtilsModule

    if CoreGui:FindFirstChild("GenesisHubGUI") then
        CoreGui.GenesisHubGUI:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisHubGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = "FloatingBtn"
    FloatingBtn.Size = UDim2.new(0, 46, 0, 46)
    FloatingBtn.Position = UDim2.new(1, -60, 0.5, -23)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    FloatingBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
    FloatingBtn.Text = "G"
    FloatingBtn.Font = Enum.Font.GothamBlack
    FloatingBtn.TextSize = 24
    FloatingBtn.AutoButtonColor = false
    FloatingBtn.Draggable = true
    FloatingBtn.Parent = ScreenGui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(1, 0)
    floatCorner.Parent = FloatingBtn

    local floatStroke = Instance.new("UIStroke")
    floatStroke.Color = Color3.fromRGB(255, 60, 60)
    floatStroke.Thickness = 2
    floatStroke.Parent = FloatingBtn

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 760, 0, 480)
    MainFrame.Position = UDim2.new(0.5, -380, 0.5, -240)
    MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = MainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(35, 35, 45)
    mainStroke.Thickness = 1
    mainStroke.Parent = MainFrame

    FloatingBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 185, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 21)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame

    local sideCorner = Instance.new("UICorner")
    sideCorner.CornerRadius = UDim.new(0, 10)
    sideCorner.Parent = Sidebar

    local sideFix = Instance.new("Frame")
    sideFix.Size = UDim2.new(0, 10, 1, 0)
    sideFix.Position = UDim2.new(1, -10, 0, 0)
    sideFix.BackgroundColor3 = Color3.fromRGB(16, 16, 21)
    sideFix.BorderSizePixel = 0
    sideFix.Parent = Sidebar

    local LogoHeader = Instance.new("Frame")
    LogoHeader.Size = UDim2.new(1, 0, 0, 50)
    LogoHeader.BackgroundTransparency = 1
    LogoHeader.Parent = Sidebar

    local LogoDot = Instance.new("Frame")
    LogoDot.Size = UDim2.new(0, 10, 0, 10)
    LogoDot.Position = UDim2.new(0, 14, 0.5, -5)
    LogoDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    LogoDot.BorderSizePixel = 0
    LogoDot.Parent = LogoHeader

    local ldCorner = Instance.new("UICorner")
    ldCorner.CornerRadius = UDim.new(1, 0)
    ldCorner.Parent = LogoDot

    local LogoText = Instance.new("TextLabel")
    LogoText.Size = UDim2.new(1, -35, 1, 0)
    LogoText.Position = UDim2.new(0, 32, 0, 0)
    LogoText.BackgroundTransparency = 1
    LogoText.Text = "GENESIS HUB"
    LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    LogoText.Font = Enum.Font.GothamBlack
    LogoText.TextSize = 15
    LogoText.TextXAlignment = Enum.TextXAlignment.Left
    LogoText.Parent = LogoHeader

    local NavScroll = Instance.new("ScrollingFrame")
    NavScroll.Size = UDim2.new(1, -12, 1, -60)
    NavScroll.Position = UDim2.new(0, 6, 0, 52)
    NavScroll.BackgroundTransparency = 1
    NavScroll.ScrollBarThickness = 2
    NavScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    NavScroll.BorderSizePixel = 0
    NavScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    NavScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    NavScroll.Parent = Sidebar

    local navLayout = Instance.new("UIListLayout")
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 4)
    navLayout.Parent = NavScroll

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, -185, 0, 50)
    TopBar.Position = UDim2.new(0, 185, 0, 0)
    TopBar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TabTitle = Instance.new("TextLabel")
    TabTitle.Size = UDim2.new(0, 220, 1, 0)
    TabTitle.Position = UDim2.new(0, 16, 0, 0)
    TabTitle.BackgroundTransparency = 1
    TabTitle.Text = "Dashboard & Info"
    TabTitle.TextColor3 = Color3.fromRGB(245, 245, 250)
    TabTitle.Font = Enum.Font.GothamBold
    TabTitle.TextSize = 16
    TabTitle.TextXAlignment = Enum.TextXAlignment.Left
    TabTitle.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 22, 25)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 85, 85)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 13
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = TopBar

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 6)
    cbCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    local PagesContainer = Instance.new("Frame")
    PagesContainer.Size = UDim2.new(1, -195, 1, -58)
    PagesContainer.Position = UDim2.new(0, 190, 0, 54)
    PagesContainer.BackgroundTransparency = 1
    PagesContainer.Parent = MainFrame

    local TabPages = {}
    local TabButtons = {}

    local function createTwoColumnPage(tabId, titleName)
        local Page = Instance.new("ScrollingFrame")
        Page.Name = tabId .. "Page"
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.ScrollBarThickness = 3
        Page.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
        Page.BorderSizePixel = 0
        Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Page.CanvasSize = UDim2.new(0, 0, 0, 0)
        Page.Visible = false
        Page.Parent = PagesContainer

        local Grid = Instance.new("Frame")
        Grid.Size = UDim2.new(1, -8, 1, 0)
        Grid.BackgroundTransparency = 1
        Grid.AutomaticSize = Enum.AutomaticSize.Y
        Grid.Parent = Page

        local LeftCol = Instance.new("Frame")
        LeftCol.Size = UDim2.new(0.49, 0, 0, 0)
        LeftCol.Position = UDim2.new(0, 0, 0, 0)
        LeftCol.BackgroundTransparency = 1
        LeftCol.AutomaticSize = Enum.AutomaticSize.Y
        LeftCol.Parent = Grid

        local lLayout = Instance.new("UIListLayout")
        lLayout.SortOrder = Enum.SortOrder.LayoutOrder
        lLayout.Padding = UDim.new(0, 8)
        lLayout.Parent = LeftCol

        local RightCol = Instance.new("Frame")
        RightCol.Size = UDim2.new(0.49, 0, 0, 0)
        RightCol.Position = UDim2.new(0.51, 0, 0, 0)
        RightCol.BackgroundTransparency = 1
        RightCol.AutomaticSize = Enum.AutomaticSize.Y
        RightCol.Parent = Grid

        local rLayout = Instance.new("UIListLayout")
        rLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rLayout.Padding = UDim.new(0, 8)
        rLayout.Parent = RightCol

        TabPages[tabId] = { Page = Page, Left = LeftCol, Right = RightCol, Title = titleName }
        return LeftCol, RightCol
    end

    local function switchTab(tabId)
        for id, tab in pairs(TabPages) do
            tab.Page.Visible = (id == tabId)
            if id == tabId then
                TabTitle.Text = tab.Title
            end
        end
        for id, btn in pairs(TabButtons) do
            if id == tabId then
                btn.BackgroundColor3 = Color3.fromRGB(35, 24, 28)
                btn.TextColor3 = Color3.fromRGB(255, 75, 75)
            else
                btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                btn.TextColor3 = Color3.fromRGB(160, 160, 175)
            end
        end
    end

    local function createNavBtn(tabId, icon, label, order)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 34)
        Btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        Btn.Text = "  " .. icon .. "  " .. label
        Btn.TextColor3 = Color3.fromRGB(160, 160, 175)
        Btn.Font = Enum.Font.GothamBold
        Btn.TextSize = 12
        Btn.TextXAlignment = Enum.TextXAlignment.Left
        Btn.AutoButtonColor = false
        Btn.LayoutOrder = order
        Btn.Parent = NavScroll

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = Btn

        Btn.MouseButton1Click:Connect(function()
            switchTab(tabId)
        end)

        TabButtons[tabId] = Btn
        return Btn
    end

    createNavBtn("Info", "ℹ", "Info & Live Status", 1)
    createNavBtn("Auctions", "🔨", "Auctions & Bidding", 2)
    createNavBtn("Processing", "🧼", "Item Processing", 3)
    createNavBtn("Shop", "🏪", "Shop, Stock & Sell", 4)
    createNavBtn("Rewards", "🎁", "Rewards & Quests", 5)
    createNavBtn("Teleport", "🗺", "Map & Teleports", 6)
    createNavBtn("Utilities", "🔧", "Utilities & Guard", 7)
    createNavBtn("Settings", "⚙", "Settings & Unload", 8)

    local infoL, infoR = createTwoColumnPage("Info", "Dashboard & Info")
    
    local accCard = Card.new(infoL, "Account & Session", "👤", 1)
    local function addRow(parent, lText, rText)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 20)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.45, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = lText
        l.TextColor3 = Color3.fromRGB(140, 140, 155)
        l.Font = Enum.Font.GothamMedium
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = row

        local r = Instance.new("TextLabel")
        r.Size = UDim2.new(0.55, 0, 1, 0)
        r.Position = UDim2.new(0.45, 0, 0, 0)
        r.BackgroundTransparency = 1
        r.Text = rText
        r.TextColor3 = Color3.fromRGB(240, 240, 250)
        r.Font = Enum.Font.GothamBold
        r.TextSize = 12
        r.TextXAlignment = Enum.TextXAlignment.Left
        r.Parent = row
    end

    addRow(accCard.Content, "User", LocalPlayer.Name)
    addRow(accCard.Content, "Game", "Storage Hunters")
    addRow(accCard.Content, "Place ID", tostring(game.PlaceId))
    addRow(accCard.Content, "Status", "Keyless / Premium")

    local statusCard = Card.new(infoR, "Live Telemetry Dashboard", "📊", 1)
    addRow(statusCard.Content, "Auction State", "Active Tracking")
    addRow(statusCard.Content, "Fast Loot", "Direct Bypass Ready")
    addRow(statusCard.Content, "Wash Pipeline", "Reactive Ready")
    addRow(statusCard.Content, "Watchdog", "Guard Active")

    local aucL, aucR = createTwoColumnPage("Auctions", "Auctions & Bidding")
    local aucMainCard = Card.new(aucL, "Auction Automation", "🔨", 1)
    Toggle.new(aucMainCard.Content, "Auto Bid", "AutoBid", Store, 1)
    Toggle.new(aucMainCard.Content, "Fast Loot (Instant Pickup)", "FastPickup", Store, 2)
    Toggle.new(aucMainCard.Content, "Auto Enter Auctions", "AutoEnterAuctions", Store, 3)
    Dropdown.new(aucMainCard.Content, "Target Auction Area", AUCTION_AREAS, false, "AuctionArea", Store, 4)
    Input.new(aucMainCard.Content, "Minimum Bid ($)", "MinimumBid", true, Store, 5)
    Input.new(aucMainCard.Content, "Maximum Bid ($)", "MaximumBid", true, Store, 6)

    local aucPowerCard = Card.new(aucR, "Auction Powers & NPC", "⚡", 1)
    Toggle.new(aucPowerCard.Content, "Auto Use X-Ray", "AutoXRay", Store, 1)
    Toggle.new(aucPowerCard.Content, "Auto Use Calculator", "AutoCalculator", Store, 2)
    Toggle.new(aucPowerCard.Content, "Auto Kick Top NPC Bidder", "AutoKickNPC", Store, 3)
    Toggle.new(aucPowerCard.Content, "Always Grab Mutated Items", "AlwaysGrabMutated", Store, 4)
    Slider.new(aucPowerCard.Content, "Bid Delay", 0.05, 1, 0.05, "BidDelay", "s", Store, 5)

    local procL, procR = createTwoColumnPage("Processing", "Item Processing Pipeline")
    local washCard = Card.new(procL, "Auto Wash (Cleaning)", "🧼", 1)
    Toggle.new(washCard.Content, "Auto Wash Items", "AutoWash", Store, 1)

    local RarityGrid = Instance.new("Frame")
    RarityGrid.Size = UDim2.new(1, 0, 0, 68)
    RarityGrid.BackgroundTransparency = 1
    RarityGrid.LayoutOrder = 2
    RarityGrid.Parent = washCard.Content

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.23, 0, 0, 30)
    gridLayout.CellPadding = UDim2.new(0.02, 0, 0, 6)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = RarityGrid

    local washRarities = Store.Get("WashRarities") or {}
    for idx, rarity in ipairs(RARITIES) do
        local rBtn = Instance.new("TextButton")
        rBtn.Size = UDim2.new(1, 0, 1, 0)
        rBtn.Text = rarity
        rBtn.Font = Enum.Font.GothamBold
        rBtn.TextSize = 10
        rBtn.AutoButtonColor = false
        rBtn.LayoutOrder = idx
        rBtn.Parent = RarityGrid

        local rbCorner = Instance.new("UICorner")
        rbCorner.CornerRadius = UDim.new(0, 5)
        rbCorner.Parent = rBtn

        local rbStroke = Instance.new("UIStroke")
        rbStroke.Thickness = 1
        rbStroke.Parent = rBtn

        local col = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)

        local function updateR()
            local on = washRarities[rarity] == true
            if on then
                rBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
                rBtn.TextColor3 = col
                rbStroke.Color = col
            else
                rBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                rBtn.TextColor3 = Color3.fromRGB(75, 75, 85)
                rbStroke.Color = Color3.fromRGB(35, 35, 45)
            end
        end

        updateR()

        rBtn.MouseButton1Click:Connect(function()
            washRarities[rarity] = not washRarities[rarity]
            Store.Set("WashRarities", washRarities)
            updateR()
        end)
    end

    local repCard = Card.new(procR, "Repair & Grading & Safes", "🔧", 1)
    Toggle.new(repCard.Content, "Auto Repair Slots", "AutoRepair", Store, 1)
    Toggle.new(repCard.Content, "Auto Wrench Won Items", "AutoWrench", Store, 2)
    Toggle.new(repCard.Content, "Auto Grade PSA", "AutoGrade", Store, 3)
    Toggle.new(repCard.Content, "Auto Locksmith Slots", "AutoLocksmith", Store, 4)
    Toggle.new(repCard.Content, "Auto Picklock Inventory Safes", "AutoOpenSafes", Store, 5)
    Toggle.new(repCard.Content, "Auto Authenticate Items", "AutoAuthenticate", Store, 6)

    local shopL, shopR = createTwoColumnPage("Shop", "Shop, Stocking & Selling")
    local stockCard = Card.new(shopL, "Shelves & Stocking", "🏪", 1)
    Toggle.new(stockCard.Content, "Auto Stock Shelves", "AutoStock", Store, 1)
    Slider.new(stockCard.Content, "Stock Price Multiplier", 100, 300, 10, "StockPricePercent", "%", Store, 2)

    local sellCard = Card.new(shopR, "Liquidation & Pawn", "💲", 1)
    Toggle.new(sellCard.Content, "Auto Sell to Pawn Shop", "AutoSell", Store, 1)

    local rewL, rewR = createTwoColumnPage("Rewards", "Rewards, Quests & Events")
    local rewCard = Card.new(rewL, "Automated Claims", "🎁", 1)
    Toggle.new(rewCard.Content, "Auto Collect Museum Yield", "AutoMuseum", Store, 1)
    Toggle.new(rewCard.Content, "Auto Claim Collections", "AutoCollections", Store, 2)
    Toggle.new(rewCard.Content, "Auto Claim Daily Rewards", "AutoDailyReward", Store, 3)
    Toggle.new(rewCard.Content, "Auto Lost & Found Retrieval", "AutoLostFound", Store, 4)

    local tpL, tpR = createTwoColumnPage("Teleport", "Map Locations & Navigation")
    local tpCard = Card.new(tpL, "Instant Teleportation", "🗺", 1)
    
    local locList = TeleportModule.GetLocationList()
    local selectedLoc = locList[1]
    
    Dropdown.new(tpCard.Content, "Select Destination", locList, false, "TeleportTarget", Store, 1)
    
    local TpBtn = Instance.new("TextButton")
    TpBtn.Size = UDim2.new(1, 0, 0, 36)
    TpBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    TpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TpBtn.Text = "TELEPORT NOW"
    TpBtn.Font = Enum.Font.GothamBold
    TpBtn.TextSize = 13
    TpBtn.AutoButtonColor = false
    TpBtn.LayoutOrder = 2
    TpBtn.Parent = tpCard.Content

    local tpbCorner = Instance.new("UICorner")
    tpbCorner.CornerRadius = UDim.new(0, 6)
    tpbCorner.Parent = TpBtn

    TpBtn.MouseButton1Click:Connect(function()
        local target = Store.Get("TeleportTarget") or locList[1]
        local ok = TeleportModule.TeleportTo(target)
        TpBtn.Text = ok and "TELEPORTED!" or "LOCATION NOT FOUND"
        task.wait(1.5)
        TpBtn.Text = "TELEPORT NOW"
    end)

    local utilL, utilR = createTwoColumnPage("Utilities", "Utilities, Movement & Guard")
    local guardCard = Card.new(utilL, "Watchdog & Movement", "🛡", 1)
    Toggle.new(guardCard.Content, "Anti-Stuck Watchdog", "AntiStuck", Store, 1)
    Input.new(guardCard.Content, "Idle Timeout (Seconds)", "AntiStuckSeconds", true, Store, 2)
    Toggle.new(guardCard.Content, "WalkSpeed Boost", "WalkSpeedEnabled", Store, 3)
    Slider.new(guardCard.Content, "WalkSpeed Value", 16, 200, 2, "WalkSpeedValue", "", Store, 4)
    Toggle.new(guardCard.Content, "JumpPower Boost", "JumpPowerEnabled", Store, 5)
    Slider.new(guardCard.Content, "JumpPower Value", 50, 300, 5, "JumpPowerValue", "", Store, 6)
    Toggle.new(guardCard.Content, "Noclip", "Noclip", Store, 7)

    local drinkCard = Card.new(utilR, "Consumables & Upgrades", "⚡", 1)
    Toggle.new(drinkCard.Content, "Auto Buy Energy Drinks", "AutoBuyDrinks", Store, 1)
    Toggle.new(drinkCard.Content, "Auto Use Energy Drinks", "AutoUseDrinks", Store, 2)
    Toggle.new(drinkCard.Content, "Auto Buy Shop Upgrades", "AutoBuyUpgrades", Store, 3)

    local setL, setR = createTwoColumnPage("Settings", "Configuration & Unload")
    local setCard = Card.new(setL, "Config Management", "⚙", 1)
    
    local SaveBtn = Instance.new("TextButton")
    SaveBtn.Size = UDim2.new(1, 0, 0, 36)
    SaveBtn.BackgroundColor3 = Color3.fromRGB(25, 95, 45)
    SaveBtn.TextColor3 = Color3.fromRGB(140, 255, 160)
    SaveBtn.Text = "SAVE SETTINGS TO JSON"
    SaveBtn.Font = Enum.Font.GothamBold
    SaveBtn.TextSize = 13
    SaveBtn.AutoButtonColor = false
    SaveBtn.LayoutOrder = 1
    SaveBtn.Parent = setCard.Content

    local sbCorner = Instance.new("UICorner")
    sbCorner.CornerRadius = UDim.new(0, 6)
    sbCorner.Parent = SaveBtn

    SaveBtn.MouseButton1Click:Connect(function()
        Store.DebouncedSave()
        SaveBtn.Text = "SAVED TO GENESIS/SETTINGS.JSON!"
        task.wait(1.5)
        SaveBtn.Text = "SAVE SETTINGS TO JSON"
    end)

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(1, 0, 0, 36)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(65, 25, 30)
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    UnloadBtn.Text = "UNLOAD GENESIS HUB"
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 13
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.LayoutOrder = 2
    UnloadBtn.Parent = setCard.Content

    local ubCorner = Instance.new("UICorner")
    ubCorner.CornerRadius = UDim.new(0, 6)
    ubCorner.Parent = UnloadBtn

    UnloadBtn.MouseButton1Click:Connect(function()
        AuctionModule.StopLoop()
        WashModule.StopAutoWashLoop()
        RepairModule.StopLoop()
        GradingModule.StopLoop()
        LocksmithModule.StopLoop()
        StockModule.StopLoop()
        RewardsModule.StopLoop()
        UtilsModule.StopLoop()
        ResetModule.StopTracker()
        EventBus.Destroy()
        ScreenGui:Destroy()
    end)

    switchTab("Info")

    AuctionModule.StartLoop(Store)
    WashModule.StartAutoWashLoop(Store)
    RepairModule.StartLoop(Store)
    GradingModule.StartLoop(Store)
    LocksmithModule.StartLoop(Store)
    StockModule.StartLoop(Store)
    RewardsModule.StartLoop(Store)
    UtilsModule.StartLoop(Store)
    ResetModule.StartTracker(Store)
end

return UI
