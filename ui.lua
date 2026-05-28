repeat task.wait() until game:IsLoaded()

-- newcclosure executor global env'inden alinir
local newcclosure = newcclosure or (getgenv and getgenv().newcclosure)


local Players = game:GetService('Players')
local Player = Players.LocalPlayer

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local VirtualInputManager = game:GetService("VirtualInputManager")

local Aerodynamic = false
local Aerodynamic_Time = tick()

local UserInputService = game:GetService('UserInputService')
local Last_Input = UserInputService:GetLastInputType()

local Debris = game:GetService('Debris')
local RunService = game:GetService('RunService')

local Alive = workspace.Alive

getgenv().Trail_Ball_Enabled = false
getgenv().self_effect_Enabled = false

local Vector2_Mouse_Location = nil
local Grab_Parry = nil

local Remotes = {}
local Parry_Key = nil

local revertedRemotes = {}

local function isValidRemoteArgs(args)
    return #args == 7 and
           type(args[2]) == "string" and
           type(args[3]) == "number" and
           typeof(args[4]) == "CFrame" and
           type(args[5]) == "table" and
           type(args[6]) == "table" and
           type(args[7]) == "boolean"
end

local function restoreRemotes()
    revertedRemotes = {}
end

-- BAC bypass: replaceclosure
-- clonefunction ile orijinalin kopyasi alinir, boylece replaceclosure
-- sonrasinda origFS/origIS kendini cagirmaz (sonsuz dongü olmaz).
local dummyEvent = Instance.new("RemoteEvent")
local dummyFunc  = Instance.new("RemoteFunction")

local rawFS = dummyEvent.FireServer
local rawIS = dummyFunc.InvokeServer

local origFS = clonefunction(rawFS)
local origIS = clonefunction(rawIS)

replaceclosure(rawFS, newcclosure(function(self, ...)
    local args = { ... }
    if isValidRemoteArgs(args) then
        if not revertedRemotes[self] then
            revertedRemotes[self] = args
        end
    end
    return origFS(self, ...)
end))

replaceclosure(rawIS, newcclosure(function(self, ...)
    local args = { ... }
    if isValidRemoteArgs(args) then
        if not revertedRemotes[self] then
            revertedRemotes[self] = args
        end
    end
    return origIS(self, ...)
end))



local Key = Parry_Key
local Parries = 0

function create_animation(object, info, value)
    local animation = game:GetService('TweenService'):Create(object, info, value)

    animation:Play()
    task.wait(info.Time)

    Debris:AddItem(animation, 0)

    animation:Destroy()
    animation = nil
end

local Animation = {}
Animation.storage = {}

Animation.current = nil
Animation.track = nil

for _, v in pairs(game:GetService("ReplicatedStorage").Misc.Emotes:GetChildren()) do
    if v:IsA("Animation") and v:GetAttribute("EmoteName") then
        local Emote_Name = v:GetAttribute("EmoteName")
        Animation.storage[Emote_Name] = v
    end
end

local Emotes_Data = {}

for Object in pairs(Animation.storage) do
    table.insert(Emotes_Data, Object)
end

table.sort(Emotes_Data)

local RbxAnalyticsService = game:GetService('RbxAnalyticsService')

local client_id = RbxAnalyticsService:GetClientId()

local Auto_Parry = {}

function Auto_Parry.Parry_Animation()
    local Parry_Animation = game:GetService("ReplicatedStorage").Shared.SwordAPI.Collection.Default:FindFirstChild('GrabParry')
    local Current_Sword = Player.Character:GetAttribute('CurrentlyEquippedSword')

    if not Current_Sword then
        return
    end

    if not Parry_Animation then
        return
    end

    local Sword_Data = game:GetService("ReplicatedStorage").Shared.ReplicatedInstances.Swords.GetSword:Invoke(Current_Sword)

    if not Sword_Data or not Sword_Data['AnimationType'] then
        return
    end

    for _, object in pairs(game:GetService('ReplicatedStorage').Shared.SwordAPI.Collection:GetChildren()) do
        if object.Name == Sword_Data['AnimationType'] then
            if object:FindFirstChild('GrabParry') or object:FindFirstChild('Grab') then
                local sword_animation_type = 'GrabParry'

                if object:FindFirstChild('Grab') then
                    sword_animation_type = 'Grab'
                end

                Parry_Animation = object[sword_animation_type]
            end
        end
    end

    Grab_Parry = Player.Character.Humanoid.Animator:LoadAnimation(Parry_Animation)
    Grab_Parry:Play()
end

function Auto_Parry.Play_Animation(v)
    local Animations = Animation.storage[v]

    if not Animations then
        return false
    end

    local Animator = Player.Character.Humanoid.Animator

    if Animation.track then
        Animation.track:Stop()
    end

    Animation.track = Animator:LoadAnimation(Animations)
    Animation.track:Play()

    Animation.current = v
end

function Auto_Parry.Get_Balls()
    local Balls = {}

    for _, Instance in pairs(workspace.Balls:GetChildren()) do
        if Instance:GetAttribute('realBall') then
            Instance.CanCollide = false
            table.insert(Balls, Instance)
        end
    end
    return Balls
end

function Auto_Parry.Get_Ball()
    for _, Instance in pairs(workspace.Balls:GetChildren()) do
        if Instance:GetAttribute('realBall') then
            Instance.CanCollide = false
            return Instance
        end
    end
end

function Auto_Parry.Parry_Data()
    local Camera = workspace.CurrentCamera
    if not Camera then return {0, CFrame.new(), {}, {0, 0}} end

    if Last_Input == Enum.UserInputType.MouseButton1 or Last_Input == Enum.UserInputType.MouseButton2 or Last_Input == Enum.UserInputType.Keyboard then
        Vector2_Mouse_Location = {UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y}
    else
        Vector2_Mouse_Location = {Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2}
    end

    local directionMap = {
        ['Backwards'] = function()
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - (Camera.CFrame.LookVector * 1000))
        end,
        ['Random'] = function()
            return CFrame.new(Camera.CFrame.Position, Vector3.new(math.random(-3000,3000), math.random(-3000,3000), math.random(-3000,3000)))
        end,
        ['Custom'] = function()
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + (Camera.CFrame.LookVector * 1000))
        end,
        ['Default'] = function()
            return Camera.CFrame
        end
    }

    return {0, directionMap[Auto_Parry.Parry_Type] and directionMap[Auto_Parry.Parry_Type]() or Camera.CFrame, {}, Vector2_Mouse_Location}
end

local FirstParryDone = false
Auto_Parry.Parry = function()
    local Parry_Data = Auto_Parry.Parry_Data()
    
    local hasRemotes = false
    for k, v in pairs(revertedRemotes) do
        hasRemotes = true
        break
    end
    
    if not hasRemotes then
        -- VirtualInputManager fallback: max 1 kez/saniye (spam aramaları server transfer yapmaz)
        local now = tick()
        if (now - (Auto_Parry._lastVIM or 0)) >= 1 then
            Auto_Parry._lastVIM = now
            local cam = workspace.CurrentCamera
            local viewport = cam and cam.ViewportSize or Vector2.new(500, 500)
            VirtualInputManager:SendMouseButtonEvent(viewport.X/2, viewport.Y/2, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(viewport.X/2, viewport.Y/2, 0, false, game, 0)
        end
        return
    else
        for remote, originalArgs in pairs(revertedRemotes) do
            local modifiedArgs = {
                originalArgs[1],
                originalArgs[2],
                originalArgs[3],
                Parry_Data[2],
                originalArgs[5],
                originalArgs[6],
                originalArgs[7]
            }
            
            if remote:IsA("RemoteEvent") then
                pcall(function() remote:FireServer(unpack(modifiedArgs)) end)
            elseif remote:IsA("RemoteFunction") then
                pcall(function() remote:InvokeServer(unpack(modifiedArgs)) end)
            end
        end
    end

    if Parries > 7 then
        return false
    end

    Parries += 1

    task.delay(0.5, function()
        if Parries > 0 then
            Parries -= 1
        end
    end)
end

local Lerp_Radians = 0
local Last_Warping = tick()

function Auto_Parry.Linear_Interpolation(a, b, time_volume)
    return a + (b - a) * time_volume
end

local Previous_Velocity = {}
local Curving = tick()

local Runtime = workspace.Runtime

function Auto_Parry.Is_Curved()
    local Ball = Auto_Parry.Get_Ball()

    if not Ball then
        return false
    end

    local Zoomies = Ball:FindFirstChild('zoomies')

    if not Zoomies then
        return false
    end

    local Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()

    local Velocity = Zoomies.VectorVelocity
    local Ball_Direction = Velocity.Unit

    local Direction = (Player.Character.PrimaryPart.Position - Ball.Position).Unit
    local Dot = Direction:Dot(Ball_Direction)

    local Speed = Velocity.Magnitude

    local Speed_Threshold = math.min(Speed / 100, 40)
    local Angle_Threshold = 40 * math.max(Dot, 0)

    local Direction_Difference = (Ball_Direction - Velocity).Unit
    local Direction_Similarity = Direction:Dot(Direction_Difference)

    local Dot_Difference = Dot - Direction_Similarity
    local Dot_Threshold = 0.5 - Ping / 1000

    local Distance = (Player.Character.PrimaryPart.Position - Ball.Position).Magnitude
    local Reach_Time = Distance / Speed - (Ping / 1000)

    local Enough_Speed = Speed > 100
    local Ball_Distance_Threshold = 15 - math.min(Distance / 1000, 15) + Angle_Threshold + Speed_Threshold

    table.insert(Previous_Velocity, Velocity)

    if #Previous_Velocity > 4 then
        table.remove(Previous_Velocity, 1)
    end

    if Enough_Speed and Reach_Time > Ping / 10 then
        Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15)
    end

    if Distance < Ball_Distance_Threshold then
        return false
    end

    if (tick() - Curving) < Reach_Time / 1.5 then --warn('Curving')
        return true
    end

    if Dot_Difference < Dot_Threshold then
        return true
    end

    local Radians = math.rad(math.asin(Dot))

    Lerp_Radians = Auto_Parry.Linear_Interpolation(Lerp_Radians, Radians, 0.8)

    if Lerp_Radians < 0.018 then
        Last_Warping = tick()
    end

    if (tick() - Last_Warping) < (Reach_Time / 1.5) then
        return true
    end

    if #Previous_Velocity == 4 then
        local Intended_Direction_Difference = (Ball_Direction - Previous_Velocity[1].Unit).Unit

        local Intended_Dot = Direction:Dot(Intended_Direction_Difference)
        local Intended_Dot_Difference = Dot - Intended_Dot

        local Intended_Direction_Difference2 = (Ball_Direction - Previous_Velocity[2].Unit).Unit

        local Intended_Dot2 = Direction:Dot(Intended_Direction_Difference2)
        local Intended_Dot_Difference2 = Dot - Intended_Dot2

        if Intended_Dot_Difference < Dot_Threshold or Intended_Dot_Difference2 < Dot_Threshold then
            return true
        end
    end

    if (tick() - Last_Warping) < (Reach_Time / 1.5) then
        return true
    end

    return Dot < Dot_Threshold
end

local Closest_Entity = nil

function Auto_Parry.Closest_Player()
    local Max_Distance = math.huge

    for _, Entity in pairs(workspace.Alive:GetChildren()) do
        if tostring(Entity) ~= tostring(Player) then
            local Distance = Player:DistanceFromCharacter(Entity.PrimaryPart.Position)

            if Distance < Max_Distance then
                Max_Distance = Distance
                Closest_Entity = Entity
            end
        end
    end
    return Closest_Entity
end

