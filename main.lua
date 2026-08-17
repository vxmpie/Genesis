local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FOLDER = "Genesis"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"

local State = {
    IsActive = false,
    IntervalSeconds = 60,
    IntervalValue = 1,
    TimeRemaining = 0,
    Unit = "Minutes",
}

local timerThread = nil

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
            IsActive = State.IsActive,
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
                State.IntervalValue = tonumber(decoded.IntervalValue) or 1
            end
            if decoded.Unit == "Minutes" or decoded.Unit == "Seconds" then
                State.Unit = decoded.Unit
            end
            if decoded.IsActive == true then
                State.IsActive = true
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

local function startTimer(countdownLabel, statusLabel, toggleBtn, toggleCircle)
    if timerThread then
        pcall(function() task.cancel(timerThread) end)
    end

    State.TimeRemaining = State.IntervalSeconds

    timerThread = task.spawn(function()
        while State.IsActive do
            if State.TimeRemaining <= 0 then
                if statusLabel then
                    statusLabel.Text = "RESETTING..."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
                end
                resetCharacter()
                task.wait(3)
                State.TimeRemaining = State.IntervalSeconds
                if statusLabel then
                    statusLabel.Text = "ACTIVE"
                    statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
                end
            end

            if countdownLabel then
                local mins = math.floor(State.TimeRemaining / 60)
                local secs = State.TimeRemaining % 60
                countdownLabel.Text = string.format("%02d:%02d", mins, secs)
            end

            task.wait(1)
            if State.IsActive then
                State.TimeRemaining = State.TimeRemaining - 1
            end
        end
    end)
end

