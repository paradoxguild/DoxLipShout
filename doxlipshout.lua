local SHARED_POTION_COOLDOWNS = {
    "Greater Stoneshield", "Stoneshield", "Invulnerability", "Arcane Protection", "Fire Protection", "Frost Protection", "Holy Protection", "Nature Protection",
    "Shadow Protection", "Mighty Rage", "Great Rage", "Rage", "Healing Potion", "Rejuvenation Potion", "Wildvine Potion", "Free Action", "Resistance", "Speed"
    -- TODO: Living Action Potion, Invisibility, Dreamless sleep potion, Jungle remedy, Restorative Potion
};
local POTION_CD = (60 * 2);
local SHOUT_CD = (60 * 10);

local dragging = false;
local debug = false;
local hideIfTimers = true;
local showTimerWhenNear = true;

-- potionTimers = {};
-- shoutTimers = {};

local function makeMovable(frame, trackFrameData)
    -- frame:SetUserPlaced(true);
    frame:EnableMouse(true);
    frame:SetMovable(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetScript("OnDragStart", function(self)
        if trackFrameData then
            dragging = true;
        end
        self:StartMoving();
    end);
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        if trackFrameData then
            frameData = {
                ["x"] = frame:GetLeft(),
                ["y"] = frame:GetBottom()
            };
            dragging = false;
        end
    end);
end

local msgFrame = CreateFrame("Frame", "LIPSHOUT-FRAME", UIParent, "BackdropTemplate");
msgFrame:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
});
msgFrame:SetBackdropColor(0, 0, 0, 0.6);
msgFrame:SetFrameStrata("MEDIUM");
msgFrame:SetClampedToScreen(true);
makeMovable(msgFrame, true);
msgFrame.text = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
msgFrame.text:SetPoint("CENTER", msgFrame);
msgFrame.text:SetText("");
msgFrame.text:SetJustifyH("LEFT");
msgFrame:Show();
msgFrame:ClearAllPoints();
msgFrame:SetPoint("CENTER", 0, 0);

local loadFrame = CreateFrame("Frame");
loadFrame:RegisterEvent("ADDON_LOADED");
loadFrame:SetScript("OnEvent", function()
    print("DoxLipShout Load..");
    if not frameData or next(frameData) == nil then
        print("DoxLipShout Set Initial Position");
        frameData = {
            ["x"] = msgFrame:GetLeft() or 0,
            ["y"] = msgFrame:GetBottom() or 0
        };
    end
    print("DoxLipShout Loaded");
end);