function Auto_Parry:Get_Entity_Properties()
    Auto_Parry.Closest_Player()

    if not Closest_Entity then
        return false
    end

    local Entity_Velocity = Closest_Entity.PrimaryPart.Velocity
    local Entity_Direction = (Player.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit
    local Entity_Distance = (Player.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude

    return {
        Velocity = Entity_Velocity,
        Direction = Entity_Direction,
        Distance = Entity_Distance
    }
end

function Auto_Parry:Get_Ball_Properties()
    local Ball = Auto_Parry.Get_Ball()

    local Ball_Velocity = Vector3.zero
    local Ball_Origin = Ball

    local Ball_Direction = (Player.Character.PrimaryPart.Position - Ball_Origin.Position).Unit
    local Ball_Distance = (Player.Character.PrimaryPart.Position - Ball.Position).Magnitude
    local Ball_Dot = Ball_Direction:Dot(Ball_Velocity.Unit)

    return {
        Velocity = Ball_Velocity,
        Direction = Ball_Direction,
        Distance = Ball_Distance,
        Dot = Ball_Dot
    }
end

function Auto_Parry:Spam_Service()
    local Ball = Auto_Parry.Get_Ball()

    if not Ball then
        return false
    end

    Auto_Parry.Closest_Player()

    local Spam_Accuracy = 0

    local Velocity = Ball.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude

    local Direction = (Player.Character.PrimaryPart.Position - Ball.Position).Unit
    local Dot = Direction:Dot(Velocity.Unit)

    local Target_Position = Closest_Entity.PrimaryPart.Position
    local Target_Distance = Player:DistanceFromCharacter(Target_Position)

    local Maximum_Spam_Distance = self.Ping + math.min(Speed / 6.5, 95)

    if self.Entity_Properties.Distance > Maximum_Spam_Distance then
        return Spam_Accuracy
    end

    if self.Ball_Properties.Distance > Maximum_Spam_Distance then
        return Spam_Accuracy
    end

    if Target_Distance > Maximum_Spam_Distance then
        return Spam_Accuracy
    end

    local Maximum_Speed = 5 - math.min(Speed / 5, 5)
    local Maximum_Dot = math.clamp(Dot, -1, 0) * Maximum_Speed

    Spam_Accuracy = Maximum_Spam_Distance - Maximum_Dot

    return Spam_Accuracy
end

local Connections_Manager = {}
local Selected_Parry_Type = nil

local Parried = false
local Last_Parry = 0

getgenv().Trail_Enabled = true -- Toggle on/off

-- Black color sequence
local blackSequence = ColorSequence.new(Color3.new(0, 0, 0))

-- Trail creator
local function addTrail(ball)
	if ball and ball:IsA("BasePart") and not ball:FindFirstChild("Trail") then
		local att0 = Instance.new("Attachment")
		att0.Position = Vector3.new(0, 0.5, 0)
		att0.Parent = ball

		local att1 = Instance.new("Attachment")
		att1.Position = Vector3.new(0, -0.5, 0)
		att1.Parent = ball

		local trail = Instance.new("Trail")
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.Color = blackSequence
		trail.Lifetime = 0.2
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.MinLength = 0.1
		trail.Parent = ball
	end
end

-- Main toggleable loop
task.defer(function()
	RunService.RenderStepped:Connect(function()
		if getgenv().Trail_Ball_Enabled then
			local ball = Auto_Parry.Get_Ball()
			addTrail(ball)
		end
	end)
end)

task.defer(function()
	game:GetService("RunService").Heartbeat:Connect(function()

		if not Player.Character then
			return
		end

		if getgenv().self_effect_Enabled then
			local effect = game:GetObjects("rbxassetid://17519530107")[1]

			effect.Name = 'nurysium_efx'

			if Player.Character.PrimaryPart:FindFirstChild('nurysium_efx') then
				return
			end

			effect.Parent = Player.Character.PrimaryPart
		else

			if Player.Character.PrimaryPart:FindFirstChild('nurysium_efx') then
				Player.Character.PrimaryPart['nurysium_efx']:Destroy()
			end
		end

	end)
end)

-- ==================== ESP FUNCTIONALITY ====================

local Camera = workspace.CurrentCamera
getgenv().espEnabled = getgenv().espEnabled or false
getgenv().espTracers = getgenv().espTracers or false
getgenv().espNames = getgenv().espNames or false
getgenv().espBoxes = getgenv().espBoxes or false

local espObjects = {}

local function createESP(player)
    if player == Player then return end
    if espObjects[player] then return end
    local esp = { box = nil, name = nil, tracer = nil }
    if getgenv().espBoxes then
        esp.box = Drawing.new("Square")
        esp.box.Visible = false
        esp.box.Color = Color3.fromRGB(255, 255, 255)
        esp.box.Thickness = 2
        esp.box.Transparency = 1
        esp.box.Filled = false
    end
    if getgenv().espNames then
        esp.name = Drawing.new("Text")
        esp.name.Visible = false
        esp.name.Color = Color3.fromRGB(255, 255, 255)
        esp.name.Size = 14
        esp.name.Center = true
        esp.name.Outline = true
        esp.name.OutlineColor = Color3.fromRGB(0, 0, 0)
        esp.name.Text = player.Name
    end
    if getgenv().espTracers then
        esp.tracer = Drawing.new("Line")
        esp.tracer.Visible = false
        esp.tracer.Color = Color3.fromRGB(255, 255, 255)
        esp.tracer.Thickness = 1
        esp.tracer.Transparency = 1
    end
    espObjects[player] = esp
end

local function removeESP(player)
    if espObjects[player] then
        if espObjects[player].box then espObjects[player].box:Remove() end
        if espObjects[player].name then espObjects[player].name:Remove() end
        if espObjects[player].tracer then espObjects[player].tracer:Remove() end
        espObjects[player] = nil
    end
end

local function getBoundingBox(character)
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil, nil, nil, nil, nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local size = hrp.Size
    local cf = hrp.CFrame
    local corners = {
        Vector3.new(-size.X/2, -size.Y/2, -size.Z/2), Vector3.new(size.X/2, -size.Y/2, -size.Z/2),
        Vector3.new(size.X/2, size.Y/2, -size.Z/2), Vector3.new(-size.X/2, size.Y/2, -size.Z/2),
        Vector3.new(-size.X/2, -size.Y/2, size.Z/2), Vector3.new(size.X/2, -size.Y/2, size.Z/2),
        Vector3.new(size.X/2, size.Y/2, size.Z/2), Vector3.new(-size.X/2, size.Y/2, size.Z/2)
    }
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    local hasVisible = false
    for _, corner in ipairs(corners) do
        local worldPos = (cf * CFrame.new(corner)).Position
        local screenPoint, onScreen = Camera:WorldToViewportPoint(worldPos)
        if onScreen then
            hasVisible = true
            minX = math.min(minX, screenPoint.X)
            maxX = math.max(maxX, screenPoint.X)
            minY = math.min(minY, screenPoint.Y)
            maxY = math.max(maxY, screenPoint.Y)
        end
    end
    if not hasVisible then return nil, nil, nil, nil, nil end
    return minX, maxX, minY, maxY, hrp.Position
end

local function updateESPDraw()
    if not getgenv().espEnabled then
        for _, esp in pairs(espObjects) do
            if esp.box then esp.box.Visible = false end
            if esp.name then esp.name.Visible = false end
            if esp.tracer then esp.tracer.Visible = false end
        end
        return
    end
    for player, esp in pairs(espObjects) do
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local minX, maxX, minY, maxY, worldPos = getBoundingBox(character)
            if minX and Camera then
                local _, onScreen = Camera:WorldToViewportPoint(worldPos)
                if onScreen then
                    if esp.box and getgenv().espBoxes then
                        esp.box.Visible = true
                        esp.box.Size = Vector2.new(maxX - minX, maxY - minY)
                        esp.box.Position = Vector2.new(minX, minY)
                    elseif esp.box then esp.box.Visible = false end
                    if esp.name and getgenv().espNames then
                        esp.name.Visible = true
                        esp.name.Position = Vector2.new((minX + maxX) / 2, minY - 20)
                    elseif esp.name then esp.name.Visible = false end
                    if esp.tracer and getgenv().espTracers then
                        esp.tracer.Visible = true
                        esp.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        esp.tracer.To = Vector2.new((minX + maxX) / 2, maxY)
                    elseif esp.tracer then esp.tracer.Visible = false end
                else
                    if esp.box then esp.box.Visible = false end
                    if esp.name then esp.name.Visible = false end
                    if esp.tracer then esp.tracer.Visible = false end
                end
            end
        end
    end
end

getgenv().updateESP = function()
    if not getgenv().espEnabled then
        for _, esp in pairs(espObjects) do
            if esp.box then esp.box.Visible = false end
            if esp.name then esp.name.Visible = false end
            if esp.tracer then esp.tracer.Visible = false end
        end
    else
        for player, esp in pairs(espObjects) do
            if getgenv().espBoxes and not esp.box then
                esp.box = Drawing.new("Square")
                esp.box.Visible = false
                esp.box.Color = Color3.fromRGB(255, 255, 255)
                esp.box.Thickness = 2
                esp.box.Transparency = 1
                esp.box.Filled = false
            elseif not getgenv().espBoxes and esp.box then
                esp.box:Remove(); esp.box = nil
            end
            if getgenv().espNames and not esp.name then
                esp.name = Drawing.new("Text")
                esp.name.Visible = false
                esp.name.Color = Color3.fromRGB(255, 255, 255)
                esp.name.Size = 14
                esp.name.Center = true
                esp.name.Outline = true
                esp.name.OutlineColor = Color3.fromRGB(0, 0, 0)
                esp.name.Text = player.Name
            elseif not getgenv().espNames and esp.name then
                esp.name:Remove(); esp.name = nil
            end
            if getgenv().espTracers and not esp.tracer then
                esp.tracer = Drawing.new("Line")
                esp.tracer.Visible = false
                esp.tracer.Color = Color3.fromRGB(255, 255, 255)
                esp.tracer.Thickness = 1
                esp.tracer.Transparency = 1
            elseif not getgenv().espTracers and esp.tracer then
                esp.tracer:Remove(); esp.tracer = nil
            end
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do createESP(player) end
Players.PlayerAdded:Connect(function(player) createESP(player) end)
Players.PlayerRemoving:Connect(function(player) removeESP(player) end)

local espUpdateCounter = 0
RunService.Heartbeat:Connect(function()
    espUpdateCounter += 1
    if espUpdateCounter % 2 == 0 and getgenv().espEnabled then
        updateESPDraw()
    end
end)

-- ==================== END ESP FUNCTIONALITY ====================


-- ==================== AUTO PLAY FUNCTIONALITY ====================

getgenv().autoPlay = getgenv().autoPlay or false
getgenv().autoVote = getgenv().autoVote or false
getgenv().autoAbility = getgenv().autoAbility or false

local AutoPlayModule = {}
AutoPlayModule.CONFIG = {
    DEFAULT_DISTANCE = 30,
    MULTIPLIER_THRESHOLD = 70,
    TRAVERSING = 25,
    DIRECTION = 1,
    JUMP_PERCENTAGE = 50,
    DOUBLE_JUMP_PERCENTAGE = 50,
    JUMPING_ENABLED = false,
    MOVEMENT_DURATION = 0.8,
    OFFSET_FACTOR = 0.7,
    GENERATION_THRESHOLD = 0.25,
}
AutoPlayModule.ball = nil
AutoPlayModule.lobbyChoice = nil
AutoPlayModule.animationCache = nil
AutoPlayModule.doubleJumped = false
AutoPlayModule.ELAPSED = 0
AutoPlayModule.CONTROL_POINT = nil
AutoPlayModule.LAST_GENERATION = 0
AutoPlayModule.signals = {}

AutoPlayModule.playerHelper = {
    isAlive = function(player)
        local character = player and player.Character
        if not character then return false end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        if not rootPart or not humanoid then return false end
        return humanoid.Health > 0
    end,
    inLobby = function(character)
        if not character then return false end
        return character.Parent == workspace:FindFirstChild("Dead")
    end,
    onGround = function(character)
        if not character then return false end
        return character.Humanoid.FloorMaterial ~= Enum.Material.Air
    end,
}

function AutoPlayModule.isLimited()
    return (tick() - AutoPlayModule.LAST_GENERATION) < AutoPlayModule.CONFIG.GENERATION_THRESHOLD
end

function AutoPlayModule.percentageCheck(limit)
    if AutoPlayModule.isLimited() then return false end
    local percentage = math.random(100)
    AutoPlayModule.LAST_GENERATION = tick()
    return limit >= percentage
end

AutoPlayModule.ballUtils = {
    getBall = function()
        local balls = workspace:FindFirstChild("Balls")
        if not balls then return end
        for _, object in pairs(balls:GetChildren()) do
            if object:GetAttribute("realBall") then
                AutoPlayModule.ball = object
                return
            end
        end
        AutoPlayModule.ball = nil
    end,
    getDirection = function()
        if not AutoPlayModule.ball or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
        return (Player.Character.HumanoidRootPart.Position - AutoPlayModule.ball.Position).Unit
    end,
    getVelocity = function()
        if not AutoPlayModule.ball then return end
        local zoomies = AutoPlayModule.ball:FindFirstChild("zoomies")
        if not zoomies then return end
        return zoomies.VectorVelocity
    end,
    getSpeed = function()
        local velocity = AutoPlayModule.ballUtils.getVelocity()
        if not velocity then return end
        return velocity.Magnitude
    end,
    isExisting = function()
        return AutoPlayModule.ball ~= nil
    end,
}

AutoPlayModule.lerp = function(s, f, a) return s + (f - s) * a end
AutoPlayModule.quadratic = function(s, m, f, a)
    return AutoPlayModule.lerp(AutoPlayModule.lerp(s, m, a), AutoPlayModule.lerp(m, f, a), a)
end

AutoPlayModule.getControlPoint = function(start, finish)
    local middle = (start + finish) * 0.5
    local difference = start - finish
    if difference.Magnitude < 5 then return finish end
    local theta = math.atan2(difference.Z, difference.X)
    local offsetLength = difference.Magnitude * AutoPlayModule.CONFIG.OFFSET_FACTOR
    local firstCX = math.cos(theta + math.pi/2); local firstCZ = math.sin(theta + math.pi/2)
    local secondCX = math.cos(theta - math.pi/2); local secondCZ = math.sin(theta - math.pi/2)
    local first = middle + Vector3.new(firstCX, 0, firstCZ) * offsetLength
    local second = middle + Vector3.new(secondCX, 0, secondCZ) * offsetLength
    local dotValue = start - middle
    if (first - middle):Dot(dotValue) < 0 then return first else return second end
end

AutoPlayModule.getCurve = function(start, finish, delta)
    AutoPlayModule.ELAPSED = AutoPlayModule.ELAPSED + delta
    local timeElapsed = math.clamp(AutoPlayModule.ELAPSED / AutoPlayModule.CONFIG.MOVEMENT_DURATION, 0, 1)
    if timeElapsed >= 1 then
        if (start - finish).Magnitude >= 10 then AutoPlayModule.ELAPSED = 0 end
        AutoPlayModule.CONTROL_POINT = nil
        return finish
    end
    if not AutoPlayModule.CONTROL_POINT then
        AutoPlayModule.CONTROL_POINT = AutoPlayModule.getControlPoint(start, finish)
    end
    if not AutoPlayModule.CONTROL_POINT then return finish end
    return AutoPlayModule.quadratic(start, AutoPlayModule.CONTROL_POINT, finish, timeElapsed)
end

AutoPlayModule.map = {
    getFloor = function()
        local floor = workspace:FindFirstChild("FLOOR")
        if not floor then
            for _, part in pairs(workspace:GetDescendants()) do
                if (part:IsA("MeshPart") or part:IsA("BasePart")) then
                    local size = part.Size
                    if size.X > 50 and size.Z > 50 and part.Position.Y < 5 then return part end
                end
            end
        end
        return floor
    end,
}

AutoPlayModule.getRandomPosition = function()
    local floor = AutoPlayModule.map.getFloor()
    if not floor or not AutoPlayModule.ballUtils.isExisting() then return end
    local ballDirection = AutoPlayModule.ballUtils.getDirection() * AutoPlayModule.CONFIG.DIRECTION
    local ballSpeed = AutoPlayModule.ballUtils.getSpeed()
    if not ballDirection or not ballSpeed then return end
    local speedThreshold = math.min(ballSpeed / 10, AutoPlayModule.CONFIG.MULTIPLIER_THRESHOLD)
    local speedMultiplier = AutoPlayModule.CONFIG.DEFAULT_DISTANCE + speedThreshold
    local negativeDirection = ballDirection * speedMultiplier
    local currentTime = os.time() / 1.2
    local traversing = Vector3.new(math.sin(currentTime), 0, math.cos(currentTime)) * AutoPlayModule.CONFIG.TRAVERSING
    return floor.Position + negativeDirection + traversing
end

AutoPlayModule.lobby = {
    isChooserAvailable = function()
        local spawn = workspace:FindFirstChild("Spawn")
        if not spawn then return false end
        local npc = spawn:FindFirstChild("NewPlayerCounter")
        if not npc then return false end
        local gui = npc:FindFirstChild("GUI")
        if not gui then return false end
        local sg = gui:FindFirstChild("SurfaceGui")
        if not sg then return false end
        local top = sg:FindFirstChild("Top")
        if not top then return false end
        local options = top:FindFirstChild("Options")
        return options and options.Visible or false
    end,
    updateChoice = function(choice)
        AutoPlayModule.lobbyChoice = choice
    end,
    getMapChoice = function()
        local choice = AutoPlayModule.lobbyChoice or math.random(1, 3)
        local spawn = workspace:FindFirstChild("Spawn")
        if not spawn then return end
        local npc = spawn:FindFirstChild("NewPlayerCounter")
        if not npc then return end
        local colliders = npc:FindFirstChild("Colliders")
        if not colliders then return end
        return colliders:FindFirstChild(tostring(choice))
    end,
    getPadPosition = function()
        if not AutoPlayModule.lobby.isChooserAvailable() then
            AutoPlayModule.lobbyChoice = nil; return
        end
        local choice = AutoPlayModule.lobby.getMapChoice()
        if not choice then return end
        return choice.Position, choice.Name
    end,
}

AutoPlayModule.movement = {
    removeCache = function()
        AutoPlayModule.animationCache = nil
    end,
    createJumpVelocity = function(player)
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
        local velocity = Instance.new("BodyVelocity")
        velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        velocity.Velocity = Vector3.new(0, 80, 0)
        velocity.Parent = player.Character.HumanoidRootPart
        Debris:AddItem(velocity, 0.001)
        local doubleJumpRemote = ReplicatedStorage:FindFirstChild("Remotes")
        if doubleJumpRemote then
            doubleJumpRemote = doubleJumpRemote:FindFirstChild("DoubleJump")
            if doubleJumpRemote then doubleJumpRemote:FireServer() end
        end
    end,
    doubleJump = function(player)
        if AutoPlayModule.doubleJumped then return end
        if not AutoPlayModule.percentageCheck(AutoPlayModule.CONFIG.DOUBLE_JUMP_PERCENTAGE) then return end
        AutoPlayModule.doubleJumped = true
        AutoPlayModule.movement.createJumpVelocity(player)
    end,
    jump = function(player)
        if not AutoPlayModule.CONFIG.JUMPING_ENABLED then return end
        if not AutoPlayModule.playerHelper.onGround(player.Character) then
            AutoPlayModule.movement.doubleJump(player); return
        end
        if not AutoPlayModule.percentageCheck(AutoPlayModule.CONFIG.JUMP_PERCENTAGE) then return end
        AutoPlayModule.doubleJumped = false
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end,
    move = function(player, playerPosition)
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid:MoveTo(playerPosition)
        end
    end,
    stop = function(player)
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
        player.Character.Humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
    end,
}

AutoPlayModule.signal = {
    connect = function(name, connection, callback)
        AutoPlayModule.signals[name] = connection:Connect(callback)
        return AutoPlayModule.signals[name]
    end,
    disconnect = function(name)
        if not name or not AutoPlayModule.signals[name] then return end
        AutoPlayModule.signals[name]:Disconnect()
        AutoPlayModule.signals[name] = nil
    end,
    stop = function()
        for name, connection in pairs(AutoPlayModule.signals) do
            if typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
                AutoPlayModule.signals[name] = nil
            end
        end
    end,
}

AutoPlayModule.findPath = function(inLobby, delta)
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    local rootPosition = Player.Character.HumanoidRootPart.Position
    if inLobby then
        local padPosition, padNumber = AutoPlayModule.lobby.getPadPosition()
        local choice = tonumber(padNumber)
        if choice then
            AutoPlayModule.lobby.updateChoice(choice)
            if getgenv().autoVote then
                local packages = ReplicatedStorage:FindFirstChild("Packages")
                if packages then
                    local _Index = packages:FindFirstChild("_Index")
                    if _Index then
                        local sleitnick_net = _Index:FindFirstChild("sleitnick_net@0.1.0")
                        if sleitnick_net then
                            local net = sleitnick_net:FindFirstChild("net")
                            if net then
                                local updateVotes = net:FindFirstChild("RE/UpdateVotes")
                                if updateVotes then updateVotes:FireServer("FFA") end
                            end
                        end
                    end
                end
            end
        end
        if not padPosition then return end
        return AutoPlayModule.getCurve(rootPosition, padPosition, delta)
    end
    local randomPosition = AutoPlayModule.getRandomPosition()
    if not randomPosition then return end
    return AutoPlayModule.getCurve(rootPosition, randomPosition, delta)
end

AutoPlayModule.followPath = function(delta)
    if not AutoPlayModule.playerHelper.isAlive(Player) then
        AutoPlayModule.movement.removeCache(); return
    end
    local inLobby = Player.Character and Player.Character.Parent == workspace:FindFirstChild("Dead")
    local path = AutoPlayModule.findPath(inLobby, delta)
    if not path then
        AutoPlayModule.movement.stop(Player); return
    end
    AutoPlayModule.movement.move(Player, path)
    AutoPlayModule.movement.jump(Player)
end

AutoPlayModule.finishThread = function()
    AutoPlayModule.signal.disconnect("auto-play")
    AutoPlayModule.signal.disconnect("synchronize")
    if AutoPlayModule.playerHelper.isAlive(Player) then
        AutoPlayModule.movement.stop(Player)
    end
end

AutoPlayModule.runThread = function()
    AutoPlayModule.signal.connect("auto-play", RunService.PostSimulation, AutoPlayModule.followPath)
    AutoPlayModule.signal.connect("synchronize", RunService.PostSimulation, AutoPlayModule.ballUtils.getBall)
end

-- ==================== END AUTO PLAY FUNCTIONALITY ====================


-- ==================== AUTO ABILITY FUNCTIONALITY ====================

getgenv().AutoAbility = function()
    if not Player.Character then return false end
    local playerGui = Player:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    local hotbar = playerGui:FindFirstChild("Hotbar")
    if not hotbar then return false end
    local ability = hotbar:FindFirstChild("Ability")
    if not ability then return false end
    local abilityCD = ability:FindFirstChild("UIGradient")
    if not abilityCD then return false end
    if abilityCD.Offset and abilityCD.Offset.Y == 0.5 then
        local abilities = Player.Character:FindFirstChild("Abilities")
        if not abilities then return false end
        local abilityNames = {"Raging Deflection", "Dash", "Rapture", "Calming Deflection", "Aerodynamic Slash", "Fracture", "Death Slash"}
        for _, abilityName in ipairs(abilityNames) do
            local abilityObj = abilities:FindFirstChild(abilityName)
            if abilityObj and abilityObj.Enabled then
                pcall(function()
                    ReplicatedStorage.Remotes.AbilityButtonPress:Fire()
                end)
                return true
            end
        end
    end
    return false
end

getgenv().updateAutoAbility = function() end

-- ==================== END AUTO ABILITY FUNCTIONALITY ====================


-- ==================== DETECTIONS FUNCTIONALITY ====================

getgenv().InfinityDetection = getgenv().InfinityDetection or false
getgenv().DeathSlashDetection = getgenv().DeathSlashDetection or false
getgenv().TimeHoleDetection = getgenv().TimeHoleDetection or false
getgenv().DribbleDetection = getgenv().DribbleDetection or false
getgenv().SlashOfFuryDetection = getgenv().SlashOfFuryDetection or false
getgenv().PhantomV2Detection = getgenv().PhantomV2Detection or false

getgenv().Infinity = false
getgenv().deathBallActive = false
getgenv().timehole = false
getgenv().currentBall = nil
getgenv().focusConnection = nil

task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    -- Infinity Detection
    pcall(function()
        if rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("InfinityBall") then
            rs.Remotes.InfinityBall.OnClientEvent:Connect(function(a, b)
                getgenv().Infinity = b and true or false
            end)
        end
    end)
    -- Death Slash Detection
    pcall(function()
        if rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("DeathBall") then
            rs.Remotes.DeathBall.OnClientEvent:Connect(function(c, d)
                getgenv().deathBallActive = d and true or false
            end)
        end
    end)
    -- Time Hole Detection
    pcall(function()
        if rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("TimeHoleHoldBall") then
            rs.Remotes.TimeHoleHoldBall.OnClientEvent:Connect(function(e, f)
                getgenv().timehole = f and true or false
            end)
        end
    end)
    -- Slash of Fury Detection
    pcall(function()
        local balls = workspace:FindFirstChild("Balls")
        if balls then
            balls.ChildAdded:Connect(function(ball)
                ball.ChildAdded:Connect(function(child)
                    if getgenv().SlashOfFuryDetection and child.Name == "ComboCounter" then
                        local sofLabel = child:FindFirstChildOfClass("TextLabel")
                        if sofLabel then
                            task.spawn(function()
                                repeat
                                    local count = tonumber(sofLabel.Text)
                                    if count and count < 32 and getgenv().autoparry then
                                        pcall(function() Auto_Parry.Parry() end)
                                    end
                                    task.wait()
                                until not sofLabel.Parent
                            end)
                        end
                    end
                end)
            end)
        end
    end)
    -- Phantom V2 Detection
    pcall(function()
        local balls = workspace:FindFirstChild("Balls")
        local runtime = workspace:FindFirstChild("Runtime")
        if runtime then
            runtime.ChildAdded:Connect(function(object)
                local name = object.Name
                if getgenv().PhantomV2Detection then
                    if name == "maxTransmission" or name == "transmissionpart" then
                        local weld = object:FindFirstChildWhichIsA("WeldConstraint")
                        if weld then
                            local character = Player.Character or Player.CharacterAdded:Wait()
                            if character and weld.Part1 == character.HumanoidRootPart then
                                if balls then
                                    for _, ball in ipairs(balls:GetChildren()) do
                                        if ball:FindFirstChild("ff") then
                                            getgenv().currentBall = ball; break
                                        end
                                    end
                                end
                                weld:Destroy()
                                if getgenv().currentBall then
                                    if getgenv().focusConnection then getgenv().focusConnection:Disconnect() end
                                    getgenv().focusConnection = RunService.RenderStepped:Connect(function()
                                        if not getgenv().currentBall or not getgenv().currentBall.Parent then
                                            if getgenv().focusConnection then
                                                getgenv().focusConnection:Disconnect()
                                                getgenv().focusConnection = nil
                                            end
                                            return
                                        end
                                        local highlighted = getgenv().currentBall:GetAttribute("highlighted")
                                        if highlighted == true then
                                            if character and character:FindFirstChild("Humanoid") then
                                                character.Humanoid.WalkSpeed = 36
                                                local hrp = character:FindFirstChild("HumanoidRootPart")
                                                if hrp then
                                                    local dir = (getgenv().currentBall.Position - hrp.Position).Unit
                                                    character.Humanoid:Move(dir, false)
                                                end
                                            end
                                        elseif highlighted == false then
                                            if getgenv().focusConnection then
                                                getgenv().focusConnection:Disconnect()
                                                getgenv().focusConnection = nil
                                            end
                                            if character and character:FindFirstChild("Humanoid") then
                                                character.Humanoid.WalkSpeed = 10
                                                character.Humanoid:Move(Vector3.new(0,0,0), false)
                                                task.delay(3, function()
                                                    if character and character:FindFirstChild("Humanoid") then
                                                        character.Humanoid.WalkSpeed = 36
                                                    end
                                                end)
                                            end
                                            getgenv().currentBall = nil
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end)

-- ==================== END DETECTIONS FUNCTIONALITY ====================


-- ==================== SKIN CHANGER FUNCTIONALITY ====================

getgenv().skinChanger = getgenv().skinChanger or false
getgenv().swordModel = getgenv().swordModel or ""
getgenv().swordAnimations = getgenv().swordAnimations or ""
getgenv().swordFX = getgenv().swordFX or ""

task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local swordInstancesInstance = rs:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9)
    local swordInstances = require(swordInstancesInstance)

    local swordsController
    task.spawn(function()
        while task.wait() and not swordsController do
            for i, v in getconnections(rs.Remotes.FireSwordInfo.OnClientEvent) do
                if v.Function and islclosure(v.Function) then
                    local upvalues = getupvalues(v.Function)
                    if #upvalues == 1 and type(upvalues[1]) == "table" then
                        swordsController = upvalues[1]
                        break
                    end
                end
            end
        end
    end)

    local function getSlashName(swordName)
        local slashName = swordInstances:GetSword(swordName)
        return (slashName and slashName.SlashName) or "SlashEffect"
    end

    local function setSword()
        if not getgenv().skinChanger then return end
        if not Player.Character then return end

        -- Görünümü (mesh) değiştir
        pcall(function()
            local f = rawget(swordInstances, "EquipSwordTo")
            if type(f) == "function" then
                local ups = getupvalues(f)
                for i = 1, #ups do
                    if type(ups[i]) == "boolean" then
                        setupvalue(f, i, false)
                        break
                    end
                end
            end
        end)
        pcall(function()
            swordInstances:EquipSwordTo(Player.Character, getgenv().swordModel)
        end)

        -- Animasyon + Ses + Efekt: swordsController hazır olana kadar bekle
        task.spawn(function()
            local attempts = 0
            while not swordsController and attempts < 20 do
                task.wait(0.5)
                attempts += 1
            end
            if not swordsController then return end

            -- Animasyon
            pcall(function()
                if swordsController.SetSword then
                    swordsController:SetSword(getgenv().swordAnimations ~= "" and getgenv().swordAnimations or getgenv().swordModel)
                end
            end)

            -- Ses + Efekt: FireSwordInfo remote'unu tetikle (oyunun kendi sistemi)
            pcall(function()
                local targetSword = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
                refreshSlashName()
                local swordData = swordInstances:GetSword(targetSword)
                if rs.Remotes:FindFirstChild("FireSwordInfo") then
                    rs.Remotes.FireSwordInfo:FireServer(targetSword)
                end
                -- swordsController üzerinden doğrudan güncelle
                if swordsController.currentSword ~= nil then
                    pcall(function() swordsController.currentSword = targetSword end)
                end
                if swordsController.SwordFX ~= nil then
                    pcall(function() swordsController.SwordFX = targetSword end)
                end
            end)
        end)
    end

    local function refreshSlashName()
        local fxName = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
        if fxName ~= "" then
            getgenv().slashName = getSlashName(fxName)
        else
            getgenv().slashName = "SlashEffect"
        end
    end
    refreshSlashName()

    local hookedFuncs = {}
    task.spawn(function()
        while task.wait(1) do
            local success, conns = pcall(getconnections, rs.Remotes.ParrySuccessAll.OnClientEvent)
            if success and type(conns) == "table" then
                for _, v in ipairs(conns) do
                    local func = v.Function
                    if func and not hookedFuncs[func] then
                        if isourclosure and isourclosure(func) then
                            hookedFuncs[func] = true
                            continue
                        end
                        
                        hookedFuncs[func] = true
                        v:Disable()
                        
                        local targetFunc = func
                        local ourFunc
                        ourFunc = function(...)
                            local args = { ... }
                            if tostring(args[4]) == Player.Name and getgenv().skinChanger then
                                local fxSword = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
                                refreshSlashName()
                                args[1] = getgenv().slashName
                                args[3] = fxSword
                            end
                            if setthreadidentity then pcall(setthreadidentity, 2) end
                            local callOk = pcall(targetFunc, unpack(args))
                            if not callOk then pcall(targetFunc, unpack(args)) end
                        end
                        hookedFuncs[ourFunc] = true
                        rs.Remotes.ParrySuccessAll.OnClientEvent:Connect(ourFunc)
                    end
                end
            end
        end
    end)

    getgenv().updateSword = function()
        refreshSlashName()
        setSword()
    end

    task.spawn(function()
        while task.wait(1) do
            if getgenv().skinChanger and getgenv().swordModel ~= "" then
                local char = Player.Character
                if char then
                    if Player:GetAttribute("CurrentlyEquippedSword") ~= getgenv().swordModel then
                        setSword()
                    end
                    if not char:FindFirstChild(getgenv().swordModel) then
                        setSword()
                    end
                    for _, v in char:GetChildren() do
                        if v:IsA("Model") and v.Name ~= getgenv().swordModel then
                            v:Destroy()
                        end
                        task.wait()
                    end
                end
            end
        end
    end)

    Player.CharacterAdded:Connect(function(char)
        if getgenv().skinChanger then
            getgenv().skinChanger = false
            if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(false) end
            task.wait(2)
            getgenv().skinChanger = true
            if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(true) end
            task.wait(0.5)
            pcall(function() getgenv().updateSword() end)
        end
    end)
end)

-- ==================== END SKIN CHANGER FUNCTIONALITY ====================


-- ==================== SKY CHANGER FUNCTIONALITY ====================

local Lighting = game:GetService("Lighting")

getgenv().customSky = getgenv().customSky or false
getgenv().selectedSky = getgenv().selectedSky or "Default"

getgenv().skyboxData = getgenv().skyboxData or {
    ["Default"] = { "591058823", "591059876", "591058104", "591057861", "591057625", "591059642" },
    ["Vaporwave"] = { "1417494030", "1417494146", "1417494253", "1417494402", "1417494499", "1417494643" },
    ["Redshift"] = { "401664839", "401664862", "401664960", "401664881", "401664901", "401664936" },
    ["Desert"] = { "1013852", "1013853", "1013850", "1013851", "1013849", "1013854" },
    ["DaBaby"] = { "7245418472", "7245418472", "7245418472", "7245418472", "7245418472", "7245418472" },
    ["Minecraft"] = { "1876545003", "1876544331", "1876542941", "1876543392", "1876543764", "1876544642" },
    ["SpongeBob"] = { "7633178166", "7633178166", "7633178166", "7633178166", "7633178166", "7633178166" },
    ["Skibidi"] = { "14952256113", "14952256113", "14952256113", "14952256113", "14952256113", "14952256113" },
    ["Blaze"] = { "150939022", "150939038", "150939047", "150939056", "150939063", "150939082" },
    ["Pussy Cat"] = { "11154422902", "11154422902", "11154422902", "11154422902", "11154422902", "11154422902" },
    ["Among Us"] = { "5752463190", "5752463190", "5752463190", "5752463190", "5752463190", "5752463190" },
    ["Space Wave"] = { "16262356578", "16262358026", "16262360469", "16262362003", "16262363873", "16262366016" },
    ["Space Wave2"] = { "1233158420", "1233158838", "1233157105", "1233157640", "1233157995", "1233159158" },
    ["Turquoise Wave"] = { "47974894", "47974690", "47974821", "47974776", "47974859", "47974909" },
    ["Dark Night"] = { "6285719338", "6285721078", "6285722964", "6285724682", "6285726335", "6285730635" },
    ["Bright Pink"] = { "271042516", "271077243", "271042556", "271042310", "271042467", "271077958" },
    ["White Galaxy"] = { "5540798456", "5540799894", "5540801779", "5540801192", "5540799108", "5540800635" },
    ["Blue Galaxy"] = { "14961495673", "14961494492", "14961492844", "14961491298", "14961490439", "14961489508" }
}

getgenv().applySkybox = function(skyName)
    local data = getgenv().skyboxData[skyName]
    if not data then return end
    local Sky = Lighting:FindFirstChildOfClass("Sky")
    if not Sky then
        Sky = Instance.new("Sky", Lighting)
    end
    local skyFaces = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
    for index, face in ipairs(skyFaces) do
        Sky[face] = "rbxassetid://" .. data[index]
    end
    Lighting.GlobalShadows = (skyName == "Default")
end

getgenv().updateSky = function()
    if getgenv().customSky then
        getgenv().applySkybox(getgenv().selectedSky)
    else
        getgenv().applySkybox("Default")
    end
end

-- ==================== END SKY CHANGER FUNCTIONALITY ====================


-- ==================== BALL STATS FUNCTIONALITY ====================

getgenv().ballStatsEnabled = getgenv().ballStatsEnabled or false
getgenv().VelocityGui = nil
getgenv().ballStatsUpdateConn = nil
getgenv().peakVelocity = 0
getgenv().VelocityLabel = nil
getgenv().PeakVelocityLabel = nil

getgenv().updateBallStats = function()
    if getgenv().ballStatsUpdateConn then
        getgenv().ballStatsUpdateConn:Disconnect()
        getgenv().ballStatsUpdateConn = nil
    end

    if getgenv().VelocityGui then
        getgenv().VelocityGui:Destroy()
        getgenv().VelocityGui = nil
    end

    if not getgenv().ballStatsEnabled then
        getgenv().peakVelocity = 0
        getgenv().VelocityLabel = nil
        getgenv().PeakVelocityLabel = nil
        return
    end

    getgenv().peakVelocity = 0
    local playerGui = Player:WaitForChild("PlayerGui")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")

    getgenv().VelocityGui = Instance.new("ScreenGui")
    getgenv().VelocityGui.Name = "VelocityGui"
    getgenv().VelocityGui.Parent = playerGui
    getgenv().VelocityGui.ResetOnSpawn = false
    getgenv().VelocityGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame", getgenv().VelocityGui)
    mainFrame.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
    mainFrame.BorderSizePixel = 0
    mainFrame.Size = UDim2.new(0, 220, 0, 120)
    mainFrame.Position = UDim2.new(0.02, 0, 0.15, 0)
    mainFrame.ZIndex = 2
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = Color3.fromRGB(138, 43, 226)
    stroke.Thickness = 2
    stroke.Transparency = 0.2

    local shadowFrame = Instance.new("Frame", getgenv().VelocityGui)
    shadowFrame.BackgroundColor3 = Color3.fromRGB(75, 0, 130)
    shadowFrame.BackgroundTransparency = 0.6
    shadowFrame.BorderSizePixel = 0
    shadowFrame.Size = UDim2.new(0, 220, 0, 120)
    shadowFrame.Position = UDim2.new(0.02, 2, 0.15, 2)
    shadowFrame.ZIndex = 1
    Instance.new("UICorner", shadowFrame).CornerRadius = UDim.new(0, 12)

    local titleLabel = Instance.new("TextLabel", mainFrame)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -20, 0, 25)
    titleLabel.Position = UDim2.new(0, 10, 0, 8)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "Ball Stats"
    titleLabel.TextColor3 = Color3.fromRGB(200, 150, 255)
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local divider = Instance.new("Frame", mainFrame)
    divider.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    divider.BackgroundTransparency = 0.4
    divider.BorderSizePixel = 0
    divider.Size = UDim2.new(1, -20, 0, 1)
    divider.Position = UDim2.new(0, 10, 0, 35)

    local velocityTitle = Instance.new("TextLabel", mainFrame)
    velocityTitle.BackgroundTransparency = 1
    velocityTitle.Size = UDim2.new(0.5, -15, 0, 20)
    velocityTitle.Position = UDim2.new(0, 10, 0, 45)
    velocityTitle.Font = Enum.Font.Gotham
    velocityTitle.Text = "Velocity:"
    velocityTitle.TextColor3 = Color3.fromRGB(180, 160, 220)
    velocityTitle.TextSize = 13
    velocityTitle.TextXAlignment = Enum.TextXAlignment.Left

    local Velocity = Instance.new("TextLabel", mainFrame)
    Velocity.BackgroundTransparency = 1
    Velocity.Size = UDim2.new(0.5, -15, 0, 22)
    Velocity.Position = UDim2.new(0.5, 5, 0, 43)
    Velocity.Font = Enum.Font.GothamBold
    Velocity.Text = "0.00"
    Velocity.TextColor3 = Color3.fromRGB(150, 100, 255)
    Velocity.TextSize = 15
    Velocity.TextXAlignment = Enum.TextXAlignment.Right

    local peakTitle = Instance.new("TextLabel", mainFrame)
    peakTitle.BackgroundTransparency = 1
    peakTitle.Size = UDim2.new(0.5, -15, 0, 20)
    peakTitle.Position = UDim2.new(0, 10, 0, 72)
    peakTitle.Font = Enum.Font.Gotham
    peakTitle.Text = "Peak:"
    peakTitle.TextColor3 = Color3.fromRGB(180, 160, 220)
    peakTitle.TextSize = 13
    peakTitle.TextXAlignment = Enum.TextXAlignment.Left

    local PeakVelocity = Instance.new("TextLabel", mainFrame)
    PeakVelocity.BackgroundTransparency = 1
    PeakVelocity.Size = UDim2.new(0.5, -15, 0, 22)
    PeakVelocity.Position = UDim2.new(0.5, 5, 0, 70)
    PeakVelocity.Font = Enum.Font.GothamBold
    PeakVelocity.Text = "0.00"
    PeakVelocity.TextColor3 = Color3.fromRGB(255, 100, 255)
    PeakVelocity.TextSize = 15
    PeakVelocity.TextXAlignment = Enum.TextXAlignment.Right

    local dragging = false
    local dragInput, dragStart, startPos
    mainFrame.Active = true
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = newPos}):Play()
            TweenService:Create(shadowFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(newPos.X.Scale, newPos.X.Offset + 2, newPos.Y.Scale, newPos.Y.Offset + 2)}):Play()
        end
    end)

    getgenv().VelocityLabel = Velocity
    getgenv().PeakVelocityLabel = PeakVelocity

    local function getRealBalls()
        local balls = {}
        for _, instance in pairs(workspace.Balls:GetChildren()) do
            if instance:GetAttribute("realBall") then
                table.insert(balls, instance)
            end
        end
        return balls
    end

    getgenv().ballStatsUpdateConn = RunService.RenderStepped:Connect(function()
        if not getgenv().ballStatsEnabled then return end
        local speedShown = false
        for _, ball in ipairs(getRealBalls()) do
            local zoomies = ball:FindFirstChild("zoomies")
            if zoomies then
                local speed = zoomies.VectorVelocity.Magnitude
                if getgenv().VelocityLabel then
                    getgenv().VelocityLabel.Text = ("%.2f"):format(speed)
                end
                if speed > getgenv().peakVelocity then
                    getgenv().peakVelocity = speed
                    if getgenv().PeakVelocityLabel then
                        getgenv().PeakVelocityLabel.Text = ("%.2f"):format(getgenv().peakVelocity)
                    end
                end
                speedShown = true
                break
            end
        end
        if not speedShown and getgenv().VelocityLabel then
            getgenv().VelocityLabel.Text = "0.00"
        end
    end)