local function stopTimer(countdownLabel, statusLabel)
    State.IsActive = false
    if timerThread then
        pcall(function() task.cancel(timerThread) end)
        timerThread = nil
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
    MainFrame.Size = UDim2.new(0, 340, 0, 450)
    MainFrame.Position = UDim2.new(0.5, -170, 0.5, -225)
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
    SubTitle.Text = "Character Reset Timer"
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

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -30, 1, -65)
    Content.Position = UDim2.new(0, 15, 0, 55)
    Content.BackgroundTransparency = 1
    Content.Parent = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = Content

    local CountdownFrame = Instance.new("Frame")
    CountdownFrame.Size = UDim2.new(1, 0, 0, 100)
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
    CountdownLabel.Size = UDim2.new(1, 0, 0, 60)
    CountdownLabel.Position = UDim2.new(0, 0, 0, 8)
    CountdownLabel.BackgroundTransparency = 1
    CountdownLabel.Text = "00:00"
    CountdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    CountdownLabel.Font = Enum.Font.GothamBlack
    CountdownLabel.TextSize = 48
    CountdownLabel.Parent = CountdownFrame

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "Status"
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.Position = UDim2.new(0, 0, 1, -28)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "INACTIVE"
    StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 12
    StatusLabel.Parent = CountdownFrame

    local SectionHeader = Instance.new("TextLabel")
    SectionHeader.Size = UDim2.new(1, 0, 0, 20)
    SectionHeader.BackgroundTransparency = 1
    SectionHeader.Text = "TIMER SETTINGS"
    SectionHeader.TextColor3 = Color3.fromRGB(100, 100, 115)
    SectionHeader.Font = Enum.Font.GothamBlack
    SectionHeader.TextSize = 11
    SectionHeader.TextXAlignment = Enum.TextXAlignment.Left
    SectionHeader.LayoutOrder = 2
    SectionHeader.Parent = Content

    local InputRow = Instance.new("Frame")
    InputRow.Size = UDim2.new(1, 0, 0, 44)
    InputRow.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    InputRow.LayoutOrder = 3
    InputRow.Parent = Content

    local irCorner = Instance.new("UICorner")
    irCorner.CornerRadius = UDim.new(0, 8)
    irCorner.Parent = InputRow

    local InputLabel = Instance.new("TextLabel")
    InputLabel.Size = UDim2.new(0, 80, 1, 0)
    InputLabel.Position = UDim2.new(0, 12, 0, 0)
    InputLabel.BackgroundTransparency = 1
    InputLabel.Text = "Interval"
    InputLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    InputLabel.Font = Enum.Font.GothamSemibold
    InputLabel.TextSize = 13
    InputLabel.TextXAlignment = Enum.TextXAlignment.Left
    InputLabel.Parent = InputRow

    local TimeInput = Instance.new("TextBox")
    TimeInput.Name = "TimeInput"
    TimeInput.Size = UDim2.new(0, 70, 0, 30)
    TimeInput.Position = UDim2.new(0, 100, 0.5, -15)
    TimeInput.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    TimeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    TimeInput.PlaceholderText = tostring(State.IntervalValue)
    TimeInput.Text = tostring(State.IntervalValue)
    TimeInput.Font = Enum.Font.GothamBold
    TimeInput.TextSize = 14
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
    UnitBtn.Size = UDim2.new(0, 95, 0, 30)
    UnitBtn.Position = UDim2.new(1, -107, 0.5, -15)
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
    UnitBtn.TextSize = 12

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

    local Spacer = Instance.new("Frame")
    Spacer.Size = UDim2.new(1, 0, 0, 5)
    Spacer.BackgroundTransparency = 1
    Spacer.LayoutOrder = 4
    Spacer.Parent = Content

    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, 0, 0, 52)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    ToggleFrame.LayoutOrder = 5
    ToggleFrame.Parent = Content

    local tfCorner = Instance.new("UICorner")
    tfCorner.CornerRadius = UDim.new(0, 8)
    tfCorner.Parent = ToggleFrame

    local ToggleLabel = Instance.new("TextLabel")
    ToggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    ToggleLabel.Position = UDim2.new(0, 15, 0, 0)
    ToggleLabel.BackgroundTransparency = 1
    ToggleLabel.Text = "Auto Reset"
    ToggleLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    ToggleLabel.Font = Enum.Font.GothamBold
    ToggleLabel.TextSize = 15
    ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    ToggleLabel.Parent = ToggleFrame

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ToggleSwitch"
    ToggleBtn.Size = UDim2.new(0, 56, 0, 28)
    ToggleBtn.Position = UDim2.new(1, -72, 0.5, -14)
    ToggleBtn.Text = ""
    ToggleBtn.AutoButtonColor = false
    ToggleBtn.Parent = ToggleFrame

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(1, 0)
    tbCorner.Parent = ToggleBtn

    local ToggleCircle = Instance.new("Frame")
    ToggleCircle.Name = "Circle"
    ToggleCircle.Size = UDim2.new(0, 22, 0, 22)
    ToggleCircle.Parent = ToggleBtn

    local tcCorner = Instance.new("UICorner")
    tcCorner.CornerRadius = UDim.new(1, 0)
    tcCorner.Parent = ToggleCircle

    local ToggleText = Instance.new("TextLabel")
    ToggleText.Size = UDim2.new(0, 30, 1, 0)
    ToggleText.BackgroundTransparency = 1
    ToggleText.Font = Enum.Font.GothamBold
    ToggleText.TextSize = 10
    ToggleText.Parent = ToggleBtn

    if State.IsActive then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
        ToggleCircle.Position = UDim2.new(1, -25, 0.5, -11)
        ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ToggleText.Text = "ON"
        ToggleText.Position = UDim2.new(0, 4, 0, 0)
        ToggleText.TextColor3 = Color3.fromRGB(255, 255, 255)
        cdStroke.Color = Color3.fromRGB(40, 160, 80)
        StatusLabel.Text = "ACTIVE"
        StatusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        ToggleCircle.Position = UDim2.new(0, 3, 0.5, -11)
        ToggleCircle.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
        ToggleText.Text = "OFF"
        ToggleText.Position = UDim2.new(1, -34, 0, 0)
        ToggleText.TextColor3 = Color3.fromRGB(150, 150, 160)
    end

    ToggleBtn.MouseButton1Click:Connect(function()
        State.IsActive = not State.IsActive

        if State.IsActive then
            local rawVal = tonumber(TimeInput.Text) or 1
            if rawVal <= 0 then rawVal = 1 end
            State.IntervalValue = rawVal
            if State.Unit == "Minutes" then
                State.IntervalSeconds = rawVal * 60
            else
                State.IntervalSeconds = rawVal
            end

            ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
            ToggleCircle.Position = UDim2.new(1, -25, 0.5, -11)
            ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            ToggleText.Text = "ON"
            ToggleText.Position = UDim2.new(0, 4, 0, 0)
            ToggleText.TextColor3 = Color3.fromRGB(255, 255, 255)

            cdStroke.Color = Color3.fromRGB(40, 160, 80)

            saveSettings()
            startTimer(CountdownLabel, StatusLabel, ToggleBtn, ToggleCircle)
        else
            saveSettings()
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            ToggleCircle.Position = UDim2.new(0, 3, 0.5, -11)
            ToggleCircle.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
            ToggleText.Text = "OFF"
            ToggleText.Position = UDim2.new(1, -34, 0, 0)
            ToggleText.TextColor3 = Color3.fromRGB(150, 150, 160)

            cdStroke.Color = Color3.fromRGB(40, 40, 50)

            stopTimer(CountdownLabel, StatusLabel)
        end
    end)

    if State.IsActive then
        startTimer(CountdownLabel, StatusLabel, ToggleBtn, ToggleCircle)
    end

    local Spacer2 = Instance.new("Frame")
    Spacer2.Size = UDim2.new(1, 0, 0, 5)
    Spacer2.BackgroundTransparency = 1
    Spacer2.LayoutOrder = 6
    Spacer2.Parent = Content

    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Size = UDim2.new(1, 0, 0, 40)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Text = "Set the timer and press ON.\nCharacter will auto-reset when time is up."
    InfoLabel.TextColor3 = Color3.fromRGB(80, 80, 95)
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.TextSize = 11
    InfoLabel.TextWrapped = true
    InfoLabel.LayoutOrder = 7
    InfoLabel.Parent = Content

    local UnloadBtn = Instance.new("TextButton")
    UnloadBtn.Size = UDim2.new(1, 0, 0, 38)
    UnloadBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 28)
    UnloadBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    UnloadBtn.Text = "UNLOAD SCRIPT"
    UnloadBtn.Font = Enum.Font.GothamBold
    UnloadBtn.TextSize = 12
    UnloadBtn.AutoButtonColor = false
    UnloadBtn.LayoutOrder = 8
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
        stopTimer(CountdownLabel, StatusLabel)
        ScreenGui:Destroy()
    end)
end

createUI()
warn("[GENESIS] Character Reset Timer loaded successfully!")
