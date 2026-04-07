local player = game.Players.LocalPlayer
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

local assistStrength = 0.15

-- =====================
-- UTILS (UNIVERSAL)
-- =====================

local function getCharacterParts(char)
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head") or root

    return humanoid, root, head
end

local function isEnemy(v)
    if v == player then return false end

    if player.Team and v.Team then
        return v.Team ~= player.Team
    end

    return true
end

-- =====================
-- ESP
-- =====================

local espVisible = true
local espLines = {}
local espBoxes = {}
local espHealth = {}

local function createESP(target)
    if espLines[target] then return end

    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Transparency = 1
    espLines[target] = line

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = game.CoreGui
    espBoxes[target] = highlight

    local text = Drawing.new("Text")
    text.Size = 14
    text.Center = false
    text.Outline = true
    text.Font = 2
    espHealth[target] = text
end

local function removeESP(target)
    if espLines[target] then
        espLines[target]:Remove()
        espLines[target] = nil
    end

    if espBoxes[target] then
        espBoxes[target]:Destroy()
        espBoxes[target] = nil
    end

    if espHealth[target] then
        espHealth[target]:Remove()
        espHealth[target] = nil
    end
end

local hue = 0

local function updateESP()
    hue = (hue + 0.005) % 1
    local color = Color3.fromHSV(hue, 1, 1)

    for _,v in pairs(Players:GetPlayers()) do
        if isEnemy(v) then
            local humanoid, root, head = getCharacterParts(v.Character)

            if humanoid and head then
                createESP(v)

                local pos, visible = camera:WorldToViewportPoint(head.Position)

                local line = espLines[v]
                local box = espBoxes[v]
                local text = espHealth[v]

                box.Adornee = v.Character
                box.OutlineColor = color

                if visible and espVisible then
                    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)

                    line.From = center
                    line.To = Vector2.new(pos.X, pos.Y)
                    line.Color = color
                    line.Visible = true

                    text.Text = "HP: "..math.floor(humanoid.Health)
                    text.Position = Vector2.new(pos.X + 20, pos.Y)
                    text.Color = color
                    text.Visible = true
                else
                    line.Visible = false
                    text.Visible = false
                end
            else
                removeESP(v)
            end
        else
            removeESP(v)
        end
    end
end

-- =====================
-- AIM
-- =====================

local aimLockEnabled = false

local fovCircle = Drawing.new("Circle")
fovCircle.Radius = 180
fovCircle.Thickness = 2
fovCircle.Transparency = 1
fovCircle.Filled = false
fovCircle.Visible = false

local function isVisible(target)
    local origin = camera.CFrame.Position
    local direction = (target.Position - origin)

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {player.Character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)

    if result then
        return result.Instance:IsDescendantOf(target.Parent)
    end

    return true
end

local function getClosest()
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)

    local closestHead = nil
    local shortestDistance = fovCircle.Radius

    for _,v in pairs(Players:GetPlayers()) do
        if isEnemy(v) then
            local humanoid, root, head = getCharacterParts(v.Character)

            if humanoid and head and humanoid.Health > 0 then
                local pos, visible = camera:WorldToViewportPoint(head.Position)

                if visible and isVisible(head) then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude

                    if dist < shortestDistance then
                        shortestDistance = dist
                        closestHead = head
                    end
                end
            end
        end
    end

    return closestHead
end

-- =====================
-- PULL
-- =====================

local enabled = false

local function pullPlayers()
    if not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local forward = root.CFrame.LookVector
    local count = 0

    for _,p in pairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local _, targetRoot = getCharacterParts(p.Character)

            if targetRoot then
                count += 1

                local position = root.Position + (forward * 5) + Vector3.new(count*2,0,0)
                targetRoot.CFrame = CFrame.new(position)

                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = true end
            end
        end
    end
end

-- =====================
-- TP ALL
-- =====================

local tpEnabled = false
local currentIndex = 1
local playerList = {}
local angle = 0
local switchDelay = 0.6
local lastSwitch = 0

local function updatePlayerList()
    playerList = {}

    for _,p in pairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local _, root = getCharacterParts(p.Character)
            if root then
                table.insert(playerList, p)
            end
        end
    end
end

local function teleportToPlayers()
    if not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    updatePlayerList()
    if #playerList == 0 then return end

    if currentIndex > #playerList then
        currentIndex = 1
    end

    if tick() - lastSwitch >= switchDelay then
        currentIndex += 1
        lastSwitch = tick()
    end

    local targetPlayer = playerList[currentIndex]

    if targetPlayer and targetPlayer.Character then
        local _, targetRoot, head = getCharacterParts(targetPlayer.Character)

        if targetRoot and head then
            angle += 0.15
            local radius = 4

            local offset = Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)
            local newPos = targetRoot.Position + offset

            root.CFrame = CFrame.new(newPos, head.Position)

            camera.CFrame = camera.CFrame:Lerp(
                CFrame.lookAt(camera.CFrame.Position, head.Position),
                0.5
            )
        end
    end
end

-- =====================
-- NOCLIP
-- =====================

local noclipEnabled = false

RunService.Stepped:Connect(function()
    if noclipEnabled and player.Character then
        for _,v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end
end)

-- =====================
-- LOOPS
-- =====================

