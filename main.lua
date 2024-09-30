local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local TextLabel = Instance.new("TextLabel")
local TextButton = Instance.new("TextButton")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local currentPath = nil
local pathActive = false
local recalculateAttempts = 0
local maxRecalculateAttempts = 5

ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Frame.Parent = ScreenGui
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.BackgroundColor3 = Color3.fromRGB(29, 29, 29)
Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
Frame.Size = UDim2.new(0, 500, 0, 223)

TextLabel.Parent = Frame
TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.BackgroundTransparency = 1.000
TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
TextLabel.BorderSizePixel = 0
TextLabel.Position = UDim2.new(0.3, 0, 0, 0)
TextLabel.Size = UDim2.new(0, 200, 0, 44)
TextLabel.Font = Enum.Font.SourceSans
TextLabel.Text = "Test GUI"
TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.TextSize = 19.000
TextLabel.TextWrapped = true

TextButton.Parent = Frame
TextButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
TextButton.BorderSizePixel = 0
TextButton.Position = UDim2.new(0.04, 0, 0.25, 0)
TextButton.Size = UDim2.new(0, 78, 0, 33)
TextButton.Font = Enum.Font.SourceSans
TextButton.TextColor3 = Color3.fromRGB(0, 0, 0)
TextButton.TextSize = 14.000

local function visualizePath(waypoints)
	for _, waypoint in ipairs(waypoints) do
		local pathPart = Instance.new("Part")
		pathPart.Size = Vector3.new(1, 1, 1)
		pathPart.Color = Color3.fromRGB(0, 255, 0)
		pathPart.Position = waypoint.Position
		pathPart.Anchored = true
		pathPart.CanCollide = false
		pathPart.Parent = workspace
		Debris:AddItem(pathPart, 10)
	end
end

local function clearCurrentPath()
	if currentPath then
		currentPath:Destroy()
		currentPath = nil
	end
end

local function checkDoorLock(currentRoom)
	if currentRoom.Door and currentRoom.Door:FindFirstChild("Lock") then
		print("Door locked")
		return true
	else
		print("Door unlocked")
		return false
	end
end

local function findKeyObtain(currentRoom)
	for _, child in pairs(currentRoom:GetChildren()) do
		if child:IsA("Model") then
			local keyObtain = child:FindFirstChild("KeyObtain")
			if keyObtain then
				return keyObtain.Hitbox
			end
		end
	end
	return nil
end

local function moveToExit()
	local player = Players.LocalPlayer
	local currentRoomIndex = player:GetAttribute("CurrentRoom")
	local currentRoom = workspace.CurrentRooms:FindFirstChild(tostring(currentRoomIndex))

	if currentRoom and currentRoom:FindFirstChild("RoomExit") and not pathActive then
		if checkDoorLock(currentRoom) then
			local keyObtainHitbox = findKeyObtain(currentRoom)
			if keyObtainHitbox then
				print("KeyObtain found, moving to obtain it...")
				local character = player.Character or player.CharacterAdded:Wait()
				local humanoid = character:FindFirstChild("Humanoid")

				if humanoid and character.PrimaryPart then
					local path = PathfindingService:CreatePath({
						AgentRadius = 2,
						AgentHeight = 5,
						AgentCanJump = false,
						AgentJumpHeight = 0,
						AgentMaxSlope = 45,
					})

					path:ComputeAsync(character.PrimaryPart.Position, keyObtainHitbox.Position)
					local waypoints = path:GetWaypoints()

					if path.Status == Enum.PathStatus.Success then
						pathActive = true
						visualizePath(waypoints)

						for _, waypoint in ipairs(waypoints) do
							humanoid:MoveTo(waypoint.Position)
							local reached = humanoid.MoveToFinished:Wait()

							if not reached then
								print("Failed to reach KeyObtain, stopping search.")
								return
							end
						end

						local distanceToHitbox = (keyObtainHitbox.Position - character.PrimaryPart.Position).Magnitude
						if distanceToHitbox <= 4 then
							print("Obtained key")
						else
							humanoid:MoveTo(keyObtainHitbox.Position)
							humanoid.MoveToFinished:Wait()
							print("Obtained key")
						end

						return
					else
						print("Path to KeyObtain failed.")
						return
					end
				end
			else
				print("No KeyObtain found in the current room.")
				return
			end
		end

		local roomExit = currentRoom.RoomExit
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:FindFirstChild("Humanoid")

		if currentRoom.Door and currentRoom.Door:FindFirstChild("Door") then
			local door = currentRoom.Door.Door
			local pathfindingModifier = Instance.new("PathfindingModifier")
			pathfindingModifier.Parent = door
			pathfindingModifier.Label = "DoorIgnore"
			pathfindingModifier.PassThrough = true
		end

		if humanoid and character.PrimaryPart then
			local path = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = false,
				AgentJumpHeight = 0,
				AgentMaxSlope = 45,
			})

			path:ComputeAsync(character.PrimaryPart.Position, roomExit.Position)
			local waypoints = path:GetWaypoints()

			if path.Status == Enum.PathStatus.Success then
				pathActive = true
				visualizePath(waypoints)
				currentPath = path
				
				for _, waypoint in ipairs(waypoints) do
					humanoid:MoveTo(waypoint.Position)
					local reached = humanoid.MoveToFinished:Wait()

					if not reached then
						clearCurrentPath()
						recalculateAttempts = recalculateAttempts + 1
						if recalculateAttempts <= maxRecalculateAttempts then
							moveToExit()
						else
							print("Pathfinding failed after 5 attempts")
							local stuckPart = Instance.new("Part")
							stuckPart.Size = Vector3.new(2, 2, 2)
							stuckPart.Color = Color3.fromRGB(255, 0, 0)
							stuckPart.Position = waypoint.Position
							stuckPart.Anchored = true
							stuckPart.CanCollide = false
							stuckPart.Parent = workspace
							Debris:AddItem(stuckPart, 10)
							return
						end
						return
					end
				end

				humanoid:MoveTo(roomExit.Position)
				humanoid.MoveToFinished:Wait()
				print("Successfully reached the exit")
				
				pathActive = false
				clearCurrentPath()

				player:SetAttribute("CurrentRoom", currentRoomIndex + 1)
				moveToExit()
			end
		end
	end
end

UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Return then
		moveToExit()
	end
end)

local guiVisible = true
UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftControl then
		guiVisible = not guiVisible
		ScreenGui.Enabled = guiVisible
	end
end)

UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.C and pathActive then
		clearCurrentPath()
		pathActive = false
		print("Pathfinding canceled.")
	end
end)