end

-- ==================== END BALL STATS FUNCTIONALITY ====================


-- ==================== BALL TRAIL FUNCTIONALITY ====================

getgenv().ballTrailEnabled = getgenv().ballTrailEnabled or false
getgenv().ballTrailHue = getgenv().ballTrailHue or 0
getgenv().ballTrailRainbow = getgenv().ballTrailRainbow or false
getgenv().ballTrailParticle = getgenv().ballTrailParticle or false
getgenv().ballTrailGlow = getgenv().ballTrailGlow or false
getgenv().ballTrailColor = getgenv().ballTrailColor or Color3.new(1, 1, 1)

local ballTrailHueVal = 0
local trackedBalls = {}

local function getRealBalls()
    local balls = {}
    for _, instance in pairs(workspace.Balls:GetChildren()) do
        if instance:GetAttribute("realBall") then
            table.insert(balls, instance)
        end
    end
    return balls
end

local function clearBallEffects(ball)
    local trail = ball:FindFirstChild("Trail")
    if trail then trail:Destroy() end
    local emitter = ball:FindFirstChild("ParticleEmitter")
    if emitter then emitter:Destroy() end
    local glow = ball:FindFirstChild("BallGlow")
    if glow then glow:Destroy() end
    local att0 = ball:FindFirstChild("Attachment0")
    if att0 then att0:Destroy() end
    local att1 = ball:FindFirstChild("Attachment1")
    if att1 then att1:Destroy() end
