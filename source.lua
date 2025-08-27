-- VoidX Framework v3.1 | Enhanced Professional Roblox UI Library
-- Multi-Select Dropdown & Universal Refresh Features

local VoidX = {}
VoidX.__index = VoidX

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Get proper GUI parent
local function GetGuiParent()
    local success, result = pcall(function()
        return game:GetService("CoreGui")
    end)
    
    if success then
        return result
    else
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local GuiParent = GetGuiParent()

-- Destroy existing GUIs
for _, gui in pairs(GuiParent:GetChildren()) do
    if gui.Name and gui.Name:find("VoidX") then
        gui:Destroy()
    end
end

-- Global Storage
if getgenv then
    getgenv().VoidXConnections = getgenv().VoidXConnections or {}
    for _, connection in pairs(getgenv().VoidXConnections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    getgenv().VoidXConnections = {}
end

-- Configuration
local Config = {
    Themes = {
        Night = {
            Background = Color3.fromRGB(26, 26, 46),
            Secondary = Color3.fromRGB(15, 15, 25),
            Accent = Color3.fromRGB(102, 126, 234),
            AccentDark = Color3.fromRGB(118, 75, 162),
            Text = Color3.fromRGB(255, 255, 255),
            TextDim = Color3.fromRGB(180, 180, 180),
            Border = Color3.fromRGB(40, 40, 60),
            Toggle = Color3.fromRGB(102, 126, 234),
            ContentBG = Color3.fromRGB(20, 20, 35)
        },
        Ocean = {
            Background = Color3.fromRGB(0, 31, 63),
            Secondary = Color3.fromRGB(0, 20, 40),
            Accent = Color3.fromRGB(0, 119, 190),
            AccentDark = Color3.fromRGB(0, 77, 122),
            Text = Color3.fromRGB(255, 255, 255),
            TextDim = Color3.fromRGB(180, 200, 220),
            Border = Color3.fromRGB(0, 50, 80),
            Toggle = Color3.fromRGB(0, 150, 200),
            ContentBG = Color3.fromRGB(0, 25, 50)
        },
        Sunset = {
            Background = Color3.fromRGB(44, 24, 16),
            Secondary = Color3.fromRGB(30, 15, 10),
            Accent = Color3.fromRGB(255, 107, 107),
            AccentDark = Color3.fromRGB(78, 205, 196),
            Text = Color3.fromRGB(255, 255, 255),
            TextDim = Color3.fromRGB(220, 180, 180),
            Border = Color3.fromRGB(60, 30, 20),
            Toggle = Color3.fromRGB(255, 120, 120),
            ContentBG = Color3.fromRGB(35, 20, 13)
        }
    },
    AnimationSpeed = 0.25,
    EasingStyle = Enum.EasingStyle.Cubic,
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
    DefaultToggleKey = Enum.KeyCode.RightShift,
    KeySystem = {
        Enabled = false,
        Key = "",
        SaveKey = true,
        FileName = "VoidXKey"
    },
    ConfigSystem = {
        Enabled = true,
        FolderName = "VoidXConfigs",
        AutoSave = true
    }
}

-- Global Settings Storage
local GlobalSettings = {
    UIToggle = true,
    ToggleKey = Config.DefaultToggleKey,
    KeybindList = {},
    CurrentConfig = "Default",
    Notifications = {},
    Theme = "Night"
}

-- Utility Functions
local function CreateTween(instance, properties, duration, style)
    duration = duration or Config.AnimationSpeed
    style = style or Config.EasingStyle
    
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration, style, Enum.EasingDirection.InOut),
        properties
    )
    tween:Play()
    return tween
end

local function CreateInstance(className, properties, parent)
    local success, instance = pcall(function()
        local obj = Instance.new(className)
        for prop, value in pairs(properties or {}) do
            if prop ~= "Parent" then
                obj[prop] = value
            end
        end
        return obj
    end)
    
    if success and instance then
        if parent then
            instance.Parent = parent
        end
        return instance
    else
        warn("Failed to create instance:", className)
        return nil
    end
end

local function MakeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- Advanced Config System
local ConfigManager = {}

function ConfigManager:SaveConfig(configName, data)
    if not Config.ConfigSystem.Enabled then return end
    
    local fileName = Config.ConfigSystem.FolderName .. "/" .. configName .. ".json"
    local success, err = pcall(function()
        if writefile then
            writefile(fileName, HttpService:JSONEncode(data))
        end
    end)
    
    if not success then
        warn("Failed to save config:", err)
    end
end

function ConfigManager:LoadConfig(configName)
    if not Config.ConfigSystem.Enabled then return {} end
    
    local fileName = Config.ConfigSystem.FolderName .. "/" .. configName .. ".json"
    local success, data = pcall(function()
        if readfile and isfile and isfile(fileName) then
            return HttpService:JSONDecode(readfile(fileName))
        end
    end)
    
    if success and data then
        return data
    else
        return {}
    end
end

