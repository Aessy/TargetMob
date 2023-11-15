local TargetUnit, UnitName = TargetUnit, UnitName

local fmt, tinsert, tremove, mmax = string.format, table.insert, table.remove,
                                    math.max

local SetRaidTarget, GetRaidTargetIndex = SetRaidTarget, GetRaidTargetIndex


TargetMobTracker= {}
TargetMobTracker.__index = TargetMobTracker

local targetting = {
    timeout = 0.25,
    time = 0,

    scan_timeout = 5,

    scan_data = {},

    scanned_data = {}, -- Contains current mobs that are scanned and exists within scan timeout
    last_match = 0

}

local mobIcons = {
    "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8.blp", -- Skull
    "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp", -- Cross
    "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6.blp" -- Square
}

local actionForbiddenText = fmt(ADDON_ACTION_FORBIDDEN, "TargetMob")

local TextBoxHook = function(self)
    if self.text:GetText() == actionForbiddenText then
        if self:IsShown() then self:Hide() end
        local _, channel = PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        if channel then
            StopSound(channel)
            StopSound(channel - 1)
        end
        StaticPopupDialogs["ADDON_ACTION_FORBIDDEN"] = nil
    end
end

_G.StaticPopup1:HookScript("OnShow", TextBoxHook)
_G.StaticPopup1:HookScript("OnHide", TextBoxHook)
_G.StaticPopup2:HookScript("OnShow", TextBoxHook)
_G.StaticPopup2:HookScript("OnHide", TextBoxHook)

--local scan_list = {"Ragged Young Wolf", "Ragged Timber Wolf", "Burly Rockjaw Trogg", "Rockjaw Trogg"}
--local scan_list = {"Ashenvale Outrunner", "Rotting Slime"} 
local scan_list = {"Ghostpaw Howler", "Wildthorn Venomspitter", "Foulweald Totemic", "Foulweald Warrior", "Foulweald Shaman"}

function TargetMobTracker:UpdateTargetFrame()
    enemy_buttons = self.frame.enemy_buttons

    local i = 0
    for name, d in pairs(targetting.scanned_data) do
        i = i + 1

        btn = self.frame.enemy_buttons[i]
        btn:SetText(name)
        btn:Show()
        btn:SetAttribute('macrotext',
                         '/cleartarget\n/targetexact ' .. name)
        
    end
    for j=i+1,10 do
        btn = self.frame.enemy_buttons[j]
        btn:Hide()
    end
end

function UpdateMarker(kind, unit_id, index)
    if GetRaidTargetIndex("target") == nil then
        SetRaidTarget("target", 5)
    end
end

function TargetMobTracker:PlayerTargetChanged(event)

    local kind = "target"
    local unit_name = UnitName(kind)

    for i, name in ipairs(scan_list) do
        if name == unit_name then
            self:UpdateTargetFrame()
            UpdateMarker("mob", kind, i)
        end
    end

end

function TargetMobTracker:actionForbidden(forbidden_addon, func)
    if func ~= "TargetUnit()" or forbidden_addon ~= "TargetMob" then return end

    local name = targetting.scan_data.name

    local now = GetTime()
    targetting.last_match = now
    targetting.scanned_data[name] = {
        kind = 'mob',
        last_match = now
    }

    self:UpdateTargetFrame()
end

function TargetMobTracker:OnEvent(event, ...)
    if event == "ADDON_ACTION_FORBIDDEN" then
        self:actionForbidden(...)
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:PlayerTargetChanged(...)
    end
end

function TargetMobTracker:OnUpdate(elapsed)
    targetting.time = targetting.time + elapsed

    if targetting.time < targetting.timeout then
        return
    end

    targetting.time = 0

    for i, name in ipairs(scan_list) do
        targetting.scan_data = {name = name}
        TargetUnit(name, true)
    end

    local now = GetTime()
    if targetting.last_match + targetting.scan_timeout < now then
        wipe(targetting.scanned_data)
    end


    for name, data in pairs(targetting.scanned_data) do
        if data.last_match + targetting.timeout < now then
            targetting.scanned_data[name] = nil
        end
    end

    for name, data in pairs(targetting.scanned_data) do
    end
end

function TargetMobTracker:Create()
    local tracker = {}
    setmetatable(tracker, TargetMobTracker)

    tracker.frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tracker.frame:SetSize(140, 200)
    tracker.frame:SetPoint("CENTER", UIParent)

    tracker.frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tile = true, tileSize = 16,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 5,
        insets = { left = 2, right = 2, top = 2, bottom = 2, },
    })
    tracker.frame:SetBackdropColor(0, 0, 1, 0.8)

    tracker.frame:SetMovable(true)
    tracker.frame:EnableMouse(true)
    tracker.frame:RegisterForDrag("LeftButton")
    tracker.frame:SetScript("OnDragStart", function(self, button)
        tracker.frame:StartMoving()
    end)
    tracker.frame:SetScript("OnDragStop", function(self, button)
        tracker.frame:StopMovingOrSizing()
    end)

    tracker.frame.enemy_buttons = {}

    local last = nil
    for i=1,10 do
        btn = CreateFrame("Button", "MyButton" .. i,
                tracker.frame, "SecureActionButtonTemplate")

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", tracker.frame, "TOPLEFT", 0, (i-1)*-20)
        btn:SetAttribute('type', 'macro')
        btn:RegisterForClicks("AnyDown")
        btn:SetText("TEST" ..i)
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Up")
        btn:SetHighlightTexture("Interface/Buttons/UI-Panel-Button-Highlight")
        btn:SetPushedTexture("Interface/Buttons/UI-Panel-Button-Down")
        btn:SetSize(180, 25)
        btn:Hide()
        --btn:SetAttribute('macrotext',
        --                  '/say yoyo')
        tinsert(tracker.frame.enemy_buttons, btn)
    end
    return tracker
end

local current_window = TargetMobTracker:Create()

local event_handler = CreateFrame("Frame")

event_handler:RegisterEvent("PLAYER_TARGET_CHANGED")
event_handler:RegisterEvent("ADDON_ACTION_FORBIDDEN")
event_handler:SetScript("OnEvent", function(frame, event, ...)
    current_window:OnEvent(event, ...)
end)
event_handler:SetScript("OnUpdate", function(self, elapsed)
    current_window:OnUpdate(elapsed)
end)