local function hasValue(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function getUnitName(unitName, unitRealm)
    if unitRealm ~= nil then
        return unitName .. "-" .. unitRealm;
    else
        return unitName;
    end
end

local function isWarrior(unit)
    localizedClass, englishClass, classIndex = UnitClass(unit);
    return englishClass == "WARRIOR";
end

local function getInstanceFriendlyUnits()
    units = {};
    unitCount = 0;
    if debug then
        unitCount = unitCount + 2;
        table.insert(units, "Adebug");
        table.insert(units, "Zdebug");
    end
    if UnitExists("player") and isWarrior("player") then
        unitName, unitRealm = UnitName("player");
        unitCount = unitCount + 1;
        table.insert(units, getUnitName(unitName, unitRealm));
    end
    for i = 1, 5 do
        local unit = format("%s%i", 'party', i);
        if UnitExists(unit) and isWarrior(unit) then
            unitName, unitRealm = UnitName(unit);
            unitCount = unitCount + 1;
            table.insert(units, getUnitName(unitName, unitRealm));
        end
    end
    for i = 1, 40 do
        local unit = format("%s%i", 'raid', i);
        if UnitExists(unit) and isWarrior(unit) then
            unitName, unitRealm = UnitName(unit);
            unitCount = unitCount + 1;
            table.insert(units, getUnitName(unitName, unitRealm));
        end
    end
    if unitCount == 0 then
        msgFrame:Hide();
    else
        msgFrame:Show();
    end
    return units;
end

local function colorText(text, color)
    return "\124c" .. color .. text .. "\124r";
end

local function getDisplayName(fullName)
    if string.find(fullName, "-") ~= nil then
        return string.sub(fullName, 1, string.find(fullName, "-") - 1);
    end
    return fullName;
end

local function buildText()
    output = "";
    keys = {};
    for key, _ in pairs(potionTimers) do
        table.insert(keys, key);
    end
    table.sort(keys);

    for _, key in ipairs(keys) do
        value = potionTimers[key];
        if value ~= nil then
            displayKey = getDisplayName(key);
            showEntry = true;
            potionNear = false;
            shoutNear = false;
            duration = value["time"] ~= nil and math.floor(GetTime() - value["time"] + 0.5) or POTION_CD;
            potionCDText = duration < POTION_CD and colorText("N " .. (POTION_CD - duration) .. "s", "FFFF0000") or colorText("Y", "FF008000");
            shoutCDText = colorText("Y", "FF008000");
            if POTION_CD - duration < 30 then
                potionNear = true;
            end
            if duration < POTION_CD then
                showEntry = false;
            end
            if shoutTimers[key] ~= nil then
                shoutDuration = shoutTimers[key]["time"] ~= nil and math.floor(GetTime() - shoutTimers[key]["time"]) or SHOUT_CD;
                
                if SHOUT_CD - shoutDuration < 30 then
                    shoutNear = true;
                end
                if shoutDuration < SHOUT_CD then
                    showEntry = false;
                    shoutCDText = colorText("N " .. (SHOUT_CD - shoutDuration) .. "s", "FFFF0000");
                end
            end
            if not hideIfTimers or showEntry or (showTimerWhenNear and potionNear and shoutNear) then
                if string.len(output) > 0 then
                    output = output .. "\n";
                end
                output = output .. displayKey .. ": Potion " .. potionCDText .. " | Shout " .. shoutCDText;
            end
        end
    end
    
    return output;
end

local function populateTimerPlaceholders()
    -- Populate units
    for _, unitKey in ipairs(friendlyUnits) do
        if potionTimers == nil then
            potionTimers = {};
        end

        if shoutTimers == nil then
            shoutTimers = {};
        end

        if potionTimers[unitKey] == nil then
            unitData = {};
            unitData["time"] = nil;
            potionTimers[unitKey] = unitData;
        end

        if shoutTimers[unitKey] == nil then
            shoutData = {};
            shoutData["time"] = nil;
            shoutTimers[unitKey] = shoutData;
        end
    end
    -- Remove old units
    if not debug then
        for unitKey, _ in pairs(potionTimers) do
            if not hasValue(friendlyUnits, unitKey) then
                potionTimers[unitKey] = nil;
            end
        end
        for unitKey, _ in pairs(shoutTimers) do
            if not hasValue(friendlyUnits, unitKey) then
                shoutTimers[unitKey] = nil;
            end
        end
    end
end

local frame = CreateFrame("Frame");
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    unitName, unitRealm = UnitName(arg1);
    key = getUnitName(unitName, unitRealm);
    if hasValue(friendlyUnits, key) then
        spellName, rank, icon, castTime, minRange, maxRange = GetSpellInfo(arg3);
        spellId = arg3;
        guid = arg2;
        isPassiveEffect = string.len(guid) > 7 and string.sub(guid, 1, 7) == "Cast-4-"; -- type 4 can be seen https://wowpedia.fandom.com/wiki/GUID
        spellName = strtrim(spellName);

        if arg1 == "player" and debug then
            potionTimers[key]["time"] = GetTime();
            potionTimers["Adebug"]["time"] = GetTime() - 60;
            potionTimers["Zdebug"]["time"] = GetTime() + 10;
            print("'" .. spellName .. "'' used by " .. unitName .. " (ID=" .. tostring(spellId) .. ", GUID=" .. guid .. ") passive? -> " .. tostring(isPassiveEffect));
        end

        if hasValue(SHARED_POTION_COOLDOWNS, spellName) and isPassiveEffect then
            potionTimers[key]["time"] = GetTime();
        end

        if spellName == "Challenging Shout" then
            shoutTimers[key]["time"] = GetTime();
        end
    end
end);

C_Timer.NewTicker(1, function()
    friendlyUnits = getInstanceFriendlyUnits();

    populateTimerPlaceholders();

    text = buildText();
    
    if string.len(text) == 0 then
        msgFrame:Hide();
    else
        msgFrame.text:SetText(text);
        msgFrame:SetWidth(msgFrame.text:GetStringWidth() + 20);
        msgFrame:SetHeight(msgFrame.text:GetStringHeight() + 20);
        msgFrame:Show();
    end

    if frameData ~= nil and next(frameData) ~= nil and not dragging then
        msgFrame:ClearAllPoints();
        if frameData["x"] == 0 and frameData["y"] == 0 then
            msgFrame:SetPoint("Center", 0, 0);
        else
            msgFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", frameData["x"], frameData["y"]);
        end
    end
end)