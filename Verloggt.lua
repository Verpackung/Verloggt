-- TODO: 
-- add all important spells
-- color code spells in outop
-- check if encounter is mythic
-- cleanup/fix output window
-- savable variables to enable/disable with cmd
-- check mrt timers
-- maybe use something better for combat time
-- spellnames instead of ids if it costs less performance
-- scroll bar should only appear if content is too large
SLASH_VERLOGGT1 = "/verloggt"

-- 51505 lava burst, 188196 lightning bolt
local spellsToLookFor = {51505, 188196}
local recordedSpells = {}

local frame = CreateFrame("Frame")
local currentTime
local combatStartTime
local inCombat = false
VerloggtSettings = VerloggtSettings or {}

local onMessage = "Verloggt is turned on!"
local offMessage = "Verloggt is turned off!"

local function printOnStatus()
    if VerloggtSettings.isOn then
        print(onMessage)
    else
        print(offMessage)
    end

end

SlashCmdList["VERLOGGT"] = function(msg)
    print(msg)
    if msg == "status" then
        printOnStatus()
        return
    else
        VerloggtSettings.isOn = not VerloggtSettings.isOn
    end
    printOnStatus()

end

function GetSettings() return VerloggtSettings end

-- Create a new frame
local messageFrame = CreateFrame("ScrollingMessageFrame", "MyMessageFrame",
                                 UIParent, "BasicFrameTemplateWithInset")

-- Set the size and position
messageFrame:SetSize(300, 200)
messageFrame:SetPoint("TOP")

-- Set properties for scrolling
messageFrame:SetJustifyH("LEFT")
messageFrame:SetFading(false) -- Set to true if you want fading effects
messageFrame:SetMaxLines(10) -- Maximum number of lines to display
messageFrame:Clear() -- Clear any existing messages
messageFrame:SetInsertMode("TOP") --
messageFrame:Hide()

-- Scroll Frame
local scrollFrame = CreateFrame("ScrollFrame", nil, messageFrame,
                                "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(300, 160)
scrollFrame:SetPoint("TOPLEFT", 10, -30)

local messageList = CreateFrame("Frame", nil, scrollFrame)
messageList:SetSize(300, 160)
scrollFrame:SetScrollChild(messageList)

messageFrame:SetMovable(true)
messageFrame:EnableMouse(true)
messageFrame:RegisterForDrag("LeftButton")
messageFrame:SetScript("OnDragStart", function(self, button)
    self:StartMoving()
    print("OnDragStart", button)
end)
messageFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    print("OnDragStop")
end)

messageFrame.CloseButton:SetScript("OnClick", function() messageFrame:Hide() end)

-- Function to update the message list
local function updateMessageList(messages)
    local height = 0
    for i, msg in ipairs(messages) do
        local messageText = messageList[i] or
                                messageList:CreateFontString(nil, "OVERLAY",
                                                             "GameFontNormal")
        messageText:SetPoint("TOP", messageList, "TOP", 0, -20 * (i - 1))
        messageText:SetText(msg)
        messageList[i] = messageText
        height = height + 20 -- Increment height for each message
    end
    messageList:SetHeight(height) -- Set the height of the message list frame
    local frameHeight = math.min(height, 200)
    scrollFrame:SetSize(300, frameHeight)
    messageFrame:SetSize(300, frameHeight + 40)
end

local function UpdateTime() if inCombat then currentTime = time() end end

local function StartCombatTimer()
    messageFrame:Hide()
    messageFrame:Clear()
    combatStartTime = time()
    print("combat started " .. combatStartTime)
end

function FormatSeconds(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60

    -- Format minutes and seconds to always be two digits
    return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function GetCombatTimeStamp()
    if combatStartTime ~= nil and currentTime ~= nil then
        return FormatSeconds(difftime(currentTime, combatStartTime))
    elseif combatStartTime == nil then
        print("start time nil")
    elseif currentTime == nil then
        print("current time nil")
    end
end

local function SaveSpell(spellID, timestamp, source)
    return {spellID = spellID, timestamp = timestamp, source = source}
end

local function contains(list, spellID)
    for _, value in ipairs(list) do if value == spellID then return true end end
    return false
end

local function PrintResult()
    print(recordedSpells)
    local messages = {}
    for _, spell in ipairs(recordedSpells) do
        table.insert(messages, spell.timestamp .. " - " .. spell.spellID ..
                         " - " .. spell.source .. "\n")
    end
    updateMessageList(messages)
    messageFrame:Show()

end

local function CombatTimeHandler(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        if not inCombat then StartCombatTimer() end
        inCombat = true
        UpdateTime()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if inCombat then
            inCombat = false
            print("combat timer stopped ")
            combatStartTime = nil
            PrintResult()
            recordedSpells = {}
        end
    end
end

local function CombatLogHandler(self, event, ...)
    local timestamp, subEvent, _, sourceGUID, sourceName, _, _, destGUID,
          destName, _, _, spellID, spellName, spellSchool =
        CombatLogGetCurrentEventInfo()

    -- test if i can just use timestamp here
    if subEvent == "SPELL_CAST_SUCCESS" then
        UpdateTime()
        if contains(spellsToLookFor, spellID) then
            table.insert(recordedSpells,
                         SaveSpell(spellName, GetCombatTimeStamp(), sourceName))
        end

    end

end

local function EventHandler(self, event, ...)
    if event == "ADDON_LOADED" then
        message("Verloggt loaded..")
        if VerloggtSettings.isOn == nil then VerloggtSettings.isOn = true end
    end

    -- do nothing if turned off
    if not VerloggtSettings.isOn then return end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        CombatLogHandler(self, "COMBAT_LOG_EVENT_UNFILTERED", ...)
    end
    if event == "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED" then
        CombatTimeHandler(self, event, ...)
    end
end

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", EventHandler)

