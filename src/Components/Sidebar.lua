-- Sidebar
-- Improved 24 May, 2025
-- Original mobile support: MachineFox :)

local midiPlayer = script:FindFirstAncestor("MidiPlayer")
local Thread = require(midiPlayer.Util.Thread)
local Controller = require(midiPlayer.Components.Controller)
local FastTween = require(midiPlayer.FastTween)

local Sidebar = {}

local tweenInfo = {0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out}

local sidebar, template, isDragging, startDragPosition, startScrollPosition, dragVelocity, lastDragTime

-- Helper to get all MIDI files in the midi directory
local function getMidiFiles()
    local all = listfiles("midi")
    local result = {}
    for _, path in ipairs(all) do
        if path:match("%.mid$") then
            table.insert(result, path)
        end
    end
    table.sort(result)
    return result
end

-- Create a sidebar element for a MIDI file
function Sidebar:CreateElement(filePath)
    local fullname = filePath:match("([^\\]+)$")
    local name = fullname:gsub("^midi/", ""):match("^([^%.]+)") or ""
    local extension = fullname:match("([^%.]+)$")
    if extension ~= "mid" then return end

    local element = template:Clone()
    element.Name = filePath
    element.Title.Text = name
    element.Title.TextTruncate = Enum.TextTruncate.AtEnd
    element.Title.TextWrapped = false

    -- Highlight if selected
    if Controller.CurrentFile == filePath then
        element.Selection.Size = UDim2.fromOffset(3, element.AbsoluteSize.Y)
        element.Selection.BackgroundTransparency = 0.2
    else
        element.Selection.Size = UDim2.fromOffset(3, 0)
        element.Selection.BackgroundTransparency = 1
    end

    -- Interactive feedback
    local function setHighlight(state)
        local t = {BackgroundTransparency = 1}
        if state == "hover" then
            t.BackgroundTransparency = 0.85
        elseif state == "active" then
            t.BackgroundTransparency = 0.5
        end
        FastTween(element, tweenInfo, t)
    end

    element.InputBegan:Connect(function(input)
        if not isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            setHighlight("active")
        end
    end)
    element.InputEnded:Connect(function(input)
        if not isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            setHighlight("hover")
            Controller:Select(filePath)
        end
    end)
    element.MouseEnter:Connect(function()
        setHighlight("hover")
    end)
    element.MouseLeave:Connect(function()
        setHighlight()
    end)

    -- Double-click to open file
    local lastClickTime = 0
    element.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClickTime < 0.4 then
            Controller:Select(filePath)
        end
        lastClickTime = now
    end)

    element.Parent = sidebar.Songs
end

-- Update sidebar to show all MIDI files
function Sidebar:Update()
    local files = getMidiFiles()
    local children = sidebar.Songs:GetChildren()

    -- Remove elements for files that no longer exist
    for _, element in ipairs(children) do
        if element:IsA("Frame") and not table.find(files, element.Name) then
            element:Destroy()
        end
    end

    -- Add missing files
    for _, filePath in ipairs(files) do
        if not sidebar.Songs:FindFirstChild(filePath) then
            self:CreateElement(filePath)
        end
    end

    -- Resize Canvas
    local n = #sidebar.Songs:GetChildren()
    local elementHeight = template.AbsoluteSize.Y
    sidebar.Songs.CanvasSize = UDim2.new(0, 0, 0, n * elementHeight)
end

-- Improved drag scrolling with inertia
local function setupScrolling()
    isDragging = false
    dragVelocity = 0
    lastDragTime = 0

    sidebar.Songs.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            startDragPosition = input.Position
            startScrollPosition = sidebar.Songs.CanvasPosition
            dragVelocity = 0
            lastDragTime = tick()
        end
    end)

    sidebar.Songs.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local now = tick()
            local delta = input.Position - startDragPosition
            sidebar.Songs.CanvasPosition = Vector2.new(
                startScrollPosition.X,
                math.max(0, startScrollPosition.Y - delta.Y)
            )
            dragVelocity = -delta.Y / (now - lastDragTime + 0.001)
            lastDragTime = now
        end
    end)

    sidebar.Songs.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    -- Inertia scroll
    Thread.DelayRepeat(0.016, function()
        if not isDragging and math.abs(dragVelocity) > 1 then
            local pos = sidebar.Songs.CanvasPosition
            local newY = math.clamp(pos.Y + dragVelocity * 0.016, 0, sidebar.Songs.CanvasSize.Y.Offset)
            sidebar.Songs.CanvasPosition = Vector2.new(pos.X, newY)
            dragVelocity = dragVelocity * 0.92
        end
    end)
end

-- Initialize sidebar
function Sidebar:Init(frame)
    sidebar = frame.Sidebar
    template = sidebar.Songs.Song
    template.Parent = nil

    Controller.FileLoaded:Connect(function(song)
        for _, element in ipairs(sidebar.Songs:GetChildren()) do
            if element:IsA("Frame") then
                if element.Name == song.Path then
                    FastTween(element.Selection, tweenInfo, {Size = UDim2.fromOffset(3, element.AbsoluteSize.Y), BackgroundTransparency = 0.2})
                else
                    FastTween(element.Selection, tweenInfo, {Size = UDim2.fromOffset(3, 0), BackgroundTransparency = 1})
                end
            end
        end
    end)

    setupScrolling()
    Thread.DelayRepeat(1, self.Update, self)
    self:Update()
end

return Sidebar