-- Main Window Constructor
function VoidX:CreateWindow(options)
    options = options or {}
    local windowName = options.Name or "VoidX Framework"
    local windowSubtitle = options.Subtitle or "v3.1 Enhanced"
    local windowTheme = options.Theme or "Night"
    local windowSize = options.Size or UDim2.new(0, 900, 0, 600)
    
    local window = {}
    window.Theme = Config.Themes[windowTheme]
    window.Tabs = {}
    window.ActiveTab = nil
    window.SettingsTab = nil
    window.Elements = {}
    
    -- Create ScreenGui
    local screenGui = CreateInstance("ScreenGui", {
        Name = "VoidX_MainGUI",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        IgnoreGuiInset = true
    })
    screenGui.Parent = GuiParent
    
    -- Loading Screen
    local loadingFrame = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(20, 20, 30),
        BorderSizePixel = 0
    })
    loadingFrame.Parent = screenGui
    
    local loadingText = CreateInstance("TextLabel", {
        Size = UDim2.new(0, 200, 0, 50),
        Position = UDim2.new(0.5, -100, 0.5, -25),
        BackgroundTransparency = 1,
        Text = windowName,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 24,
        Font = Enum.Font.GothamBold
    })
    loadingText.Parent = loadingFrame
    
    local loadingBar = CreateInstance("Frame", {
        Size = UDim2.new(0, 0, 0, 3),
        Position = UDim2.new(0.5, -100, 0.5, 15),
        BackgroundColor3 = Config.Themes[windowTheme].Accent,
        BorderSizePixel = 0
    })
    loadingBar.Parent = loadingFrame
    
    CreateTween(loadingBar, {Size = UDim2.new(0, 200, 0, 3)}, 1)
    wait(1)
    CreateTween(loadingFrame, {BackgroundTransparency = 1}, 0.5)
    CreateTween(loadingText, {TextTransparency = 1}, 0.5)
    CreateTween(loadingBar, {BackgroundTransparency = 1}, 0.5)
    wait(0.5)
    loadingFrame:Destroy()
    
    -- Main Frame
    local mainFrame = CreateInstance("Frame", {
        Name = "MainFrame",
        Size = windowSize,
        Position = UDim2.new(0.5, -windowSize.X.Offset/2, 1.5, 0),
        BackgroundColor3 = window.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true
    })
    mainFrame.Parent = screenGui
    
    -- Animate main frame entrance
    CreateTween(mainFrame, {Position = UDim2.new(0.5, -windowSize.X.Offset/2, 0.5, -windowSize.Y.Offset/2)}, 0.5, Enum.EasingStyle.Back)
    
    CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 20)
    }, mainFrame)
    
    -- Sidebar
    local sidebar = CreateInstance("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 250, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = window.Theme.Secondary,
        BorderSizePixel = 0
    })
    sidebar.Parent = mainFrame
    
    CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 20)
    }, sidebar)
    
    -- Logo Section
    local logoSection = CreateInstance("Frame", {
        Name = "LogoSection",
        Size = UDim2.new(1, -30, 0, 80),
        Position = UDim2.new(0, 15, 0, 15),
        BackgroundTransparency = 1
    })
    logoSection.Parent = sidebar
    
    local logoText = CreateInstance("TextLabel", {
        Name = "Logo",
        Size = UDim2.new(1, 0, 0, 35),
        Position = UDim2.new(0, 0, 0, 5),
        BackgroundTransparency = 1,
        Text = windowName,
        TextColor3 = window.Theme.Accent,
        TextScaled = true,
        Font = Config.FontBold
    })
    logoText.Parent = logoSection
    
    -- Tab Container
    local tabContainer = CreateInstance("ScrollingFrame", {
        Name = "TabContainer",
        Size = UDim2.new(1, -30, 1, -120),
        Position = UDim2.new(0, 15, 0, 100),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = window.Theme.Accent,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y
    })
    tabContainer.Parent = sidebar
    
    CreateInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5)
    }, tabContainer)
    
    -- Content Area
    local contentArea = CreateInstance("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -260, 1, -20),
        Position = UDim2.new(0, 260, 0, 10),
        BackgroundColor3 = window.Theme.ContentBG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0
    })
    contentArea.Parent = mainFrame
    
    CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 15)
    }, contentArea)
    
    -- Make window draggable
    MakeDraggable(mainFrame, logoSection)
    
    -- Tab Creation Method
    function window:CreateTab(tabName, tabIcon)
        local tab = {}
        tab.Name = tabName
        tab.Elements = {}
        
        -- Tab Button
        local tabButton = CreateInstance("Frame", {
            Name = tabName .. "Tab",
            Size = UDim2.new(1, 0, 0, 45),
            BackgroundColor3 = window.Theme.Background,
            BackgroundTransparency = 1
        })
        tabButton.Parent = tabContainer
        
        CreateInstance("UICorner", {
            CornerRadius = UDim.new(0, 12)
        }, tabButton)
        
        local tabLabel = CreateInstance("TextLabel", {
            Name = "TabLabel",
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 45, 0, 0),
            BackgroundTransparency = 1,
            Text = tabName,
            TextColor3 = window.Theme.TextDim,
            TextSize = 14,
            Font = Config.Font,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        tabLabel.Parent = tabButton
        
        if tabIcon then
            local iconLabel = CreateInstance("TextLabel", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 15, 0.5, -10),
                BackgroundTransparency = 1,
                Text = tabIcon,
                TextColor3 = window.Theme.TextDim,
                TextSize = 20,
                Font = Config.Font
            })
            iconLabel.Parent = tabButton
        end
        
        local tabButtonClick = CreateInstance("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextTransparency = 1
        })
        tabButtonClick.Parent = tabButton
        
        -- Tab Content Frame
        local tabContent = CreateInstance("ScrollingFrame", {
            Name = tabName .. "Content",
            Size = UDim2.new(1, -20, 1, -20),
            Position = UDim2.new(0, 10, 0, 10),
            BackgroundTransparency = 1,
            Visible = false,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = window.Theme.Accent,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y
        })
        tabContent.Parent = contentArea
        
        local contentLayout = CreateInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 15)
        })
        contentLayout.Parent = tabContent
        
        -- Tab Header
        local tabHeader = CreateInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 80),
            BackgroundTransparency = 1,
            LayoutOrder = 0
        })
        tabHeader.Parent = tabContent
        
        local tabTitle = CreateInstance("TextLabel", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundTransparency = 1,
            Text = tabName,
            TextColor3 = window.Theme.Text,
            TextSize = 32,
            Font = Config.FontBold,
            TextXAlignment = Enum.TextXAlignment.Left
        })
        tabTitle.Parent = tabHeader
        
        -- Auto-resize content
        contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabContent.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 20)
        end)
        
        -- Tab Selection
        tabButtonClick.MouseButton1Click:Connect(function()
            window:SelectTab(tab)
        end)
        
        -- Multi-Select Dropdown Element (NEW!)
        function tab:CreateMultiDropdown(options)
            options = options or {}
            local dropdownName = options.Name or "Multi Dropdown"
            local dropdownList = options.Options or {}
            local dropdownDefault = options.Default or {}
            local dropdownCallback = options.Callback or function() end
            local dropdownRefresh = options.Refresh or nil
            local dropdownMaxSelect = options.MaxSelect or nil
            
            local dropdownFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = window.Theme.Background,
                BackgroundTransparency = 0.7,
                ClipsDescendants = true,
                LayoutOrder = 107
            })
            dropdownFrame.Parent = tabContent
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(0, 12)
            }, dropdownFrame)
            
            local dropdownButton = CreateInstance("TextButton", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundTransparency = 1,
                Text = "",
                TextTransparency = 1
            })
            dropdownButton.Parent = dropdownFrame
            
            local dropdownLabel = CreateInstance("TextLabel", {
                Size = UDim2.new(1, -120, 1, 0),
                Position = UDim2.new(0, 20, 0, 0),
                BackgroundTransparency = 1,
                Text = #dropdownDefault > 0 and table.concat(dropdownDefault, ", ") or dropdownName,
                TextColor3 = window.Theme.Text,
                TextSize = 14,
                Font = Config.Font,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            })
            dropdownLabel.Parent = dropdownButton
            
            -- Selected count indicator
            local countLabel = CreateInstance("TextLabel", {
                Size = UDim2.new(0, 30, 0, 20),
                Position = UDim2.new(1, -90, 0, 5),
                BackgroundColor3 = window.Theme.Accent,
                Text = tostring(#dropdownDefault),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 12,
                Font = Config.FontBold
            })
            countLabel.Parent = dropdownButton
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(1, 0)
            }, countLabel)
            
            -- Refresh button
            local refreshButton = nil
            if dropdownRefresh then
                refreshButton = CreateInstance("TextButton", {
                    Size = UDim2.new(0, 30, 0, 30),
                    Position = UDim2.new(1, -70, 0.5, -15),
                    BackgroundColor3 = window.Theme.Secondary,
                    BorderSizePixel = 0,
                    Text = "↻",
                    TextColor3 = window.Theme.TextDim,
                    TextSize = 18,
                    Font = Config.Font,
                    Rotation = 0
                })
                refreshButton.Parent = dropdownFrame
                
                CreateInstance("UICorner", {
                    CornerRadius = UDim.new(0, 6)
                }, refreshButton)
                
                refreshButton.MouseButton1Click:Connect(function()
                    CreateTween(refreshButton, {Rotation = 360}, 0.5)
                    task.wait(0.5)
                    refreshButton.Rotation = 0
                    
                    local newOptions = dropdownRefresh()
                    if newOptions then
                        dropdownList = newOptions
                        
                        -- Clear and recreate options
                        for _, child in pairs(dropdownListFrame:GetChildren()) do
                            if child:IsA("Frame") and child.Name ~= "UIListLayout" then
                                child:Destroy()
                            end
                        end
                        
                        createOptions()
                    end
                end)
            end
            
            local dropdownArrow = CreateInstance("TextLabel", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(1, -40, 0, 15),
                BackgroundTransparency = 1,
                Text = "▼",
                TextColor3 = window.Theme.TextDim,
                TextSize = 12,
                Font = Config.Font
            })
            dropdownArrow.Parent = dropdownButton
            
            local dropdownListFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 0, 50),
                BackgroundColor3 = window.Theme.Secondary,
                BorderSizePixel = 0,
                Visible = true
            })
            dropdownListFrame.Parent = dropdownFrame
            
            local dropdownListLayout = CreateInstance("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 2)
            })
            dropdownListLayout.Parent = dropdownListFrame
            
            local isOpen = false
            local selectedOptions = {}
            
            -- Initialize with defaults
            for _, option in ipairs(dropdownDefault) do
                selectedOptions[option] = true
            end
            
            local function updateDisplay()
                local selectedList = {}
                for option, selected in pairs(selectedOptions) do
                    if selected then
                        table.insert(selectedList, option)
                    end
                end
                
                if #selectedList > 0 then
                    dropdownLabel.Text = table.concat(selectedList, ", ")
                else
                    dropdownLabel.Text = dropdownName
                end
                
                countLabel.Text = tostring(#selectedList)
                
                -- Update count color based on limit
                if dropdownMaxSelect and #selectedList >= dropdownMaxSelect then
                    CreateTween(countLabel, {BackgroundColor3 = Color3.fromRGB(255, 100, 100)}, 0.2)
                else
                    CreateTween(countLabel, {BackgroundColor3 = window.Theme.Accent}, 0.2)
                end
                
                pcall(function()
                    dropdownCallback(selectedList)
                end)
            end
            
            -- Create dropdown options
            local function createOptions()
                for _, option in ipairs(dropdownList) do
                    local optionFrame = CreateInstance("Frame", {
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundColor3 = window.Theme.Background,
                        BackgroundTransparency = 0.9,
                        BorderSizePixel = 0
                    })
                    optionFrame.Parent = dropdownListFrame
                    
                    local checkbox = CreateInstance("Frame", {
                        Size = UDim2.new(0, 16, 0, 16),
                        Position = UDim2.new(0, 10, 0.5, -8),
                        BackgroundColor3 = window.Theme.Border,
                        BorderSizePixel = 0
                    })
                    checkbox.Parent = optionFrame
                    
                    CreateInstance("UICorner", {
                        CornerRadius = UDim.new(0, 4)
                    }, checkbox)
                    
                    local checkmark = CreateInstance("TextLabel", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "✓",
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 12,
                        Font = Config.FontBold,
                        TextStrokeTransparency = 0,
                        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
                        Visible = selectedOptions[option] or false
                    })
                    checkmark.Parent = checkbox
                    
                    local optionLabel = CreateInstance("TextLabel", {
                        Size = UDim2.new(1, -40, 1, 0),
                        Position = UDim2.new(0, 35, 0, 0),
                        BackgroundTransparency = 1,
                        Text = option,
                        TextColor3 = window.Theme.TextDim,
                        TextSize = 13,
                        Font = Config.Font,
                        TextXAlignment = Enum.TextXAlignment.Left
                    })
                    optionLabel.Parent = optionFrame
                    
                    local optionButton = CreateInstance("TextButton", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "",
                        TextTransparency = 1
                    })
                    optionButton.Parent = optionFrame
                    
                    -- Update checkbox visual
                    local function updateCheckbox()
                        if selectedOptions[option] then
                            CreateTween(checkbox, {BackgroundColor3 = window.Theme.Accent}, 0.2)
                            checkmark.Visible = true
                        else
                            CreateTween(checkbox, {BackgroundColor3 = window.Theme.Border}, 0.2)
                            checkmark.Visible = false
                        end
                    end
                    
                    updateCheckbox()
                    
                    optionButton.MouseButton1Click:Connect(function()
                        -- Check selection limit
                        local currentSelected = 0
                        for _, selected in pairs(selectedOptions) do
                            if selected then currentSelected = currentSelected + 1 end
                        end
                        
                        if selectedOptions[option] then
                            -- Deselect
                            selectedOptions[option] = false
                        else
                            -- Select (if under limit)
                            if not dropdownMaxSelect or currentSelected < dropdownMaxSelect then
                                selectedOptions[option] = true
                            else
                                return -- Limit reached
                            end
                        end
                        
                        updateCheckbox()
                        updateDisplay()
                    end)
                end
            end
            
            createOptions()
            
            dropdownButton.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                
                if isOpen then
                    local contentHeight = math.min(dropdownListLayout.AbsoluteContentSize.Y, 200)
                    CreateTween(dropdownFrame, {
                        Size = UDim2.new(1, 0, 0, 50 + contentHeight)
                    })
                    CreateTween(dropdownArrow, {Rotation = 180})
                else
                    CreateTween(dropdownFrame, {Size = UDim2.new(1, 0, 0, 50)})
                    CreateTween(dropdownArrow, {Rotation = 0})
                end
            end)
            
            updateDisplay()
            
            local element = {
                Name = dropdownName,
                SetOptions = function(options)
                    selectedOptions = {}
                    for _, option in ipairs(options or {}) do
                        selectedOptions[option] = true
                    end
                    updateDisplay()
                end,
                GetOptions = function()
                    local selected = {}
                    for option, isSelected in pairs(selectedOptions) do
                        if isSelected then
                            table.insert(selected, option)
                        end
                    end
                    return selected
                end,
                Clear = function()
                    selectedOptions = {}
                    updateDisplay()
                end,
                Refresh = function()
                    if dropdownRefresh then
                        local newOptions = dropdownRefresh()
                        if newOptions then
                            dropdownList = newOptions
                            createOptions()
                        end
                    end
                end
            }
            
            table.insert(tab.Elements, element)
            table.insert(window.Elements, element)
            return element
        end
        
        -- Toggle Element (Enhanced with ToggleOff and Refresh)
        function tab:CreateToggle(options)
            options = options or {}
            local toggleName = options.Name or "Toggle"
            local toggleDefault = options.Default or false
            local toggleCallback = options.Callback or function() end
            local toggleRefresh = options.Refresh or nil
            
            local toggleFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = window.Theme.Background,
                BackgroundTransparency = 0.7,
                LayoutOrder = 104
            })
            toggleFrame.Parent = tabContent
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(0, 12)
            }, toggleFrame)
            
            local toggleLabel = CreateInstance("TextLabel", {
                Size = UDim2.new(1, -100, 1, 0),
                Position = UDim2.new(0, 20, 0, 0),
                BackgroundTransparency = 1,
                Text = toggleName,
                TextColor3 = window.Theme.Text,
                TextSize = 14,
                Font = Config.Font,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            toggleLabel.Parent = toggleFrame
            
            -- Refresh Button
            local refreshButton = nil
            if toggleRefresh then
                refreshButton = CreateInstance("TextButton", {
                    Size = UDim2.new(0, 25, 0, 25),
                    Position = UDim2.new(1, -85, 0.5, -12),
                    BackgroundColor3 = window.Theme.Secondary,
                    BorderSizePixel = 0,
                    Text = "↻",
                    TextColor3 = window.Theme.TextDim,
                    TextSize = 16,
                    Font = Config.Font,
                    Rotation = 0
                })
                refreshButton.Parent = toggleFrame
                
                CreateInstance("UICorner", {
                    CornerRadius = UDim.new(0, 6)
                }, refreshButton)
                
                refreshButton.MouseButton1Click:Connect(function()
                    CreateTween(refreshButton, {Rotation = 360}, 0.5)
                    task.wait(0.5)
                    refreshButton.Rotation = 0
                    toggleRefresh()
                end)
            end
            
            local toggleSwitch = CreateInstance("Frame", {
                Size = UDim2.new(0, 48, 0, 26),
                Position = UDim2.new(1, -60, 0.5, -13),
                BackgroundColor3 = window.Theme.Border
            })
            toggleSwitch.Parent = toggleFrame
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(1, 0)
            }, toggleSwitch)
            
            local toggleCircle = CreateInstance("Frame", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 3, 0, 3),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            })
            toggleCircle.Parent = toggleSwitch
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(1, 0)
            }, toggleCircle)
            
            local toggleButton = CreateInstance("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                TextTransparency = 1
            })
            toggleButton.Parent = toggleFrame
            
            local toggled = toggleDefault
            
            local function updateToggle()
                if toggled then
                    CreateTween(toggleSwitch, {BackgroundColor3 = window.Theme.Toggle}, 0.3)
                    CreateTween(toggleCircle, {Position = UDim2.new(0, 25, 0, 3)}, 0.3, Enum.EasingStyle.Back)
                else
                    CreateTween(toggleSwitch, {BackgroundColor3 = window.Theme.Border}, 0.3)
                    CreateTween(toggleCircle, {Position = UDim2.new(0, 3, 0, 3)}, 0.3, Enum.EasingStyle.Back)
                end
                
                pcall(function()
                    toggleCallback(toggled)
                end)
            end
            
            toggleButton.MouseButton1Click:Connect(function()
                toggled = not toggled
                updateToggle()
            end)
            
            updateToggle()
            
            local element = {
                Name = toggleName,
                SetValue = function(value)
                    toggled = value
                    updateToggle()
                end,
                GetValue = function()
                    return toggled
                end,
                ToggleOff = function()
                    toggled = false
                    updateToggle()
                end,
                ToggleOn = function()
                    toggled = true
                    updateToggle()
                end,
                Refresh = function()
                    if toggleRefresh then
                        toggleRefresh()
                    end
                end
            }
            
            table.insert(tab.Elements, element)
            table.insert(window.Elements, element)
            return element
        end
        
        -- Button Element (Enhanced with Refresh)
        function tab:CreateButton(options)
            options = options or {}
            local buttonName = options.Name or "Button"
            local buttonCallback = options.Callback or function() end
            local buttonRefresh = options.Refresh or nil
            
            local buttonFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 45),
                BackgroundTransparency = 1,
                LayoutOrder = 106
            })
            buttonFrame.Parent = tabContent
            
            local button = CreateInstance("TextButton", {
                Size = buttonRefresh and UDim2.new(1, -35, 1, 0) or UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = window.Theme.Accent,
                BorderSizePixel = 0,
                Text = buttonName,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 14,
                Font = Config.FontBold,
                ClipsDescendants = true
            })
            button.Parent = buttonFrame
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(0, 10)
            }, button)
            
            -- Refresh Button
            local refreshButton = nil
            if buttonRefresh then
                refreshButton = CreateInstance("TextButton", {
                    Size = UDim2.new(0, 30, 1, 0),
                    Position = UDim2.new(1, -30, 0, 0),
                    BackgroundColor3 = window.Theme.AccentDark,
                    BorderSizePixel = 0,
                    Text = "↻",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 18,
                    Font = Config.Font,
                    Rotation = 0,
                    ClipsDescendants = true
                })
                refreshButton.Parent = buttonFrame
                
                CreateInstance("UICorner", {
                    CornerRadius = UDim.new(0, 10)
                }, refreshButton)
                
                refreshButton.MouseButton1Click:Connect(function()
                    CreateTween(refreshButton, {Rotation = 360}, 0.5)
                    task.wait(0.5)
                    refreshButton.Rotation = 0
                    buttonRefresh()
                end)
            end
            
            button.MouseButton1Click:Connect(function()
                pcall(buttonCallback)
            end)
            
            local element = {
                SetText = function(text)
                    button.Text = text
                end,
                Refresh = function()
                    if buttonRefresh then
                        buttonRefresh()
                    end
                end
            }
            
            table.insert(window.Elements, element)
            return element
        end
        
        -- Dropdown Element (Enhanced with Refresh)
        function tab:CreateDropdown(options)
            options = options or {}
            local dropdownName = options.Name or "Dropdown"
            local dropdownList = options.Options or {}
            local dropdownDefault = options.Default or dropdownList[1]
            local dropdownCallback = options.Callback or function() end
            local dropdownRefresh = options.Refresh or nil
            
            local dropdownFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = window.Theme.Background,
                BackgroundTransparency = 0.7,
                ClipsDescendants = true,
                LayoutOrder = 107
            })
            dropdownFrame.Parent = tabContent
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(0, 12)
            }, dropdownFrame)
            
            local dropdownButton = CreateInstance("TextButton", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundTransparency = 1,
                Text = "",
                TextTransparency = 1
            })
            dropdownButton.Parent = dropdownFrame
            
            local dropdownLabel = CreateInstance("TextLabel", {
                Size = UDim2.new(1, -90, 1, 0),
                Position = UDim2.new(0, 20, 0, 0),
                BackgroundTransparency = 1,
                Text = dropdownDefault or dropdownName,
                TextColor3 = window.Theme.Text,
                TextSize = 14,
                Font = Config.Font,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            dropdownLabel.Parent = dropdownButton
            
            -- Refresh button
            local refreshButton = nil
            if dropdownRefresh then
                refreshButton = CreateInstance("TextButton", {
                    Size = UDim2.new(0, 30, 0, 30),
                    Position = UDim2.new(1, -70, 0.5, -15),
                    BackgroundColor3 = window.Theme.Secondary,
                    BorderSizePixel = 0,
                    Text = "↻",
                    TextColor3 = window.Theme.TextDim,
                    TextSize = 18,
                    Font = Config.Font,
                    Rotation = 0
                })
                refreshButton.Parent = dropdownFrame
                
                CreateInstance("UICorner", {
                    CornerRadius = UDim.new(0, 6)
                }, refreshButton)
                
                refreshButton.MouseButton1Click:Connect(function()
                    CreateTween(refreshButton, {Rotation = 360}, 0.5)
                    task.wait(0.5)
                    refreshButton.Rotation = 0
                    
                    local newOptions = dropdownRefresh()
                    if newOptions then
                        dropdownList = newOptions
                        createOptions()
                    end
                end)
            end
            
            local dropdownArrow = CreateInstance("TextLabel", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(1, -40, 0, 15),
                BackgroundTransparency = 1,
                Text = "▼",
                TextColor3 = window.Theme.TextDim,
                TextSize = 12,
                Font = Config.Font
            })
            dropdownArrow.Parent = dropdownButton
            
            local dropdownListFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 0, 50),
                BackgroundColor3 = window.Theme.Secondary,
                BorderSizePixel = 0,
                Visible = true
            })
            dropdownListFrame.Parent = dropdownFrame
            
            local dropdownListLayout = CreateInstance("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder
            })
            dropdownListLayout.Parent = dropdownListFrame
            
            local isOpen = false
            local currentOption = dropdownDefault
            
            -- Create dropdown options
            local function createOptions()
                for _, child in pairs(dropdownListFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end
                
                for _, option in ipairs(dropdownList) do
                    local optionButton = CreateInstance("TextButton", {
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundColor3 = window.Theme.Background,
                        BackgroundTransparency = 0.9,
                        Text = option,
                        TextColor3 = window.Theme.TextDim,
                        TextSize = 13,
                        Font = Config.Font
                    })
                    optionButton.Parent = dropdownListFrame
                    
                    optionButton.MouseButton1Click:Connect(function()
                        currentOption = option
                        dropdownLabel.Text = option
                        pcall(function()
                            dropdownCallback(option)
                        end)
                        
                        -- Close dropdown
                        isOpen = false
                        CreateTween(dropdownFrame, {Size = UDim2.new(1, 0, 0, 50)})
                        CreateTween(dropdownArrow, {Rotation = 0})
                    end)
                end
            end
            
            createOptions()
            
            dropdownButton.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                
                if isOpen then
                    local contentHeight = dropdownListLayout.AbsoluteContentSize.Y
                    CreateTween(dropdownFrame, {
                        Size = UDim2.new(1, 0, 0, 50 + contentHeight)
                    })
                    CreateTween(dropdownArrow, {Rotation = 180})
                else
                    CreateTween(dropdownFrame, {Size = UDim2.new(1, 0, 0, 50)})
                    CreateTween(dropdownArrow, {Rotation = 0})
                end
            end)
            
            local element = {
                Name = dropdownName,
                SetOption = function(option)
                    currentOption = option
                    dropdownLabel.Text = option
                    pcall(function()
                        dropdownCallback(option)
                    end)
                end,
                GetOption = function()
                    return currentOption
                end,
                UpdateOptions = function(newOptions)
                    dropdownList = newOptions or {}
                    createOptions()
                end,
                Refresh = function()
                    if dropdownRefresh then
                        local newOptions = dropdownRefresh()
                        if newOptions then
                            dropdownList = newOptions
                            createOptions()
                        end
                    end
                end
            }
            
            table.insert(tab.Elements, element)
            table.insert(window.Elements, element)
            return element
        end
        
        -- Slider Element (Enhanced with Refresh)
        function tab:CreateSlider(options)
            options = options or {}
            local sliderName = options.Name or "Slider"
            local sliderMin = options.Min or 0
            local sliderMax = options.Max or 100
            local sliderDefault = options.Default or sliderMin
            local sliderIncrement = options.Increment or 1
            local sliderCallback = options.Callback or function() end
            local sliderRefresh = options.Refresh or nil
            
            local sliderFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 70),
                BackgroundColor3 = window.Theme.Background,
                BackgroundTransparency = 0.7,
                LayoutOrder = 105
            })
            sliderFrame.Parent = tabContent
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(0, 12)
            }, sliderFrame)
            
            local sliderHeader = CreateInstance("Frame", {
                Size = UDim2.new(1, -40, 0, 30),
                Position = UDim2.new(0, 20, 0, 10),
                BackgroundTransparency = 1
            })
            sliderHeader.Parent = sliderFrame
            
            local sliderLabel = CreateInstance("TextLabel", {
                Size = sliderRefresh and UDim2.new(0.55, 0, 1, 0) or UDim2.new(0.7, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = sliderName,
                TextColor3 = window.Theme.Text,
                TextSize = 14,
                Font = Config.Font,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            sliderLabel.Parent = sliderHeader
            
            -- Refresh Button
            local refreshButton = nil
            if sliderRefresh then
                refreshButton = CreateInstance("TextButton", {
                    Size = UDim2.new(0, 25, 0, 25),
                    Position = UDim2.new(0.6, 0, 0.5, -12),
                    BackgroundColor3 = window.Theme.Secondary,
                    BorderSizePixel = 0,
                    Text = "↻",
                    TextColor3 = window.Theme.TextDim,
                    TextSize = 16,
                    Font = Config.Font,
                    Rotation = 0
                })
                refreshButton.Parent = sliderHeader
                
                CreateInstance("UICorner", {
                    CornerRadius = UDim.new(0, 6)
                }, refreshButton)
                
                refreshButton.MouseButton1Click:Connect(function()
                    CreateTween(refreshButton, {Rotation = 360}, 0.5)
                    task.wait(0.5)
                    refreshButton.Rotation = 0
                    sliderRefresh()
                end)
            end
            
            local sliderValue = CreateInstance("TextLabel", {
                Size = UDim2.new(0.3, 0, 1, 0),
                Position = UDim2.new(0.7, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(sliderDefault),
                TextColor3 = window.Theme.Accent,
                TextSize = 14,
                Font = Config.FontBold,
                TextXAlignment = Enum.TextXAlignment.Right
            })
            sliderValue.Parent = sliderHeader
            
            local sliderBar = CreateInstance("Frame", {
                Size = UDim2.new(1, -40, 0, 6),
                Position = UDim2.new(0, 20, 0, 45),
                BackgroundColor3 = window.Theme.Border
            })
            sliderBar.Parent = sliderFrame
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(1, 0)
            }, sliderBar)
            
            local sliderFill = CreateInstance("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = window.Theme.Accent
            })
            sliderFill.Parent = sliderBar
            
            CreateInstance("UICorner", {
                CornerRadius = UDim.new(1, 0)
            }, sliderFill)
            
            local dragging = false
            local currentValue = sliderDefault
            
            local function updateSlider(value)
                value = math.clamp(value, sliderMin, sliderMax)
                value = math.floor(value / sliderIncrement) * sliderIncrement
                currentValue = value
                
                local percentage = (value - sliderMin) / (sliderMax - sliderMin)
                CreateTween(sliderFill, {Size = UDim2.new(percentage, 0, 1, 0)}, 0.1)
                sliderValue.Text = tostring(value)
                
                pcall(function()
                    sliderCallback(value)
                end)
            end
            
            sliderBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    local connection
                    connection = RunService.RenderStepped:Connect(function()
                        if dragging then
                            local mouse = LocalPlayer:GetMouse()
                            local percentage = math.clamp((mouse.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
                            local value = sliderMin + (sliderMax - sliderMin) * percentage
                            updateSlider(value)
                        else
                            connection:Disconnect()
                        end
                    end)
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)
            
            updateSlider(sliderDefault)
            
            local element = {
                Name = sliderName,
                SetValue = function(value)
                    updateSlider(value)
                end,
                GetValue = function()
                    return currentValue
                end,
                Refresh = function()
                    if sliderRefresh then
                        sliderRefresh()
                    end
                end
            }
            
            table.insert(tab.Elements, element)
            table.insert(window.Elements, element)
            return element
        end
        
        table.insert(window.Tabs, tab)
        tab.Button = tabButton
        tab.Content = tabContent
        
        -- Auto-select first tab
        if #window.Tabs == 1 then
            window:SelectTab(tab)
        end
        
        return tab
    end
    
    -- Tab Selection Function
    function window:SelectTab(tab)
        for _, t in pairs(window.Tabs) do
            if t.Content then
                t.Content.Visible = false
            end
            if t.Button then
                CreateTween(t.Button, {BackgroundTransparency = 1}, 0.3)
                local label = t.Button:FindFirstChild("TabLabel")
                if label then
                    CreateTween(label, {TextColor3 = window.Theme.TextDim}, 0.3)
                end
            end
        end
        
        if tab.Content then
            tab.Content.Visible = true
        end
        if tab.Button then
            CreateTween(tab.Button, {BackgroundTransparency = 0.8, BackgroundColor3 = window.Theme.Accent}, 0.3)
            local label = tab.Button:FindFirstChild("TabLabel")
            if label then
                CreateTween(label, {TextColor3 = window.Theme.Text}, 0.3)
            end
        end
        
        window.ActiveTab = tab
    end
    
    -- Universal Refresh Function for All Elements
    function window:RefreshAllElements()
        for _, element in pairs(window.Elements) do
            if element.Refresh then
                pcall(function()
                    element.Refresh()
                end)
            end
        end
    end
    
    -- Toggle Off All Toggles
    function window:ToggleOffAll()
        for _, element in pairs(window.Elements) do
            if element.ToggleOff then
                pcall(function()
                    element.ToggleOff()
                end)
            end
        end
    end
    
    -- Clear All Multi-Selects
    function window:ClearAllMultiSelects()
        for _, element in pairs(window.Elements) do
            if element.Clear and element.GetOptions then
                pcall(function()
                    element.Clear()
                end)
            end
        end
    end
    
    -- Toggle UI Visibility
    local isVisible = true
    local toggleConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == GlobalSettings.ToggleKey and not gameProcessed then
            isVisible = not isVisible
            mainFrame.Visible = isVisible
            
            if isVisible then
                CreateTween(mainFrame, {Position = UDim2.new(0.5, -windowSize.X.Offset/2, 0.5, -windowSize.Y.Offset/2)}, 0.5, Enum.EasingStyle.Back)
            end
        end
    end)
    
    -- Store connection for cleanup
    if getgenv then
        table.insert(getgenv().VoidXConnections, toggleConnection)
    end
    
    -- Destroy function
    function window:Destroy()
        screenGui:Destroy()
        if getgenv then
            for _, connection in pairs(getgenv().VoidXConnections) do
                if connection and connection.Disconnect then
                    connection:Disconnect()
                end
            end
            getgenv().VoidXConnections = {}
        end
    end
    
    return window
end

return VoidX