end

local function applyBallEffects(ball)
    if not getgenv().ballTrailEnabled then
        if trackedBalls[ball] then
            clearBallEffects(ball)
            trackedBalls[ball] = nil
        end
        return
    end

    if trackedBalls[ball] then
        local trail = ball:FindFirstChild("Trail")
        if trail then
            if getgenv().ballTrailRainbow then
                local color = Color3.fromHSV(ballTrailHueVal / 360, 1, 1)
                trail.Color = ColorSequence.new(color)
                getgenv().ballTrailColor = color
            else
                trail.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
            end
        end
        local glow = ball:FindFirstChild("BallGlow")
        if glow and getgenv().ballTrailGlow then
            if getgenv().ballTrailRainbow then
                glow.Color = Color3.fromHSV(ballTrailHueVal / 360, 1, 1)
            else
                glow.Color = getgenv().ballTrailColor or Color3.new(1, 1, 1)
            end
        end
        local emitter = ball:FindFirstChild("ParticleEmitter")
        if emitter and getgenv().ballTrailParticle then
            if getgenv().ballTrailRainbow then
                emitter.Color = ColorSequence.new(Color3.fromHSV(ballTrailHueVal / 360, 1, 1))
            else
                emitter.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
            end
        end
        return
    end

    trackedBalls[ball] = true

    local trail = Instance.new("Trail")
    trail.Name = "Trail"
    local att0 = Instance.new("Attachment", ball)
    att0.Name = "Attachment0"
    att0.Position = Vector3.new(0, ball.Size.Y / 2, 0)
    local att1 = Instance.new("Attachment", ball)
    att1.Name = "Attachment1"
    att1.Position = Vector3.new(0, -ball.Size.Y / 2, 0)
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Lifetime = 0.4
    trail.WidthScale = NumberSequence.new(0.5)
    trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
    trail.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
    trail.Parent = ball

    if getgenv().ballTrailParticle then
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "ParticleEmitter"
        emitter.Rate = 100
        emitter.Lifetime = NumberRange.new(0.5, 1)
        emitter.Speed = NumberRange.new(0, 1)
        emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
        emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
        emitter.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
        emitter.Parent = ball
    end

    if getgenv().ballTrailGlow then
        local glow = Instance.new("PointLight")
        glow.Name = "BallGlow"
        glow.Range = 15
        glow.Brightness = 2
        glow.Color = getgenv().ballTrailColor or Color3.new(1, 1, 1)
        glow.Parent = ball
    end