local currentSpeed = nil
local currentJump = nil -- NOVO

RunService.RenderStepped:Connect(function()
    updateESP()

    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    fovCircle.Position = center

    hue = (hue + 0.005) % 1
    fovCircle.Color = Color3.fromHSV(hue,1,1)

    local target = getClosest()

    if target then
        if aimLockEnabled then
            camera.CFrame = CFrame.new(camera.CFrame.Position, target.Position)
        else
            camera.CFrame = camera.CFrame:Lerp(
                CFrame.lookAt(camera.CFrame.Position, target.Position),
                assistStrength
            )
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if enabled then pullPlayers() end
    if tpEnabled then teleportToPlayers() end

    if currentSpeed and player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = currentSpeed
        end
    end

    -- NOVO
    if currentJump and player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = currentJump
        end
    end
end)

-- =====================
-- UI
-- =====================

local screenGui = Instance.new("ScreenGui", player.PlayerGui)
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999

local main = Instance.new("Frame", screenGui)
main.Size = UDim2.new(0,200,0,360)
main.Position = UDim2.new(0.8,0,0.5,0)
main.BackgroundColor3 = Color3.fromRGB(25,25,25)
main.Active = true
main.Draggable = true

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1,0,0,30)
title.BackgroundColor3 = Color3.fromRGB(200,50,50)
title.Text = "wakazinn hub"
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true

local button = Instance.new("TextButton", main)
button.Size = UDim2.new(1,-20,0,35)
button.Position = UDim2.new(0,10,0,40)
button.Text = "PULL: OFF"

local tpButton = Instance.new("TextButton", main)
tpButton.Size = UDim2.new(1,-20,0,35)
tpButton.Position = UDim2.new(0,10,0,80)
tpButton.Text = "TP ALL: OFF"

local hideButton = Instance.new("TextButton", main)
hideButton.Size = UDim2.new(1,-20,0,35)
hideButton.Position = UDim2.new(0,10,0,120)
hideButton.Text = "MINIMIZAR"

local aimButton = Instance.new("TextButton", main)
aimButton.Size = UDim2.new(1,-20,0,35)
aimButton.Position = UDim2.new(0,10,0,160)
aimButton.Text = "AIM LOCK: OFF"

local noclipButton = Instance.new("TextButton", main)
noclipButton.Size = UDim2.new(1,-20,0,35)
noclipButton.Position = UDim2.new(0,10,0,200)
noclipButton.Text = "NOCLIP: OFF"

local speedBox = Instance.new("TextBox", main)
speedBox.Size = UDim2.new(1,-20,0,30)
speedBox.Position = UDim2.new(0,10,0,240)
speedBox.PlaceholderText = "Speed (ex: 100)"
speedBox.Text = ""
speedBox.TextScaled = true
speedBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
speedBox.TextColor3 = Color3.new(1,1,1)

local speedButton = Instance.new("TextButton", main)
speedButton.Size = UDim2.new(1,-20,0,30)
speedButton.Position = UDim2.new(0,10,0,275)
speedButton.Text = "SET SPEED"

-- NOVO (sem mexer nos outros)
local jumpBox = Instance.new("TextBox", main)
jumpBox.Size = UDim2.new(1,-20,0,30)
jumpBox.Position = UDim2.new(0,10,0,310)
jumpBox.PlaceholderText = "Jump (ex: 150)"
jumpBox.Text = ""
jumpBox.TextScaled = true
jumpBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
jumpBox.TextColor3 = Color3.new(1,1,1)

local jumpButton = Instance.new("TextButton", main)
jumpButton.Size = UDim2.new(1,-20,0,30)
jumpButton.Position = UDim2.new(0,10,0,345)
jumpButton.Text = "SET JUMP"

speedButton.MouseButton1Click:Connect(function()
    local value = tonumber(speedBox.Text)
    if value then
        currentSpeed = value
    end
end)

jumpButton.MouseButton1Click:Connect(function()
    local value = tonumber(jumpBox.Text)
    if value then
        currentJump = value
    end
end)

local openButton = Instance.new("TextButton", screenGui)
openButton.Size = UDim2.new(0,60,0,30)
openButton.Position = UDim2.new(0,10,0,10)
openButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
openButton.Text = "OPEN"
openButton.Visible = false

button.MouseButton1Click:Connect(function()
    enabled = not enabled
    button.Text = enabled and "PULL: ON" or "PULL: OFF"
end)

tpButton.MouseButton1Click:Connect(function()
    tpEnabled = not tpEnabled
    tpButton.Text = tpEnabled and "TP ALL: ON" or "TP ALL: OFF"
end)

aimButton.MouseButton1Click:Connect(function()
    aimLockEnabled = not aimLockEnabled
    fovCircle.Visible = aimLockEnabled
    aimButton.Text = aimLockEnabled and "AIM LOCK: ON" or "AIM LOCK: OFF"
end)

noclipButton.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    noclipButton.Text = noclipEnabled and "NOCLIP: ON" or "NOCLIP: OFF"
end)

hideButton.MouseButton1Click:Connect(function()
    main.Visible = false
    openButton.Visible = true
end)

openButton.MouseButton1Click:Connect(function()
    main.Visible = true
    openButton.Visible = false
end)
