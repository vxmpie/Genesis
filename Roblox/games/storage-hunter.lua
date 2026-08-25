local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FOLDER = "Genesis"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"

local State = {
    IsActive = false,
    AutoWash = false,
    FastPickup = true,
    Mode = "Anti-Stuck",
    IntervalSeconds = 15,
    IntervalValue = 15,
    TimeRemaining = 0,
    Unit = "Seconds",
}

local trackerThread = nil
local washThread = nil
local pickupThread = nil

local function ensureFolder()
    pcall(function()
        if not isfolder(SETTINGS_FOLDER) then
            makefolder(SETTINGS_FOLDER)
        end
    end)
end

local function saveSettings()
    pcall(function()
        ensureFolder()
        local data = HttpService:JSONEncode({
            IntervalValue = State.IntervalValue,
            Unit = State.Unit,
            Mode = State.Mode,
            IsActive = State.IsActive,
            AutoWash = State.AutoWash,
            FastPickup = State.FastPickup,
        })
        writefile(SETTINGS_FILE, data)
    end)
end

local function loadSettings()
    local ok, data = pcall(function()
        return readfile(SETTINGS_FILE)
    end)
    if ok and data then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if success and decoded then
            if decoded.IntervalValue then
                State.IntervalValue = tonumber(decoded.IntervalValue) or 15
            end
            if decoded.Unit == "Minutes" or decoded.Unit == "Seconds" then
                State.Unit = decoded.Unit
            end
            if decoded.Mode == "Anti-Stuck" or decoded.Mode == "Timer" then
                State.Mode = decoded.Mode
            end
            if decoded.IsActive == true then
                State.IsActive = true
            end
            if decoded.AutoWash ~= nil then
                State.AutoWash = decoded.AutoWash
            end
            if decoded.FastPickup ~= nil then
                State.FastPickup = decoded.FastPickup
            end
        end
    end
end

loadSettings()

if State.Unit == "Minutes" then
    State.IntervalSeconds = State.IntervalValue * 60
else
    State.IntervalSeconds = State.IntervalValue
end

local function resetCharacter()
    local character = LocalPlayer.Character
    if not character then return end

    local success = pcall(function()
        character:BreakJoints()
    end)

    if not success then
        pcall(function()
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = 0
            end
        end)
    end

    if character and character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            character.HumanoidRootPart:Destroy()
        end)
    end
end

local function runAutoWash()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local washEvents = events and events:FindFirstChild("Wash")
    if not washEvents then return end

    local getSlotState = washEvents:FindFirstChild("GetSlotState")
    local getWashableItems = washEvents:FindFirstChild("GetWashableItems")
    local startWash = washEvents:FindFirstChild("StartWash")
    local claimWashed = washEvents:FindFirstChild("ClaimWashedItem") or washEvents:FindFirstChild("CollectWash")

    if not getSlotState or not getWashableItems or not startWash then return end

    local ok, slotState = pcall(function() return getSlotState:InvokeServer() end)
    if ok and type(slotState) == "table" then
        for slotIndex, slotData in pairs(slotState) do
            if type(slotData) == "table" then
                local isDone = slotData.IsComplete or slotData.Status == "Complete" or slotData.Status == "Ready" or (slotData.EndTime and os.time() >= tonumber(slotData.EndTime or 0))
                if isDone and claimWashed then
                    pcall(function()
                        claimWashed:InvokeServer(slotIndex)
                    end)
                    task.wait(0.15)
                end
            end
        end
    end

    local ok2, refreshedSlots = pcall(function() return getSlotState:InvokeServer() end)
    if ok2 and type(refreshedSlots) == "table" then
        local ok3, washable = pcall(function() return getWashableItems:InvokeServer() end)
        if ok3 and type(washable) == "table" and #washable > 0 then
            local itemIdx = 1
            for slotIndex, slotData in pairs(refreshedSlots) do
                local isEmpty = false
                if slotData == nil or slotData == false then
                    isEmpty = true
                elseif type(slotData) == "table" then
                    isEmpty = slotData.IsEmpty or not slotData.Item or slotData.Status == "Empty" or slotData.Status == nil
                end

                if isEmpty and washable[itemIdx] then
                    local target = washable[itemIdx]
                    local targetId = (type(target) == "table" and (target.Id or target.ItemId or target.UUID or target.id)) or target
                    pcall(function()
                        startWash:InvokeServer(slotIndex, targetId)
                    end)
                    itemIdx = itemIdx + 1
                    task.wait(0.15)
                end
            end
        end
    end