end

local ballTrailConnection = nil

workspace.Balls.ChildRemoved:Connect(function(ball)
    if trackedBalls[ball] then trackedBalls[ball] = nil end
end)

getgenv().updateBallTrail = function()
    if ballTrailConnection then
        ballTrailConnection:Disconnect()
        ballTrailConnection = nil
    end

    if not getgenv().ballTrailEnabled then
        for ball, _ in pairs(trackedBalls) do
            if ball.Parent then clearBallEffects(ball) end
        end
        trackedBalls = {}
        return
    end

    local ballTrailUpdateCounter = 0
    ballTrailConnection = RunService.Heartbeat:Connect(function()
        ballTrailUpdateCounter = ballTrailUpdateCounter + 1
        if ballTrailUpdateCounter % 3 == 0 then
            ballTrailHueVal = (ballTrailHueVal + 1) % 360
            for _, ball in ipairs(getRealBalls()) do
                if ball and ball.Parent then
                    applyBallEffects(ball)
                end
            end
        end
    end)
end

-- ==================== END BALL TRAIL FUNCTIONALITY ====================


-- ==================== PLAYER FUNCTIONALITY ====================

getgenv().playerSpeedEnabled = getgenv().playerSpeedEnabled or false
getgenv().playerSpeed = getgenv().playerSpeed or 36
getgenv().fovEnabled = getgenv().fovEnabled or false
getgenv().fov = getgenv().fov or 70
getgenv().playerCosmeticsEnabled = getgenv().playerCosmeticsEnabled or false
getgenv().hitSoundsEnabled = getgenv().hitSoundsEnabled or false
getgenv().hitSoundVolume = getgenv().hitSoundVolume or 5
getgenv().hitSoundType = getgenv().hitSoundType or "Medal"

do
    local speedConnection = nil
    getgenv().updatePlayerSpeed = function()
        if speedConnection then
            speedConnection:Disconnect()
            speedConnection = nil
        end
        local speedUpdateCounter = 0
        speedConnection = RunService.Heartbeat:Connect(function()
            speedUpdateCounter = speedUpdateCounter + 1
            if speedUpdateCounter % 5 ~= 0 then return end
            if Player.Character and Player.Character:FindFirstChild("Humanoid") then
                if getgenv().playerSpeedEnabled then
                    Player.Character.Humanoid.WalkSpeed = getgenv().playerSpeed
                else
                    Player.Character.Humanoid.WalkSpeed = 36
                end
            end
        end)
        if Player.Character and Player.Character:FindFirstChild("Humanoid") then
            Player.Character.Humanoid.WalkSpeed = getgenv().playerSpeedEnabled and getgenv().playerSpeed or 36
        end
    end

    Player.CharacterAdded:Connect(function(character)
        task.wait(0.1)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.WalkSpeed = getgenv().playerSpeedEnabled and getgenv().playerSpeed or 36
        end
    end)
end

do
    local fovConnection = nil
    getgenv().updateFOV = function()
        if fovConnection then
            fovConnection:Disconnect()
            fovConnection = nil
        end
        if not getgenv().fovEnabled then
            workspace.CurrentCamera.FieldOfView = 70
            return
        end
        workspace.CurrentCamera.FieldOfView = getgenv().fov
        fovConnection = RunService.Heartbeat:Connect(function()
            if getgenv().fovEnabled then
                workspace.CurrentCamera.FieldOfView = getgenv().fov
            end
        end)
    end
end

do
    local cosmeticsActive = false
    local headLoop = nil
    getgenv().PlayerCosmeticsCleanup = getgenv().PlayerCosmeticsCleanup or {}
    local cosmeticsCharacterAddedConnection = nil

    local function applyKorblox(character)
        local rightLeg = character:FindFirstChild("RightLeg") or character:FindFirstChild("Right Leg")
        if not rightLeg then return end
        for _, child in pairs(rightLeg:GetChildren()) do
            if child:IsA("SpecialMesh") then child:Destroy() end
        end
        local specialMesh = Instance.new("SpecialMesh")
        specialMesh.MeshId = "rbxassetid://101851696"
        specialMesh.TextureId = "rbxassetid://115727863"
        specialMesh.Scale = Vector3.new(1, 1, 1)
        specialMesh.Parent = rightLeg
    end

    local function saveRightLegProperties(char)
        if char then
            local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("Right Leg")
            if rightLeg then
                local originalMesh = rightLeg:FindFirstChildOfClass("SpecialMesh")
                if originalMesh then
                    getgenv().PlayerCosmeticsCleanup.originalMeshId = originalMesh.MeshId
                    getgenv().PlayerCosmeticsCleanup.originalTextureId = originalMesh.TextureId
                    getgenv().PlayerCosmeticsCleanup.originalScale = originalMesh.Scale
                else
                    getgenv().PlayerCosmeticsCleanup.hadNoMesh = true
                end
                getgenv().PlayerCosmeticsCleanup.rightLegChildren = {}
                for _, child in pairs(rightLeg:GetChildren()) do
                    if child:IsA("SpecialMesh") then
                        table.insert(getgenv().PlayerCosmeticsCleanup.rightLegChildren, {
                            ClassName = child.ClassName,
                            Properties = {
                                MeshId = child.MeshId,
                                TextureId = child.TextureId,
                                Scale = child.Scale,
                            },
                        })
                    end
                end
            end
        end
    end

    local function restoreRightLeg(char)
        if char then
            local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("Right Leg")
            if rightLeg and getgenv().PlayerCosmeticsCleanup.rightLegChildren then
                for _, child in pairs(rightLeg:GetChildren()) do
                    if child:IsA("SpecialMesh") then child:Destroy() end
                end
                if getgenv().PlayerCosmeticsCleanup.hadNoMesh then return end
                for _, childData in ipairs(getgenv().PlayerCosmeticsCleanup.rightLegChildren) do
                    if childData.ClassName == "SpecialMesh" then
                        local newMesh = Instance.new("SpecialMesh")
                        newMesh.MeshId = childData.Properties.MeshId
                        newMesh.TextureId = childData.Properties.TextureId
                        newMesh.Scale = childData.Properties.Scale
                        newMesh.Parent = rightLeg
                    end
                end
            end
        end
    end

    getgenv().updatePlayerCosmetics = function()
        if not getgenv().playerCosmeticsEnabled then
            cosmeticsActive = false
            if cosmeticsCharacterAddedConnection then
                cosmeticsCharacterAddedConnection:Disconnect()
                cosmeticsCharacterAddedConnection = nil
            end
            if headLoop then
                task.cancel(headLoop)
                headLoop = nil
            end
            local char = Player.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head and getgenv().PlayerCosmeticsCleanup.headTransparency ~= nil then
                    head.Transparency = getgenv().PlayerCosmeticsCleanup.headTransparency
                    if getgenv().PlayerCosmeticsCleanup.faceDecalId then
                        local newDecal = head:FindFirstChildOfClass("Decal") or Instance.new("Decal", head)
                        newDecal.Name = getgenv().PlayerCosmeticsCleanup.faceDecalName or "face"
                        newDecal.Texture = getgenv().PlayerCosmeticsCleanup.faceDecalId
                        newDecal.Face = Enum.NormalId.Front
                    end
                end
                restoreRightLeg(char)
            end
            getgenv().PlayerCosmeticsCleanup = {}
            return
        end

        cosmeticsActive = true
        getgenv().Config = getgenv().Config or {}
        getgenv().Config.Headless = true
        if Player.Character then
            local head = Player.Character:FindFirstChild("Head")
            if head and getgenv().Config.Headless then
                getgenv().PlayerCosmeticsCleanup.headTransparency = head.Transparency
                local decal = head:FindFirstChildOfClass("Decal")
                if decal then
                    getgenv().PlayerCosmeticsCleanup.faceDecalId = decal.Texture
                    getgenv().PlayerCosmeticsCleanup.faceDecalName = decal.Name
                end
            end
            saveRightLegProperties(Player.Character)
            applyKorblox(Player.Character)
        end

        cosmeticsCharacterAddedConnection = Player.CharacterAdded:Connect(function(char)
            local head = char:WaitForChild("Head", 5)
            if head and getgenv().Config.Headless then
                getgenv().PlayerCosmeticsCleanup.headTransparency = head.Transparency
                local decal = head:FindFirstChildOfClass("Decal")
                if decal then
                    getgenv().PlayerCosmeticsCleanup.faceDecalId = decal.Texture
                    getgenv().PlayerCosmeticsCleanup.faceDecalName = decal.Name
                end
            end
            local rightLeg = char:WaitForChild("RightLeg", 0.1) or char:WaitForChild("Right Leg", 0.1)
            if rightLeg then
                applyKorblox(char)
            end
        end)

        if getgenv().Config.Headless then
            headLoop = task.spawn(function()
                while cosmeticsActive do
                    local char = Player.Character
                    if char then
                        local head = char:FindFirstChild("Head")
                        if head then
                            head.Transparency = 1
                            local decal = head:FindFirstChildOfClass("Decal")
                            if decal then decal:Destroy() end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end
end

do
    local hitSoundFolder = nil
    local hitSound = nil
    local hitSoundIds = {
        Medal = "rbxassetid://6607336718",
        Fatality = "rbxassetid://6607113255",
        Skeet = "rbxassetid://6607204501",
        Switches = "rbxassetid://6607173363",
        ["Rust Headshot"] = "rbxassetid://138750331387064",
        ["Neverlose Sound"] = "rbxassetid://110168723447153",
        Bubble = "rbxassetid://6534947588",
        Laser = "rbxassetid://7837461331",
        Steve = "rbxassetid://4965083997",
        ["Call of Duty"] = "rbxassetid://5952120301",
        Bat = "rbxassetid://3333907347",
        ["TF2 Critical"] = "rbxassetid://296102734",
        Saber = "rbxassetid://8415678813",
        Bameware = "rbxassetid://3124331820",
    }

    local function initializeHitSounds()
        if not hitSoundFolder then
            hitSoundFolder = Instance.new("Folder")
            hitSoundFolder.Name = "Useful Utility"
            hitSoundFolder.Parent = workspace
        end
        if not hitSound then
            hitSound = Instance.new("Sound", hitSoundFolder)
            hitSound.Volume = getgenv().hitSoundVolume or 5
            hitSound.SoundId = hitSoundIds[getgenv().hitSoundType] or hitSoundIds["Medal"]
        end
    end

    getgenv().updateHitSounds = function()
        initializeHitSounds()
        if hitSound then
            hitSound.Volume = getgenv().hitSoundVolume or 5
            if hitSoundIds[getgenv().hitSoundType] then
                hitSound.SoundId = hitSoundIds[getgenv().hitSoundType]
            end
        end
    end

    initializeHitSounds()

    game:GetService("ReplicatedStorage").Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if getgenv().hitSoundsEnabled then
            initializeHitSounds()
            if hitSound then hitSound:Play() end
        end
    end)
