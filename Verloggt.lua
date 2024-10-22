-- TODO: 
-- add all important spells
-- color code spells in outop
-- check if encounter is mythic
-- cleanup/fix output window
-- check mrt timers
-- spellnames instead of ids if it costs less performance
-- scroll bar should only appear if content is too large
-- first spell will never be recorded but shouldn't matter i guess lg
-- ui for all settings
SLASH_VERLOGGT1 = "/verloggt"

-- 51505 lava burst, 188196 lightning bolt, 98008 Spirit Link, 114052 Ascendance, 108280 Healing Tide
-- 51052 AMZ, 97462 rally, 3182 AM, 414660 mass barrier, 196718 darkness, 77764 roar, 192077 windrush
-- 363534 rewind, 374968 time spiral
local spellsToLookFor = {
    98008, 114052, 108280, 51052, 97462, 3182, 414660, 196718, 77764, 192077,
    363534, 374968
}
local recordedSpells = {}

local frame = CreateFrame("Frame")
local combatStartTime
local inCombat = false

local onMessage = "Verloggt is turned on!"
local offMessage = "Verloggt is turned off!"
local bossEncouters = "Logging only Boss Encounters!"
local allEncouters = "Logging all Encounters!"
local slashStatus = "status"
local slashBoss = "boss"
VerloggtSettings = VerloggtSettings or {}

local function StatusReply()
    if VerloggtSettings.isOn then
        return onMessage
    else
        return offMessage
    end
end

local function BossEncounterReply()
    if VerloggtSettings.onlyBossEncounters then
        return bossEncouters
    else
        return allEncouters
    end
end

local function slashCmdReply()
    print(StatusReply() .. " " .. BossEncounterReply())
end

SlashCmdList["VERLOGGT"] = function(msg)
    if msg == slashStatus then
        slashCmdReply()
        return
    elseif msg == slashBoss then
        VerloggtSettings.onlyBossEncounters =
            not VerloggtSettings.onlyBossEncounters
    else
        VerloggtSettings.isOn = not VerloggtSettings.isOn
    end
    slashCmdReply()
end

function GetSettings() return VerloggtSettings end

local messageFrame = CreateFrame("ScrollingMessageFrame", "MyMessageFrame",
                                 UIParent, "BasicFrameTemplateWithInset")
messageFrame:SetSize(300, 200)
messageFrame:SetPoint("TOP")
messageFrame:SetJustifyH("LEFT")
messageFrame:SetFading(false)
messageFrame:SetMaxLines(10)
messageFrame:Clear()
messageFrame:SetInsertMode("TOP")
messageFrame:Hide()

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
messageFrame:SetScript("OnDragStart",
                       function(self, button) self:StartMoving() end)
messageFrame:SetScript("OnDragStop",
                       function(self) self:StopMovingOrSizing() end)
messageFrame.CloseButton:SetScript("OnClick", function()
    messageFrame:Hide()
    messageFrame:Clear()
end)

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
    messageList:SetHeight(height)
    local frameHeight = math.min(height, 200)
    scrollFrame:SetSize(300, frameHeight)
    messageFrame:SetSize(300, frameHeight + 40)
end

local function UpdateTime() if inCombat then currentTime = time() end end

local function StartCombatTimer() combatStartTime = time() end

function FormatSeconds(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function GetCombatTimeStamp(timestamp)
    if combatStartTime ~= nil and timestamp ~= nil then
        return FormatSeconds(difftime(timestamp, combatStartTime))
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
    if messageFrame:IsVisible() then return end
    local messages = {}
    for _, spell in ipairs(recordedSpells) do
        table.insert(messages, spell.timestamp .. " - " .. spell.spellID ..
                         " - " .. spell.source .. "\n")
    end
    updateMessageList(messages)
    messageFrame:Show()
end

local function IsBossEncounter()
    if C_Scenario.GetInfo() then
        return true
    else
        return false
    end
end

local function InitiateCombatLog()
    if not inCombat then StartCombatTimer() end
    inCombat = true
    UpdateTime()
end

local function CombatShouldBeLogged()
    local isBossEncounter = IsBossEncounter()
    return (VerloggtSettings.onlyBossEncounters and isBossEncounter) or
               not VerloggtSettings.onlyBossEncounters
end

local function CombatTimeHandler(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        if CombatShouldBeLogged then InitiateCombatLog() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if inCombat then
            inCombat = false
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

    -- timestamps might be off if combat log timestamps are from server and not pc
    if subEvent == "SPELL_CAST_SUCCESS" then
        UpdateTime()
        if contains(spellsToLookFor, spellID) then
            local spellToSave = SaveSpell(spellName, GetCombatTimeStamp(
                                              tonumber(timestamp)), sourceName)
            table.insert(recordedSpells, spellToSave)
        end

    end
end

local function AddonLoadHandler()
    message("Verloggt loaded..")
    if VerloggtSettings.isOn == nil then VerloggtSettings.isOn = true end
    if VerloggtSettings.onlyBossEncounters == nil then
        VerloggtSettings.onlyBossEncounters = true
    end
end

local function EventHandler(self, event, ...)
    if event == "ADDON_LOADED" then AddonLoadHandler() end

    -- do nothing if turned off
    if not VerloggtSettings.isOn then return end

    if event == "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED" then
        CombatTimeHandler(self, event, ...)
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" and inCombat then
        CombatLogHandler(self, event, ...)
    end
end

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", EventHandler)