end

local function fastAuctionPickup()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local auctionEvents = events and events:FindFirstChild("Auction")
    local draggingEvents = events and events:FindFirstChild("Dragging")

    local auctionPickupItem = auctionEvents and auctionEvents:FindFirstChild("AuctionPickupItem")
    local pickUpItem = draggingEvents and draggingEvents:FindFirstChild("PickUpItem")

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local isWon = obj:GetAttribute("AuctionItemId") or obj:GetAttribute("WonItem") or obj:GetAttribute("ItemId")
            local isAuctionParent = obj.Parent and (obj.Parent.Name == "AuctionItems" or obj.Parent.Name == "WonItems" or obj.Parent.Name == "StorageItems")
            local hasPrompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChild("PromptPart")

            if isWon or isAuctionParent or hasPrompt then
                if auctionPickupItem then
                    pcall(function() auctionPickupItem:FireServer(obj) end)
                end
                if pickUpItem then
                    pcall(function() pickUpItem:FireServer(obj) end)
                end
            end
        end
    end
end

local function startAutoWashLoop()
    if washThread then
        pcall(function() task.cancel(washThread) end)
    end
    washThread = task.spawn(function()
        while State.AutoWash do
            pcall(runAutoWash)
            task.wait(3)
        end
    end)
end

local function stopAutoWashLoop()
    if washThread then
        pcall(function() task.cancel(washThread) end)
        washThread = nil
    end
end

local function startFastPickupLoop()
    if pickupThread then
        pcall(function() task.cancel(pickupThread) end)
    end
    pickupThread = task.spawn(function()
        while State.FastPickup do
            pcall(fastAuctionPickup)
            task.wait(0.3)
        end
    end)
end

local function stopFastPickupLoop()
    if pickupThread then
        pcall(function() task.cancel(pickupThread) end)
        pickupThread = nil
    end
end

local function startTracker(countdownLabel, statusLabel)
    if trackerThread then
        pcall(function() task.cancel(trackerThread) end)
    end

    trackerThread = task.spawn(function()
        local lastPos = nil
        local idleSeconds = 0
        local timerCountdown = State.IntervalSeconds

        while State.IsActive do
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not hrp or not humanoid or humanoid.Health <= 0 then
                if statusLabel then
                    statusLabel.Text = "RESPAWNING..."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
                end
                lastPos = nil
                idleSeconds = 0
                task.wait(1)
            else
                if State.Mode == "Anti-Stuck" then
                    local currentPos = hrp.Position

                    if not lastPos then
                        lastPos = currentPos
                        idleSeconds = 0
                    end

                    local distance = (currentPos - lastPos).Magnitude

                    if distance > 3 then
                        lastPos = currentPos
                        idleSeconds = 0
                        if statusLabel then
                            statusLabel.Text = "FARMING (MOVING)"
                            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
                        end
                        if countdownLabel then
                            countdownLabel.Text = "00:00"
                        end
                    else
                        idleSeconds = idleSeconds + 1
                        local remaining = math.max(0, State.IntervalSeconds - idleSeconds)

                        if countdownLabel then
                            local mins = math.floor(remaining / 60)
                            local secs = remaining % 60
                            countdownLabel.Text = string.format("%02d:%02d", mins, secs)
                        end

                        if remaining <= 0 then
                            if statusLabel then
                                statusLabel.Text = "STUCK! RESETTING..."
                                statusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
                            end
                            resetCharacter()
                            task.wait(3)
                            lastPos = nil
                            idleSeconds = 0
                        else
                            if statusLabel then
                                statusLabel.Text = string.format("IDLE (%ds / %ds)", idleSeconds, State.IntervalSeconds)
                                statusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                            end
                        end
                    end
                else
                    if timerCountdown <= 0 then
                        if statusLabel then
                            statusLabel.Text = "RESETTING..."
                            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
                        end
                        resetCharacter()
                        task.wait(3)
                        timerCountdown = State.IntervalSeconds
                        if statusLabel then
                            statusLabel.Text = "ACTIVE"
                            statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
                        end
                    end

                    if countdownLabel then
                        local mins = math.floor(timerCountdown / 60)
                        local secs = timerCountdown % 60
                        countdownLabel.Text = string.format("%02d:%02d", mins, secs)
                    end

                    timerCountdown = timerCountdown - 1
                end

                task.wait(1)
            end
        end
    end)