end

-- ==================== END PLAYER FUNCTIONALITY ====================


-- ==================== MANUEL SPAM FUNCTIONALITY ====================

getgenv().autoSpam = getgenv().autoSpam or false
getgenv().autoSpamKey = getgenv().autoSpamKey or Enum.KeyCode.E
getgenv().autoSpamNotify = getgenv().autoSpamNotify or false

do
    local isSpamming = false
    local spamThread = nil
    local autoSpamConnection = nil

    local function startSpamming()
        if isSpamming then return end
        isSpamming = true
        if getgenv().autoSpamNotify then
            pcall(function()
                if Window then
                    WindUI:Notify({
                        Title = "Manuel Spam",
                        Content = "Enabled",
                        Duration = 2
                    })
                end
            end)
        end
        spamThread = task.spawn(function()
            while isSpamming and getgenv().autoSpam do
                pcall(function()
                    Auto_Parry.Parry()
                end)
                task.wait(0.05)
            end
            isSpamming = false
        end)
    end

    local function stopSpamming()
        if not isSpamming then return end
        isSpamming = false
        if spamThread then task.cancel(spamThread); spamThread = nil end
        if getgenv().autoSpamNotify then
            pcall(function()
                if Window then
                    WindUI:Notify({
                        Title = "Manuel Spam",
                        Content = "Disabled",
                        Duration = 2
                    })
                end
            end)
        end
    end

    getgenv().updateAutoSpam = function()
        if autoSpamConnection then
            autoSpamConnection:Disconnect()
            autoSpamConnection = nil
        end
        if not getgenv().autoSpam then
            stopSpamming()
            return
        end
        autoSpamConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == (getgenv().autoSpamKey or Enum.KeyCode.E) then
                if getgenv().autoSpam then
                    if isSpamming then stopSpamming() else startSpamming() end
                end
            end
        end)
    end
end

-- ==================== END MANUEL SPAM FUNCTIONALITY ====================


-- ==================== LOBBY AUTO PARRY FUNCTIONALITY ====================

getgenv().lobbyAutoParry = getgenv().lobbyAutoParry or false
getgenv().lobbyParryAccuracy = getgenv().lobbyParryAccuracy or 100
getgenv().lobbyRandomAccuracy = getgenv().lobbyRandomAccuracy or false
getgenv().lobbyParryKeypress = getgenv().lobbyParryKeypress or false

do
    local lobbyAutoParryConnection = nil
    local trainingParried = false
    local lastLobbyBallTarget = nil
    local LobbyAP_SDM = 1.1

    local function getLobbyBall()
        local trainingBalls = workspace:FindFirstChild("TrainingBalls")
        if not trainingBalls then return nil end
        for _, instance in pairs(trainingBalls:GetChildren()) do
            if instance:GetAttribute("realBall") then return instance end
        end
        return nil
    end

    local function computeSDM(value)
        value = math.clamp(value or 100, 1, 100)
        return 0.7 + (value - 1) * (0.35 / 99)
    end

    local function computePA(speed, ping, multiplier)
        local cappedSpeedDiff = math.min(math.max(speed - 9.5, 0), 650)
        local speedDivisorBase = 2.4 + cappedSpeedDiff * 0.002
        local speedDivisor = speedDivisorBase * (multiplier or 1)
        if speedDivisor <= 0 then return ping end
        return ping + math.max(speed / speedDivisor, 9.5)
    end

    getgenv().updateLobbyAutoParry = function()
        if lobbyAutoParryConnection then
            lobbyAutoParryConnection:Disconnect()
            lobbyAutoParryConnection = nil
        end
        if not getgenv().lobbyAutoParry then
            trainingParried = false
            lastLobbyBallTarget = nil
            return
        end
        LobbyAP_SDM = computeSDM(getgenv().lobbyParryAccuracy or 100)
        task.spawn(function()
            local counter = 0
            lobbyAutoParryConnection = RunService.Heartbeat:Connect(function()
                counter = counter + 1
                if counter % 2 ~= 0 then return end
                if not getgenv().lobbyAutoParry then return end
                local ball = getLobbyBall()
                if not ball then
                    trainingParried = false
                    lastLobbyBallTarget = nil
                    return
                end
                local zoomies = ball:FindFirstChild("zoomies")
                if not zoomies then return end
                local ballTarget = ball:GetAttribute("target")
                if ballTarget ~= lastLobbyBallTarget then
                    trainingParried = false
                    lastLobbyBallTarget = ballTarget
                end
                if trainingParried then return end
                local velocity = zoomies.VectorVelocity
                local distance = Player:DistanceFromCharacter(ball.Position)
                local speed = velocity.Magnitude
                local ok, pingVal = pcall(function()
                    return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 10
                end)
                local ping = ok and pingVal or 50
                local effectiveMultiplier = LobbyAP_SDM
                if getgenv().lobbyRandomAccuracy then
                    effectiveMultiplier = computeSDM(math.random(1, 100))
                end
                local parryAccuracy = computePA(speed, ping, effectiveMultiplier)
                if ballTarget == tostring(Player) and distance <= parryAccuracy then
                    pcall(function() Auto_Parry.Parry() end)
                    trainingParried = true
                    task.spawn(function()
                        local lastParry = tick()
                        repeat RunService.PreSimulation:Wait()
                        until (tick() - lastParry) >= 1 or not trainingParried
                        trainingParried = false
                    end)
                end
            end)
        end)
    end
end

-- ==================== END LOBBY AUTO PARRY FUNCTIONALITY ====================



-- ==================== BUG REPORT FUNCTIONALITY ====================
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1508521496417533985/IYk3KkZtRB7RI4W8r5tn2Y1S9zu2yzz3-wAWPgOnjqsHC1kCeqwv_hTyTlHIflsvoR5_"

local function sendBugReportToDiscord(bugType, bugMessage)
    if DISCORD_WEBHOOK_URL == "" then return false end

    local playerName = Player.Name
    local playerUserId = Player.UserId
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local limitedBugMessage = bugMessage
    if #bugMessage > 1000 then limitedBugMessage = string.sub(bugMessage, 1, 1000) .. "..." end

    local embed = {
        title = "🐛 Bug Report (Blade Ball)",
        color = 15158332,
        fields = {
            { name = "Bug Type", value = bugType, inline = true },
            { name = "Player", value = playerName .. " (" .. playerUserId .. ")", inline = true },
            { name = "Timestamp", value = timestamp, inline = true },
            { name = "Bug Description", value = limitedBugMessage or "No description provided", inline = false }
        },
        footer = { text = "Levi Hub X - Bug Report System" }
    }

    local payload = { embeds = {embed} }
    local HttpService = game:GetService("HttpService")

    local success, errorMessage = pcall(function()
        local jsonPayload = HttpService:JSONEncode(payload)
        local requestFunc = request or http_request or (syn and syn.request) or (http and http.request)
        if not requestFunc then return false end

        local response = requestFunc({
            Url = DISCORD_WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonPayload
        })

        if response and (response.StatusCode == 200 or response.StatusCode == 204) then return true else return false end
    end)
    return success
end
-- ==================== END BUG REPORT FUNCTIONALITY ====================

-- ==================== CONFIG SYSTEM FUNCTIONALITY ====================
local _isfolder = isfolder or function() return false end
local _makefolder = makefolder or function() end
local _writefile = writefile or function() end
local _readfile = readfile or function() return "" end
local _isfile = isfile or function() return false end
local _listfiles = listfiles or function() return {} end

local CONFIG_FOLDER = "LeviHubX/Configs/"
if not _isfolder("LeviHubX") then pcall(_makefolder, "LeviHubX") end
if not _isfolder(CONFIG_FOLDER) then pcall(_makefolder, CONFIG_FOLDER) end

local HttpService = game:GetService("HttpService")

getgenv().saveConfig = function(name)
    name = name or "Default"
    local path = CONFIG_FOLDER .. name .. ".json"
    local configData = {
        espEnabled = getgenv().espEnabled,
        espTracers = getgenv().espTracers,
        espNames = getgenv().espNames,
        espBoxes = getgenv().espBoxes,
        -- autoparry ve auto spam ayarlari kaydedilmeyecek (varsayilan olarak kapali gelsinler)
        parryAccuracy = getgenv().parryAccuracy,
        parryType = getgenv().parryType,
        randomAccuracy = getgenv().randomAccuracy,
        randomAccuracyMin = getgenv().randomAccuracyMin,
        randomAccuracyMax = getgenv().randomAccuracyMax,
        spamParryType = getgenv().spamParryType,
        spamParryThreshold = getgenv().spamParryThreshold,
        spamParryKeypress = getgenv().spamParryKeypress,
        spamParryAnimationFix = getgenv().spamParryAnimationFix,
        autoSpam = getgenv().autoSpam,
        autoSpamKey = getgenv().autoSpamKey,
        playerSpeedEnabled = getgenv().playerSpeedEnabled,
        playerSpeed = getgenv().playerSpeed,
        fovEnabled = getgenv().fovEnabled,
        fov = getgenv().fov,
        ballStatsEnabled = getgenv().ballStatsEnabled,
        ballTrailEnabled = getgenv().ballTrailEnabled,
        ballTrailHue = getgenv().ballTrailHue,
        ballTrailRainbow = getgenv().ballTrailRainbow,
        ballTrailParticle = getgenv().ballTrailParticle,
        ballTrailGlow = getgenv().ballTrailGlow,
        customSky = getgenv().customSky,
        selectedSky = getgenv().selectedSky,
        autoPlay = getgenv().autoPlay,
        autoVote = getgenv().autoVote,
        autoAbility = getgenv().autoAbility,
        lobbyAutoParry = getgenv().lobbyAutoParry,
        lobbyParryAccuracy = getgenv().lobbyParryAccuracy,
        lobbyRandomAccuracy = getgenv().lobbyRandomAccuracy,
        lobbyParryKeypress = getgenv().lobbyParryKeypress,
        InfinityDetection = getgenv().InfinityDetection,
        DeathSlashDetection = getgenv().DeathSlashDetection,
        TimeHoleDetection = getgenv().TimeHoleDetection,
        DribbleDetection = getgenv().DribbleDetection,
        SlashOfFuryDetection = getgenv().SlashOfFuryDetection,
        PhantomV2Detection = getgenv().PhantomV2Detection,
        hitSoundsEnabled = getgenv().hitSoundsEnabled,
        hitSoundVolume = getgenv().hitSoundVolume,
        hitSoundType = getgenv().hitSoundType,
        noRender = getgenv().noRender,
        
        swordModel = getgenv().swordModel,
    }
    local ok, err = pcall(function()
        _writefile(path, HttpService:JSONEncode(configData))
    end)
    return ok, err
