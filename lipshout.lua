local SHARED_POTION_COOLDOWNS = {
    "Greater Stoneshield", "Stoneshield", "Invulnerability", "Arcane Protection", "Fire Protection", "Frost Protection", "Holy Protection", "Nature Protection",
    "Shadow Protection", "Mighty Rage", "Great Rage", "Rage", "Healing Potion", "Rejuvenation Potion", "Wildvine Potion", "Free Action", "Resistance"
};
local POTION_CD = (60 * 2);
local SHOUT_CD = (60 * 10);

local dragging = false;

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
msgFrame:SetPoint("CENTER", 0, 0);
msgFrame:SetFrameStrata("MEDIUM");
makeMovable(msgFrame, true);
msgFrame.text = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
msgFrame.text:SetPoint("CENTER", msgFrame);
msgFrame.text:SetText("");
msgFrame.text:SetJustifyH("LEFT");
msgFrame:Show();

local loadFrame = CreateFrame("Frame");
loadFrame:RegisterEvent("ADDON_LOADED");
loadFrame:SetScript("OnEvent", function()
    if not frameData then
        msgFrame:SetPoint("CENTER", 0, 0);
        frameData = {
            ["x"] = msgFrame:GetLeft(),
            ["y"] = msgFrame:GetBottom()
        };
    end
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
    if UnitExists("player") and isWarrior("player") then
        table.insert(units, "player");
    end
    for i = 1, 5 do
        local unit = format("%s%i", 'party', i);
        if UnitExists(unit) and isWarrior(unit) then
            table.insert(units, unit);
        end
    end
    for i = 1, 40 do
        local unit = format("%s%i", 'raid', i);
        if UnitExists(unit) and isWarrior(unit) then
            table.insert(units, unit);
        end
    end
    return units;
end

local function colorText(text, color)
    return "\124c" .. color .. text .. "\124r";
end

local function buildText()
    output = "";
    for key, value in pairs(potionTimers) do
        if string.len(output) > 0 then
            output = output .. "\n";
        end
        duration = value["time"] ~= nil and math.floor(GetTime() - value["time"] + 0.5) or POTION_CD;
        potionCDText = duration < POTION_CD and colorText("N " .. (POTION_CD - duration) .. "s", "FFFF0000") or colorText("Y", "FF008000");
        shoutCDText = colorText("Y", "FF008000");
        if shoutTimers[key] ~= nil then
            shoutDuration = shoutTimers[key]["time"] ~= nil and math.floor(GetTime() - shoutTimers[key]["time"]) or SHOUT_CD;
            if shoutDuration < SHOUT_CD then
                shoutCDText = colorText("N " .. (SHOUT_CD - shoutDuration) .. "s", "FFFF0000");
            end
        end
        output = output .. value["name"] .. ": Potion " .. potionCDText .. " | Shout " .. shoutCDText;
    end
    return output;
end

local function populateTimerPlaceholders()
    for _, value in ipairs(friendlyUnits) do
        unitName, unitRealm = UnitName(value);

        key = getUnitName(unitName, unitRealm);

        if not potionTimers[key] then
            unitData = {};
            unitData["name"] = unitName;
            unitData["time"] = nil;
            potionTimers[key] = unitData;
        end

        if not shoutTimers[key] then
            shoutData = {};
            shoutData["name"] = unitName;
            shoutData["time"] = nil;
            shoutTimers[key] = shoutData;
        end
    end
end

local frame = CreateFrame("Frame");
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if hasValue(friendlyUnits, arg1) then
        spellName, rank, icon, castTime, minRange, maxRange = GetSpellInfo(arg3);
        unitName, unitRealm = UnitName(arg1);
        spellId = arg3;
        guid = arg2;
        isPassiveEffect = string.len(guid) > 7 and string.sub(guid, 1, 7) == "Cast-4-"; -- type 4 can be seen https://wowpedia.fandom.com/wiki/GUID

        unitData = {};
        unitData["name"] = unitName;
        unitData["time"] = nil;
        if hasValue(SHARED_POTION_COOLDOWNS, spellName) and isPassiveEffect then
            unitData["time"] = GetTime();
        end

        shoutData = {};
        shoutData["name"] = unitName;
        shoutData["time"] = nil;
        if spellName == "Challenging Shout" then
            shoutData["time"] = GetTime();
        end

        potionTimers[getUnitName(unitName, unitRealm)] = unitData;
        shoutTimers[getUnitName(unitName, unitRealm)] = shoutData;
    end
end);

C_Timer.NewTicker(1, function()
    friendlyUnits = getInstanceFriendlyUnits();
    populateTimerPlaceholders();
    msgFrame.text:SetText(buildText());

    stringWidth = msgFrame.text:GetStringWidth() + 20;

    msgFrame:SetWidth(stringWidth);
    msgFrame:SetHeight(msgFrame.text:GetStringHeight() + 20);

    if frameData ~= nil and not dragging then
        msgFrame:ClearAllPoints();
        msgFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", frameData["x"], frameData["y"]);
    end
end)