end

local function stopTracker(countdownLabel, statusLabel)
    State.IsActive = false
    if trackerThread then
        pcall(function() task.cancel(trackerThread) end)
        trackerThread = nil
    end
    if countdownLabel then countdownLabel.Text = "00:00" end
    if statusLabel then
        statusLabel.Text = "INACTIVE"
        statusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    end
end

local function createUI()
    if CoreGui:FindFirstChild("GenesisResetTimer") then
        CoreGui.GenesisResetTimer:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GenesisResetTimer"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = "FloatingBtn"
    FloatingBtn.Size = UDim2.new(0, 50, 0, 50)
    FloatingBtn.Position = UDim2.new(1, -70, 0.5, -25)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    FloatingBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
    FloatingBtn.Text = "G"
    FloatingBtn.Font = Enum.Font.GothamBlack
    FloatingBtn.TextSize = 28
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

    FloatingBtn.MouseEnter:Connect(function()
        floatStroke.Thickness = 3
        FloatingBtn.BackgroundColor3 = Color3.fromRGB(25, 20, 22)
    end)
    FloatingBtn.MouseLeave:Connect(function()
        floatStroke.Thickness = 2
        FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    end)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 340, 0, 500)
    MainFrame.Position = UDim2.new(0.5, -170, 0.5, -250)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = MainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(35, 35, 40)
    mainStroke.Thickness = 1
    mainStroke.Parent = MainFrame

    FloatingBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = TitleBar

    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 12)
    titleFix.Position = UDim2.new(0, 0, 1, -12)
    titleFix.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -50, 1, 0)
    TitleLabel.Position = UDim2.new(0, 15, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "GENESIS"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    TitleLabel.Font = Enum.Font.GothamBlack
    TitleLabel.TextSize = 18
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    local SubTitle = Instance.new("TextLabel")
    SubTitle.Size = UDim2.new(1, -15, 0, 16)
    SubTitle.Position = UDim2.new(0, 15, 1, -20)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "Storage Hunter Multi-Tool"
    SubTitle.TextColor3 = Color3.fromRGB(100, 100, 115)
    SubTitle.Font = Enum.Font.GothamMedium
    SubTitle.TextSize = 11
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.Parent = TitleBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -40, 0, 10)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 38)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.AutoButtonColor = false
    CloseBtn.Parent = TitleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -20, 1, -60)
    Content.Position = UDim2.new(0, 10, 0, 55)
    Content.BackgroundTransparency = 1
    Content.ScrollBarThickness = 3
    Content.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
    Content.BorderSizePixel = 0
    Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Content.CanvasSize = UDim2.new(0, 0, 0, 0)
    Content.Parent = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = Content

    local CountdownFrame = Instance.new("Frame")
    CountdownFrame.Size = UDim2.new(1, 0, 0, 90)
    CountdownFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    CountdownFrame.LayoutOrder = 1
    CountdownFrame.Parent = Content

    local cdCorner = Instance.new("UICorner")
    cdCorner.CornerRadius = UDim.new(0, 10)
    cdCorner.Parent = CountdownFrame

    local cdStroke = Instance.new("UIStroke")
    cdStroke.Color = Color3.fromRGB(40, 40, 50)
    cdStroke.Thickness = 1
    cdStroke.Parent = CountdownFrame

    local CountdownLabel = Instance.new("TextLabel")
    CountdownLabel.Name = "Countdown"
    CountdownLabel.Size = UDim2.new(1, 0, 0, 50)
    CountdownLabel.Position = UDim2.new(0, 0, 0, 6)
    CountdownLabel.BackgroundTransparency = 1
    CountdownLabel.Text = "00:00"
    CountdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    CountdownLabel.Font = Enum.Font.GothamBlack
    CountdownLabel.TextSize = 40
    CountdownLabel.Parent = CountdownFrame

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "Status"
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.Position = UDim2.new(0, 0, 1, -24)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "INACTIVE"
    StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 12
    StatusLabel.Parent = CountdownFrame

    local ModeRow = Instance.new("Frame")
    ModeRow.Size = UDim2.new(1, 0, 0, 38)
    ModeRow.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    ModeRow.LayoutOrder = 2
    ModeRow.Parent = Content

    local mrCorner = Instance.new("UICorner")
    mrCorner.CornerRadius = UDim.new(0, 8)
    mrCorner.Parent = ModeRow

    local ModeLabel = Instance.new("TextLabel")
    ModeLabel.Size = UDim2.new(0, 80, 1, 0)
    ModeLabel.Position = UDim2.new(0, 12, 0, 0)
    ModeLabel.BackgroundTransparency = 1
    ModeLabel.Text = "Reset Mode"
    ModeLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    ModeLabel.Font = Enum.Font.GothamSemibold
    ModeLabel.TextSize = 13
    ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
    ModeLabel.Parent = ModeRow

    local ModeBtn = Instance.new("TextButton")
    ModeBtn.Name = "ModeToggle"
    ModeBtn.Size = UDim2.new(0, 115, 0, 26)
    ModeBtn.Position = UDim2.new(1, -127, 0.5, -13)
    ModeBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 48)
    ModeBtn.TextColor3 = Color3.fromRGB(210, 160, 255)
    ModeBtn.Text = State.Mode
    ModeBtn.Font = Enum.Font.GothamBold
    ModeBtn.TextSize = 12
    ModeBtn.AutoButtonColor = false
    ModeBtn.Parent = ModeRow

    local mbCorner = Instance.new("UICorner")
    mbCorner.CornerRadius = UDim.new(0, 6)
    mbCorner.Parent = ModeBtn

    local mbStroke = Instance.new("UIStroke")
    mbStroke.Color = Color3.fromRGB(110, 70, 170)
    mbStroke.Thickness = 1
    mbStroke.Parent = ModeBtn

    local InputRow = Instance.new("Frame")
    InputRow.Size = UDim2.new(1, 0, 0, 38)
    InputRow.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    InputRow.LayoutOrder = 3
    InputRow.Parent = Content

    local irCorner = Instance.new("UICorner")
    irCorner.CornerRadius = UDim.new(0, 8)
    irCorner.Parent = InputRow

    local InputLabel = Instance.new("TextLabel")
    InputLabel.Size = UDim2.new(0, 90, 1, 0)
    InputLabel.Position = UDim2.new(0, 12, 0, 0)
    InputLabel.BackgroundTransparency = 1
    InputLabel.Text = State.Mode == "Anti-Stuck" and "Max Idle (s)" or "Interval"
    InputLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    InputLabel.Font = Enum.Font.GothamSemibold
    InputLabel.TextSize = 13
    InputLabel.TextXAlignment = Enum.TextXAlignment.Left
    InputLabel.Parent = InputRow

    local TimeInput = Instance.new("TextBox")
    TimeInput.Name = "TimeInput"
    TimeInput.Size = UDim2.new(0, 60, 0, 26)
    TimeInput.Position = UDim2.new(0, 105, 0.5, -13)
    TimeInput.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    TimeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    TimeInput.PlaceholderText = tostring(State.IntervalValue)
    TimeInput.Text = tostring(State.IntervalValue)
    TimeInput.Font = Enum.Font.GothamBold
    TimeInput.TextSize = 13
    TimeInput.ClearTextOnFocus = false
    TimeInput.Parent = InputRow

    local tiCorner = Instance.new("UICorner")
    tiCorner.CornerRadius = UDim.new(0, 6)
    tiCorner.Parent = TimeInput

    local tiStroke = Instance.new("UIStroke")
    tiStroke.Color = Color3.fromRGB(50, 50, 60)
    tiStroke.Thickness = 1
    tiStroke.Parent = TimeInput

    local UnitBtn = Instance.new("TextButton")
    UnitBtn.Name = "UnitToggle"
    UnitBtn.Size = UDim2.new(0, 80, 0, 26)
    UnitBtn.Position = UDim2.new(1, -92, 0.5, -13)
    UnitBtn.AutoButtonColor = false
    UnitBtn.Parent = InputRow

    if State.Unit == "Seconds" then
        UnitBtn.BackgroundColor3 = Color3.fromRGB(30, 45, 55)
        UnitBtn.TextColor3 = Color3.fromRGB(100, 200, 255)
        UnitBtn.Text = "Seconds"
    else
        UnitBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 50)
        UnitBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
        UnitBtn.Text = "Minutes"
    end

    UnitBtn.Font = Enum.Font.GothamBold
    UnitBtn.TextSize = 11

    local ubCorner = Instance.new("UICorner")
    ubCorner.CornerRadius = UDim.new(0, 6)
    ubCorner.Parent = UnitBtn

    local ubStroke = Instance.new("UIStroke")
    if State.Unit == "Seconds" then
        ubStroke.Color = Color3.fromRGB(60, 140, 200)
    else
        ubStroke.Color = Color3.fromRGB(120, 80, 180)
    end
    ubStroke.Thickness = 1
    ubStroke.Parent = UnitBtn

    ModeBtn.MouseButton1Click:Connect(function()
        if State.Mode == "Anti-Stuck" then
            State.Mode = "Timer"
            InputLabel.Text = "Interval"
        else
            State.Mode = "Anti-Stuck"
            InputLabel.Text = "Max Idle (s)"
        end
        ModeBtn.Text = State.Mode
        saveSettings()
        if State.IsActive then
            startTracker(CountdownLabel, StatusLabel)
        end
    end)

    UnitBtn.MouseButton1Click:Connect(function()
        if State.Unit == "Minutes" then
            State.Unit = "Seconds"
            UnitBtn.Text = "Seconds"
            UnitBtn.TextColor3 = Color3.fromRGB(100, 200, 255)
            UnitBtn.BackgroundColor3 = Color3.fromRGB(30, 45, 55)
            ubStroke.Color = Color3.fromRGB(60, 140, 200)
        else
            State.Unit = "Minutes"
            UnitBtn.Text = "Minutes"
            UnitBtn.TextColor3 = Color3.fromRGB(200, 160, 255)
            UnitBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 50)
            ubStroke.Color = Color3.fromRGB(120, 80, 180)
        end
        if State.Unit == "Minutes" then
            State.IntervalSeconds = State.IntervalValue * 60
        else
            State.IntervalSeconds = State.IntervalValue
        end
        saveSettings()
    end)

    TimeInput.FocusLost:Connect(function()
        local rawVal = tonumber(TimeInput.Text) or State.IntervalValue
        if rawVal <= 0 then rawVal = 1 end
        State.IntervalValue = rawVal
        TimeInput.Text = tostring(rawVal)
        if State.Unit == "Minutes" then
            State.IntervalSeconds = rawVal * 60
        else
            State.IntervalSeconds = rawVal
        end
        saveSettings()
    end)

    local function createToggleRow(labelText, initialState, onToggle, order)
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 42)
        Row.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
        Row.LayoutOrder = order
        Row.Parent = Content

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 8)
        rCorner.Parent = Row

        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.65, 0, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = labelText
        Label.TextColor3 = Color3.fromRGB(230, 230, 235)
        Label.Font = Enum.Font.GothamBold
        Label.TextSize = 13
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Row

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0, 52, 0, 24)
        Btn.Position = UDim2.new(1, -64, 0.5, -12)
        Btn.Text = ""
        Btn.AutoButtonColor = false
        Btn.Parent = Row

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(1, 0)
        bCorner.Parent = Btn

        local Circle = Instance.new("Frame")
        Circle.Size = UDim2.new(0, 18, 0, 18)
        Circle.Parent = Btn

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(1, 0)
        cCorner.Parent = Circle

        local Text = Instance.new("TextLabel")
        Text.Size = UDim2.new(0, 26, 1, 0)
        Text.BackgroundTransparency = 1
        Text.Font = Enum.Font.GothamBold
        Text.TextSize = 9
        Text.Parent = Btn

        local function updateVisual(val)
            if val then
                Btn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                Circle.Position = UDim2.new(1, -21, 0.5, -9)
                Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Text.Text = "ON"
                Text.Position = UDim2.new(0, 3, 0, 0)
                Text.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                Circle.Position = UDim2.new(0, 3, 0.5, -9)
                Circle.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
                Text.Text = "OFF"
                Text.Position = UDim2.new(1, -29, 0, 0)
                Text.TextColor3 = Color3.fromRGB(150, 150, 160)
            end
        end

        updateVisual(initialState)

        Btn.MouseButton1Click:Connect(function()
            local newState = onToggle()
            updateVisual(newState)
            saveSettings()
        end)

        return Row, updateVisual
    end

    createToggleRow("Auto Reset Guard", State.IsActive, function()
        State.IsActive = not State.IsActive
        if State.IsActive then
            local rawVal = tonumber(TimeInput.Text) or State.IntervalValue
            if rawVal <= 0 then rawVal = 1 end
            State.IntervalValue = rawVal
            if State.Unit == "Minutes" then
                State.IntervalSeconds = rawVal * 60
            else
                State.IntervalSeconds = rawVal
            end
            cdStroke.Color = Color3.fromRGB(40, 160, 80)
            startTracker(CountdownLabel, StatusLabel)
        else
            cdStroke.Color = Color3.fromRGB(40, 40, 50)
            stopTracker(CountdownLabel, StatusLabel)
        end
        return State.IsActive
    end, 4)

    createToggleRow("Auto Wash Items (Send & Claim)", State.AutoWash, function()
        State.AutoWash = not State.AutoWash
        if State.AutoWash then
            startAutoWashLoop()
        else
            stopAutoWashLoop()
        end
        return State.AutoWash
    end, 5)

    createToggleRow("Fast Auction Pickup (Instant Loot)", State.FastPickup, function()
        State.FastPickup = not State.FastPickup
        if State.FastPickup then
            startFastPickupLoop()
        else
            stopFastPickupLoop()
        end
        return State.FastPickup
    end, 6)

    if State.IsActive then
        startTracker(CountdownLabel, StatusLabel)
    end
    if State.AutoWash then
        startAutoWashLoop()
    end
    if State.FastPickup then
        startFastPickupLoop()
    end

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(1, 0, 0, 36)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 28)
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    UnloadBtn.Text = "UNLOAD SCRIPT"
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 12
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.LayoutOrder = 7
    UnloadBtn.Parent = Content

    local ulCorner = Instance.new("UICorner")
    ulCorner.CornerRadius = UDim.new(0, 8)
    ulCorner.Parent = UnloadBtn

    local ulStroke = Instance.new("UIStroke")
    ulStroke.Color = Color3.fromRGB(150, 40, 40)
    ulStroke.Thickness = 1
    ulStroke.Parent = UnloadBtn

    UnloadBtn.MouseEnter:Connect(function()
        UnloadBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 35)
    end)
    UnloadBtn.MouseLeave:Connect(function()
        UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 28)
    end)

    UnloadBtn.MouseButton1Click:Connect(function()
        stopTracker(CountdownLabel, StatusLabel)
        stopAutoWashLoop()
        stopFastPickupLoop()
        ScreenGui:Destroy()
    end)
end

createUI()
warn("[GENESIS] Character Reset Timer loaded successfully!")