end

getgenv().loadConfig = function(name)
    name = name or "Default"
    local path = CONFIG_FOLDER .. name .. ".json"

    if not _isfile(path) then return false, "File not found" end
    local readOk, rawData = pcall(_readfile, path)
    if not readOk or not rawData or rawData == "" then return false, "Could not read file" end

    local decodeOk, config = pcall(HttpService.JSONDecode, HttpService, rawData)
    if not decodeOk or type(config) ~= "table" then return false, "JSON decode failed" end

    for k, v in pairs(config) do 
        if k ~= "autoparry" and k ~= "autoSpamParry" then
            getgenv()[k] = v 
        end
    end

    pcall(function() if getgenv().updateESP then getgenv().updateESP() end end)
    pcall(function() if getgenv().updateAutoParry then getgenv().updateAutoParry() end end)
    pcall(function() if getgenv().updateAutoSpamParry then getgenv().updateAutoSpamParry() end end)
    pcall(function() if getgenv().updateAutoSpam then getgenv().updateAutoSpam() end end)
    pcall(function() if getgenv().updatePlayerSpeed then getgenv().updatePlayerSpeed() end end)
    pcall(function() if getgenv().updateFOV then getgenv().updateFOV() end end)
    pcall(function() if getgenv().updateSky then getgenv().updateSky() end end)
    pcall(function() if getgenv().updateAutoAbility then getgenv().updateAutoAbility() end end)
    pcall(function() if getgenv().updateHitSounds then getgenv().updateHitSounds() end end)
    pcall(function() if getgenv().updateNoRender then getgenv().updateNoRender() end end)
    pcall(function() if getgenv().updateLobbyAutoParry then getgenv().updateLobbyAutoParry() end end)
    pcall(function() if getgenv().updateBallTrail then getgenv().updateBallTrail() end end)
    pcall(function() if getgenv().updateBallStats then getgenv().updateBallStats() end end)
    pcall(function() if getgenv().updatePlayerCosmetics then getgenv().updatePlayerCosmetics() end end)

    return true, "Success"
end
-- ==================== END CONFIG SYSTEM ====================

pcall(function() getgenv().loadConfig("AutoSave") end)

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()


local Window = WindUI:CreateWindow({
    Title = "Levi Hub X v1.0.1",
    Icon = "shield",
    Author = "Levi",
    Folder = "LeviHubX",
    Size = UDim2.fromOffset(680, 460),
    Transparent = false,
    Theme = "Dark",
    SideBarWidth = 200,
    HasOutline = true,
    HideSearchBar = false,
    ToggleKey = Enum.KeyCode.K
})

local Window = getgenv().Window or Window



-- Sections and Tabs


Window:Section({ Title = "Main" })


local isXeno = false
pcall(function()
    local exec = (identifyexecutor or function() return "" end)()
    if type(exec) == "string" and exec:find("Xeno") then
        isXeno = true
    end
end)


local MainTab = Window:Tab({
    Title = "Main",
    Icon = "layout-dashboard",
})

-- ESP Section
MainTab:Section({ Title = "ESP" })

MainTab:Toggle({
    Title = "ESP Enabled",
    Desc = "Show players on screen",
    Value = getgenv().espEnabled or false,
      Callback = function(state)
          getgenv().espEnabled = state
        getgenv().updateESP()
    end
})

MainTab:Toggle({
    Title = "ESP Tracers",
    Desc = "Show lines from screen center to players",
    Value = getgenv().espTracers or false,
      Callback = function(state)
          getgenv().espTracers = state
        getgenv().updateESP()
    end
})

MainTab:Toggle({
    Title = "ESP Names",
    Desc = "Show player names above them",
    Value = getgenv().espNames or false,
      Callback = function(state)
          getgenv().espNames = state
        getgenv().updateESP()
    end
})

MainTab:Toggle({
    Title = "ESP Boxes",
    Desc = "Show boxes around players",
    Value = getgenv().espBoxes or false,
      Callback = function(state)
          getgenv().espBoxes = state
        getgenv().updateESP()
    end
})

-- Auto Section
MainTab:Section({ Title = "Auto" })

MainTab:Toggle({
    Title = "Auto Play",
    Desc = "Automatically plays the game for you",
    Value = getgenv().autoPlay or false,
      Callback = function(state)
          getgenv().autoPlay = state
        if state then
            AutoPlayModule.runThread()
        else
            AutoPlayModule.finishThread()
        end
    end
})

MainTab:Toggle({
    Title = "Auto Vote",
    Desc = "Automatically votes in lobby",
    Value = getgenv().autoVote or false,
      Callback = function(state)
          getgenv().autoVote = state
    end
})

MainTab:Toggle({
    Title = "Auto Ability",
    Desc = "Automatically uses sword ability",
    Value = getgenv().autoAbility or false,
      Callback = function(state)
          getgenv().autoAbility = state
        getgenv().updateAutoAbility()
    end
})

local rage = Window:Tab({
    Title = "Blatant",
    Icon = "swords",
})

local DetectionTab = Window:Tab({
    Title = "Detection",
    Icon = "radar",
})

-- Detection toggles
local detectionList = {
    { "Infinity Detection",     "InfinityDetection" },
    { "Death Slash Detection",  "DeathSlashDetection" },
    { "Time Hole Detection",    "TimeHoleDetection" },
    { "Dribble Detection",      "DribbleDetection" },
    { "Slash Of Fury Detection","SlashOfFuryDetection" },
    { "Phantom V2 Detection",   "PhantomV2Detection" },
}

for _, det in ipairs(detectionList) do
    DetectionTab:Toggle({
        Title = det[1],
        Desc = "Notifies/triggers when " .. det[1] .. " is active",
        Value = false,
        Callback = function(state)
            getgenv()[det[2]] = state
        end
    })
end

if not isXeno then
local SkinTab = Window:Tab({
    Title = "Skin",
    Icon = "shirt",
})

-- Skin Changer UI
local HttpService = game:GetService("HttpService")
local FAV_FILE = "LeviHub/Configs/favorite_swords.json"
local favoriteSwords = {}

local function saveFavs()
    pcall(function()
        if not isfolder("LeviHub/Configs") then makefolder("LeviHub/Configs") end
        writefile(FAV_FILE, HttpService:JSONEncode(favoriteSwords))
    end)
end

local function loadFavs()
    if isfile and isfile(FAV_FILE) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(FAV_FILE)) end)
        if success and type(data) == "table" then
            favoriteSwords = data
        end
    end
end
loadFavs()

local favOptions = {}
local function refreshFavList()
    table.clear(favOptions)
    for _, s in ipairs(favoriteSwords) do table.insert(favOptions, s) end
    if #favOptions == 0 then table.insert(favOptions, "No Favorites") end
    return favOptions
end
refreshFavList()

local skinChangerToggle = SkinTab:Toggle({
    Title = "Skin Changer",
      Desc = "Changes your sword skin",
      Value = false,
    Callback = function(state)
        getgenv().skinChanger = state
        if state and getgenv().swordModel ~= "" then
            getgenv().updateSword()
        end
    end
})

getgenv().setSkinChangerToggleUI = function(value)
    if skinChangerToggle and skinChangerToggle.Set then
        skinChangerToggle:Set(value)
    end
end

local skinSwordInput = SkinTab:Input({
    Title = "Sword Name",
    Desc = "Enter the sword name",
    Placeholder = "Sword Name...",
    Callback = function(text)
        getgenv().swordModel = text
        getgenv().swordAnimations = text
        getgenv().swordFX = text
        if getgenv().skinChanger and text ~= "" then
            getgenv().updateSword()
        end
    end
})

local favDropdown
favDropdown = SkinTab:Dropdown({
    Title = "Favorite List",
    Desc = "Favorite Swords",
    Values = favOptions,
    Value = "No Favorites",
    Callback = function(value)
        if value ~= "No Favorites" then
            getgenv().swordModel = value
            getgenv().swordAnimations = value
            getgenv().swordFX = value
            if skinSwordInput and skinSwordInput.Set then skinSwordInput:Set(value) end
            if getgenv().skinChanger then getgenv().updateSword() end
        end
    end
})

SkinTab:Button({
    Title = "Add Current to Favorites",
    Desc = "Adds current sword to favorites",
    Callback = function()
        local current = getgenv().swordModel
        if current and current ~= "" then
            local found = false
            for _, s in ipairs(favoriteSwords) do if s == current then found = true break end end
            if not found then
                table.insert(favoriteSwords, current)
                saveFavs()
                refreshFavList()
                if favDropdown and favDropdown.SetOptions then
                    pcall(function() favDropdown:SetOptions(favOptions) end)
                end
            end
        end
    end
})

SkinTab:Button({
    Title = "Remove Current from Favorites",
    Desc = "Removes current sword from favorites",
    Callback = function()
        local current = getgenv().swordModel
        for i, s in ipairs(favoriteSwords) do
            if s == current then
                table.remove(favoriteSwords, i)
                saveFavs()
                refreshFavList()
                if favDropdown and favDropdown.SetOptions then
                    pcall(function() favDropdown:SetOptions(favOptions) end)
                end
                break
            end
        end
    end
})
end

local PlayerTab = Window:Tab({
    Title = "Player",
    Icon = "user",
})

PlayerTab:Section({ Title = "Speed" })

PlayerTab:Toggle({
    Title = "Speed",
    Desc = "Changes the player speed",
    Value = getgenv().playerSpeedEnabled or false,
    Callback = function(state)
        getgenv().playerSpeedEnabled = state
        getgenv().updatePlayerSpeed()
    end
})

PlayerTab:Slider({
    Flag = "PlayerSpeedValue",
    Title = "Speed Value",
    Desc = "Speed value",
    Step = 1,
    Value = { Min = 16, Max = 200, Default = getgenv().playerSpeed or 36 },
    Callback = function(value)
        getgenv().playerSpeed = value
        if getgenv().playerSpeedEnabled then getgenv().updatePlayerSpeed() end
    end
})

PlayerTab:Section({ Title = "Field of View" })

PlayerTab:Toggle({
    Title = "Field of View",
    Desc = "Changes the Field of View (FOV)",
    Value = getgenv().fovEnabled or false,
    Callback = function(state)
        getgenv().fovEnabled = state
        getgenv().updateFOV()
    end
})

PlayerTab:Slider({
    Flag = "FOVValue",
    Title = "FOV Value",
    Desc = "FOV value",
    Step = 1,
    Value = { Min = 50, Max = 120, Default = getgenv().fov or 70 },
    Callback = function(value)
        getgenv().fov = value
        if getgenv().fovEnabled then getgenv().updateFOV() end
    end
})

PlayerTab:Section({ Title = "Cosmetics & Sounds" })

PlayerTab:Toggle({
    Title = "Player Cosmetics",
    Desc = "Applies Headless and Korblox",
    Value = getgenv().playerCosmeticsEnabled or false,
    Callback = function(state)
        getgenv().playerCosmeticsEnabled = state
        getgenv().updatePlayerCosmetics()
    end
})

PlayerTab:Toggle({
    Title = "Hit Sounds",
    Desc = "Plays a sound on successful parry",
    Value = getgenv().hitSoundsEnabled or false,
    Callback = function(state)
        getgenv().hitSoundsEnabled = state
    end
})

PlayerTab:Slider({
    Flag = "HitSoundVolume",
    Title = "Hit Sound Volume",
    Desc = "Hit sound volume",
    Step = 1,
    Value = { Min = 1, Max = 10, Default = getgenv().hitSoundVolume or 5 },
    Callback = function(value)
        getgenv().hitSoundVolume = value
        getgenv().updateHitSounds()
    end
})

PlayerTab:Dropdown({
    Title = "Hit Sound Type",
    Desc = "Hit sound type",
    Values = { "Medal", "Fatality", "Skeet", "Switches", "Rust Headshot", "Neverlose Sound", "Bubble", "Laser", "Steve", "Call of Duty", "Bat", "TF2 Critical", "Saber", "Bameware" },
    Value = getgenv().hitSoundType or "Medal",
    Callback = function(value)
        getgenv().hitSoundType = value
        getgenv().updateHitSounds()
    end
})

local Visual = Window:Tab({
    Title = "Others",
    Icon = "image",
})


Window:Section({ Title = "Settings" })

local SettingsTab = Window:Tab({
    Title = "Settings",
    Icon = "settings",
})

local BugReportTab = Window:Tab({
    Title = "Bugs Reports",
    Icon = "bug",
})

-- ==================== BUGS REPORT UI ====================
local bugType = "Other"
local bugMessage = ""

BugReportTab:Section({ Title = "Report a Bug" })

BugReportTab:Dropdown({
    Title = "Bug Type",
    Desc = "Select the type of bug",
    Values = { "Crash", "Feature Not Working", "UI Issue", "Performance Issue", "Other" },
    Value = "Other",
    Callback = function(value) bugType = value end
})

BugReportTab:Input({
    Title = "Bug Description",
    Desc = "Describe the bug...",
    Placeholder = "Type here...",
    Callback = function(value) bugMessage = value end
})

BugReportTab:Button({
    Title = "Send Bug Report",
    Desc = "Sends the report",
    Callback = function()
        if bugMessage == "" then
            WindUI:Notify({ Title = "Error", Content = "Please enter a description.", Duration = 3 })
            return
        end
        local ok = sendBugReportToDiscord(bugType, bugMessage)
        if ok then
            WindUI:Notify({ Title = "Report Sent!", Content = "Thanks for your report.", Duration = 3 })
        else
            WindUI:Notify({ Title = "Failed", Content = "Could not send report. Check executor.", Duration = 3 })
        end
    end
})

BugReportTab:Section({ Title = "Discord Server" })
BugReportTab:Button({
    Title = "Join Discord (Copy Link)",
    Desc = "Copies invite to clipboard",
    Callback = function()
        setclipboard("https://discord.gg/96KmTbDA8j")
        WindUI:Notify({ Title = "Copied!", Content = "Link copied to clipboard.", Duration = 3 })
    end
})

-- ==================== SETTINGS (CONFIG) UI ====================
SettingsTab:Section({ Title = "Script" })
SettingsTab:Button({
    Title = "Unload Script",
    Desc = "Closes UI",
    Callback = function() 
        Window:Destroy() 
    end
})


rage:Toggle({
    Title = "Auto Parry",
      Desc = "Automatic Parry Ball",
      Value = getgenv().autoparry or false,
      Callback = function(state)
          getgenv().autoparry = state
        if state then
            Connections_Manager['Auto Parry'] = RunService.PreSimulation:Connect(function()

                local One_Ball = Auto_Parry.Get_Ball()
                local Balls = Auto_Parry.Get_Balls()

                for _, Ball in pairs(Balls) do

                if not Ball then repeat task.wait() Balls = Auto_Parry.Get_Balls() until Balls
                    return
                end

                local Zoomies = Ball:FindFirstChild('zoomies')

                if not Zoomies then
                    return
                end

                Ball:GetAttributeChangedSignal('target'):Once(function()
                    Parried = false
                end)

                if Parried then
                    return
                end

                local Ball_Target = Ball:GetAttribute('target')
                local One_Target = One_Ball:GetAttribute('target')

                local Velocity = Zoomies.VectorVelocity

                local Distance = (Player.Character.PrimaryPart.Position - Ball.Position).Magnitude
                local Speed = Velocity.Magnitude

                local Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue() / 10

                local Parry_Accuracy = (Speed / 3.25) + Ping
                local Curved = Auto_Parry.Is_Curved()
                
                if Auto_Parry.Parry_Type == "Camera" then
                    Curved = false
                end

                if Ball_Target == tostring(Player) and Aerodynamic then
                    local Elasped_Tornado = tick() - Aerodynamic_Time

                    if Elasped_Tornado > 0.6 then
                        Aerodynamic_Time = tick()
                        Aerodynamic = false
                    end

                    return
                end

                if One_Target == tostring(Player) and Curved then
                    return
                end

                if Ball_Target == tostring(Player) and Distance <= Parry_Accuracy then
                    Auto_Parry.Parry(Selected_Parry_Type)
                    Parried = true
                end

                local Last_Parrys = tick()

                repeat RunService.PreSimulation:Wait() until (tick() - Last_Parrys) >= 1 or not Parried
                    Parried = false
                end
            end)
        else
            if Connections_Manager['Auto Parry'] then
                Connections_Manager['Auto Parry']:Disconnect()
                Connections_Manager['Auto Parry'] = nil
            end
        end
    end
})

rage:Dropdown({
    Title = "Auto Curve Direction",
      Values = { "Camera", "Backwards", "Random" },
      Value = getgenv().parryType or "Camera",
      Callback = function(Selected)
          getgenv().parryType = Selected
          Auto_Parry.Parry_Type = Selected
      end
})

rage:Slider({
    Title = "Parry Accuracy",
      Value = {
          Min = 1,
          Max = 100,
          Default = getgenv().parryAccuracy or 100
      },
    Callback = function(v)
          getgenv().parryAccuracy = v
        local Adjusted_Value = v / 5.5
        getgenv().Parry_Accuracy = Adjusted_Value
    end
})

rage:Toggle({
    Title = "Auto Spam Parry",
      Desc = "Automatically spam parries ball",
      Value = getgenv().autoSpamParry or false,
      Callback = function(state)
          getgenv().autoSpamParry = state
        if state then
            Connections_Manager['Auto Spam'] = RunService.PreSimulation:Connect(function()
                local Ball = Auto_Parry.Get_Ball()

                if not Ball then
                    return
                end

                local Zoomies = Ball:FindFirstChild('zoomies')

                if not Zoomies then
                    return
                end

                Auto_Parry.Closest_Player()

                local Ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()
                local Ping_Threshold = math.clamp(Ping / 10, 10, 16)

                local Ball_Properties = Auto_Parry:Get_Ball_Properties()
                local Entity_Properties = Auto_Parry:Get_Entity_Properties()

                local Spam_Accuracy = Auto_Parry.Spam_Service({
                    Ball_Properties = Ball_Properties,
                    Entity_Properties = Entity_Properties,
                    Ping = Ping_Threshold
                })

                local Distance = Player:DistanceFromCharacter(Ball.Position)

                local Target_Position = Closest_Entity.PrimaryPart.Position
                local Target_Distance = Player:DistanceFromCharacter(Target_Position)

                local Direction = (Player.Character.PrimaryPart.Position - Ball.Position).Unit
                local Ball_Direction = Zoomies.VectorVelocity.Unit

                local Dot = Direction:Dot(Ball_Direction)
                local Ball_Target = Alive:FindFirstChild(Ball:GetAttribute('target'))

                if not Ball_Target then
                    return
                end

                if Target_Distance > Spam_Accuracy or Distance > Spam_Accuracy then
                    return
                end

                local Ball_Targeted_Distance = Player:DistanceFromCharacter(Ball_Target.PrimaryPart.Position)

                if Distance <= Spam_Accuracy and Parries > 1 then
                    Auto_Parry.Parry(Selected_Parry_Type)
                end
            end)
        else
            if Connections_Manager['Auto Spam'] then
                Connections_Manager['Auto Spam']:Disconnect()
                Connections_Manager['Auto Spam'] = nil
            end
        end
    end
})

-- Manuel Spam Section
rage:Section({ Title = "Manuel Spam" })

rage:Toggle({
    Title = "Manuel Spam",
    Desc = "Spams parry on key hold",
    Value = getgenv().autoSpam or false,
      Callback = function(state)
          getgenv().autoSpam = state
        getgenv().updateAutoSpam()
    end
})

rage:Keybind({
    Flag = "ManuelSpamKey",
    Title = "Spam Key",
    Desc = "Spam toggle keybind",
    Value = "E",
    Callback = function(v)
        getgenv().autoSpamKey = Enum.KeyCode[v]
        getgenv().updateAutoSpam()
    end
})

rage:Toggle({
    Title = "Spam Notify",
    Desc = "Show notification when manual spam toggled",
    Value = getgenv().autoSpamNotify or false,
      Callback = function(state)
          getgenv().autoSpamNotify = state
    end
})

-- Lobby Auto Parry Section
rage:Section({ Title = "Lobby Auto Parry" })

rage:Toggle({
    Title = "Lobby Auto Parry",
    Desc = "Auto parry lobby training ball",
    Value = getgenv().lobbyAutoParry or false,
      Callback = function(state)
          getgenv().lobbyAutoParry = state
        getgenv().updateLobbyAutoParry()
    end
})

rage:Slider({
    Flag = "LobbyParryAccuracy",
    Title = "Lobby Parry Accuracy",
    Desc = "Lobby parry accuracy",
    Step = 1,
    Value = { Min = 1, Max = 100, Default = 100 },
    Callback = function(value)
        getgenv().lobbyParryAccuracy = value
        getgenv().updateLobbyAutoParry()
    end
})

rage:Toggle({
    Title = "Lobby Random Accuracy",
    Desc = "Randomized accuracy",
    Value = getgenv().lobbyRandomAccuracy or false,
      Callback = function(state)
          getgenv().lobbyRandomAccuracy = state
    end
})

rage:Toggle({
    Title = "Lobby Parry Keypress",
    Desc = "Parries using remote",
    Value = getgenv().lobbyParryKeypress or false,
      Callback = function(state)
          getgenv().lobbyParryKeypress = state
    end
})

Visual:Section({ Title = "Sky" })

Visual:Toggle({
    Title = "Custom Sky",
    Desc = "Changes the skybox",
    Value = getgenv().customSky or false,
    Callback = function(state)
        getgenv().customSky = state
        getgenv().updateSky()
    end
})

Visual:Dropdown({
    Title = "Select Sky",
    Desc = "Select the sky theme",
    Values = { "Default", "Vaporwave", "Redshift", "Desert", "DaBaby", "Minecraft", "SpongeBob", "Skibidi", "Blaze", "Pussy Cat", "Among Us", "Space Wave", "Space Wave2", "Turquoise Wave", "Dark Night", "Bright Pink", "White Galaxy", "Blue Galaxy" },
    Value = getgenv().selectedSky or "Default",
    Callback = function(value)
        getgenv().selectedSky = value
        if getgenv().customSky then
            getgenv().applySkybox(value)
        end
    end
})

Visual:Section({ Title = "Ball Features" })

Visual:Toggle({
    Title = "Ball Stats",
    Desc = "Opens a panel showing ball velocity",
    Value = getgenv().ballStatsEnabled or false,
    Callback = function(state)
        getgenv().ballStatsEnabled = state
        getgenv().updateBallStats()
    end
})

Visual:Toggle({
    Title = "Ball Trail",
    Desc = "Leaves a trail behind the ball",
    Value = getgenv().ballTrailEnabled or false,
    Callback = function(state)
        getgenv().ballTrailEnabled = state
        getgenv().updateBallTrail()
    end
})

Visual:Slider({
    Flag = "BallTrailHue",
    Title = "Ball Trail Hue",
    Desc = "Ball trail color (applies if Rainbow is off)",
    Step = 1,
    Value = { Min = 0, Max = 360, Default = getgenv().ballTrailHue or 0 },
    Callback = function(value)
        getgenv().ballTrailHue = value
        if not getgenv().ballTrailRainbow then
            getgenv().ballTrailColor = Color3.fromHSV(value / 360, 1, 1)
        end
    end
})

Visual:Toggle({
    Title = "Rainbow Trail",
    Desc = "Color-changing ball trail",
    Value = getgenv().ballTrailRainbow or false,
    Callback = function(state)
        getgenv().ballTrailRainbow = state
        if not state then
            getgenv().ballTrailColor = Color3.fromHSV(getgenv().ballTrailHue / 360, 1, 1)
        end
    end
})

Visual:Toggle({
    Title = "Particle Emitter",
    Desc = "Emits particles behind the ball",
    Value = getgenv().ballTrailParticle or false,
    Callback = function(state)
        getgenv().ballTrailParticle = state
        if getgenv().ballTrailEnabled then getgenv().updateBallTrail() end
    end
})

Visual:Toggle({
    Title = "Glow Effect",
    Desc = "Adds a glowing effect around the ball",
    Value = getgenv().ballTrailGlow or false,
    Callback = function(state)
        getgenv().ballTrailGlow = state
        if getgenv().ballTrailEnabled then getgenv().updateBallTrail() end
    end
})


Visual:Toggle({
    Title = "Aura Effect",
    Desc = "Add an aura effect to the local player",
    Value = getgenv().self_effect_Enabled or false,
      Callback = function(state)
          getgenv().self_effect_Enabled = state
    end
})

Visual:Toggle({
    Title = "No Render",
    Desc = "No Parry Sound/Effect To Avoid Lag",
    Value = false,
    Callback = function(state)
        Player.PlayerScripts.EffectScripts.ClientFX.Disabled = state

        if state then
            Connections_Manager['No Render'] = workspace.Runtime.ChildAdded:Connect(function(Value)
                Debris:AddItem(Value, 0)
            end)
        else
            if Connections_Manager['No Render'] then
                Connections_Manager['No Render']:Disconnect()
                Connections_Manager['No Render'] = nil
            end
        end
    end
}) 
    
    ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(_, root)
    if root.Parent and root.Parent ~= Player.Character then
        if root.Parent.Parent ~= workspace.Alive then
            return
        end
    end

    Auto_Parry.Closest_Player()

    local Ball = Auto_Parry.Get_Ball()

    if not Ball then
        return
    end

    if not Grab_Parry then
        return
    end

    Grab_Parry:Stop()
end)

ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    if Player.Character.Parent ~= workspace.Alive then
        return
    end

    if not Grab_Parry then
        return
    end

    Grab_Parry:Stop()
end)

Runtime.ChildAdded:Connect(function(Value)
    if Value.Name == 'Tornado' then
        Aerodynamic_Time = tick()
        Aerodynamic = true
    end
end)

workspace.Balls.ChildAdded:Connect(function()
    Parried = false
end)

workspace.Balls.ChildRemoved:Connect(function()
    Parries = 0
    Parried = false

    if Connections_Manager['Target Change'] then
        Connections_Manager['Target Change']:Disconnect()
        Connections_Manager['Target Change'] = nil
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Levi Hub X",
    Content = "Anti-Cheat Bypassed\n[" .. string.char(math.random(65,90), math.random(65,90), math.random(65,90)) .. "-" .. math.random(1000,9999) .. "]",
    Duration = 5
})


task.spawn(function()
    while task.wait(5) do
        pcall(function()
            getgenv().saveConfig("AutoSave")
        end)
    end
end)
