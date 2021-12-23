--[[

  BindPad Addon for World of Warcraft

  Author: Tageshi

--]]

local NUM_MACRO_ICONS_SHOWN = 20;
local NUM_ICONS_PER_ROW = 5;
local NUM_ICON_ROWS = 4;
local MACRO_ICON_ROW_HEIGHT = 36;

-- Avoid taint of official lua codes.
local i, j, _;

-- Register BindPad frame to be controlled together with
-- other panels in standard UI.
UIPanelWindows["BindPadFrame"] = { area = "left", pushable = 8, whileDead = 1 };
UIPanelWindows["BindPadMacroFrame"] = { area = "left", pushable = 9, whileDead = 1 };

local BINDPAD_MAXSLOTS = 42;
local BINDPAD_TOTALSLOTS = BINDPAD_MAXSLOTS * 4;
local BINDPAD_MAXPROFILETAB = 12;
local BINDPAD_GENERAL_TAB = 1;
local BINDPAD_SAVEFILE_VERSION = 1.3;
local BINDPAD_PROFILE_VERSION252 = 252;

local TYPE_ITEM = "ITEM";
local TYPE_SPELL = "SPELL";
local TYPE_MACRO = "MACRO";
local TYPE_BPMACRO = "CLICK";

local BindPadPetAction = {
  [PET_ACTION_ATTACK] = SLASH_PET_ATTACK1,
  [PET_ACTION_FOLLOW] = SLASH_PET_FOLLOW1,
  [PET_ACTION_WAIT] = SLASH_PET_STAY1,
  [PET_MODE_AGGRESSIVE] = SLASH_PET_AGGRESSIVE1,
  [PET_MODE_DEFENSIVE] = SLASH_PET_DEFENSIVE1,
  [PET_MODE_PASSIVE] = SLASH_PET_PASSIVE1
};

-- Initialize the saved variable for BindPad.
BindPadVars = {
  tab = BINDPAD_GENERAL_TAB,
  version = BINDPAD_SAVEFILE_VERSION,
};

-- Initialize BindPad core object.
BindPadCore = {
  drag = {},
  dragswap = {},
  specInfoCache = {}
};
local BindPadCore = BindPadCore;

function BindPad_SlashCmd(msg)
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")

  if cmd == nil or cmd == "" then
      BindPadFrame_Toggle();
  elseif cmd == "list" then
      BindPadCore.DoList(arg);
  elseif cmd == "delete" then
      BindPadCore.DoDelete(arg);
  elseif cmd == "copyfrom" then
      BindPadCore.DoCopyFrom(arg);
  elseif cmd == "profile" or cmd == "pr" then
      BindPadCore.DoSetProfile(arg);
  else
      BindPadFrame_OutputText(BINDPAD_TEXT_USAGE);
  end
end

function BindPadFrame_OnLoad(self)
  PanelTemplates_SetNumTabs(BindPadFrame, 4);

  SlashCmdList["BINDPAD"] = BindPad_SlashCmd;

  SLASH_BINDPAD1 = "/bindpad";
  SLASH_BINDPAD2 = "/bp";

  self:RegisterEvent("UPDATE_BINDINGS");
  self:RegisterEvent("PLAYER_LOGIN");
  self:RegisterEvent("VARIABLES_LOADED");
  -- self:RegisterEvent("CVAR_UPDATE");
  self:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
  self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR");
  self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR");
  self:RegisterEvent("ACTIONBAR_PAGE_CHANGED");
end

function BindPadFrame_OnMouseDown(self, button)
  if button == "RightButton" then
    BindPadCore.ClearCursor();
  end
end

function BindPadFrame_OnEnter(self)
  BindPadCore.UpdateCursor();
end

function BindPadFrame_OnEvent(self, event, ...)
  local arg1, arg2 = ...;

  if event == "UPDATE_BINDINGS" then
    BindPadCore.DoSaveAllKeys();
    BindPadCore.UpdateAllHotkeys();
  elseif event == "ACTIONBAR_SLOT_CHANGED" then
    BindPadCore.UpdateHotKey(arg1);
  elseif event == "UPDATE_VEHICLE_ACTIONBAR" or event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" then
    BindPadCore.UpdateAllHotkeys();
  elseif event == "PLAYER_LOGIN" then
    BindPadCore.InitBindPad(event);
  elseif event == "VARIABLES_LOADED" then
    BindPadCore.InitBindPad(event);
  -- Not used on Ascension
  -- elseif event == "PLAYER_TALENT_UPDATE" then
  --   BindPadCore.PlayerTalentUpdate();
  -- Not used in 335a
  -- elseif event == "CVAR_UPDATE" then
  --   BindPadCore.CVAR_UPDATE(arg1, arg2);
  end
end

function BindPadFrame_OutputText(text)
  ChatFrame1:AddMessage("[BindPad] "..text, 1.0, 1.0, 0.0);
end

function BindPadFrame_Toggle()
  if BindPadFrame:IsVisible() then
    HideUIPanel(BindPadFrame);
  else
    ShowUIPanel(BindPadFrame);
  end
end

function BindPadFrame_OnShow()
  if nil == BindPadVars.tab then
    BindPadVars.tab = 1;
  end
  if GetCurrentBindingSet() == 1 then
    -- Don't show Character Specific Slots tab at first.
    BindPadVars.tab = 1;
  end

  if BindPadVars.tab == 1 then
    BindPadFrameTitleText:SetText(BINDPAD_TITLE);
  else
    BindPadFrameTitleText:SetText(_G["BINDPAD_TITLE_PROFILE"] .. " " .. BindPadCore.GetCurrentProfileNum());
  end

  PanelTemplates_SetTab(BindPadFrame, BindPadVars.tab);

  -- Update character button
  BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);

  -- Update Option buttons
  BindPadFrameSaveAllKeysButton:SetChecked(BindPadVars.saveAllKeysFlag);
  BindPadFrameShowKeyInTooltipButton:SetChecked(BindPadVars.showKeyInTooltipFlag);

  -- Update Trigger on Keydown button
  BindPadFrameTriggerOnKeydownButton:SetChecked(BindPadVars.triggerOnKeydown);

  -- Update profile tab
  for i = 1, BINDPAD_MAXPROFILETAB, 1 do
    local tab = _G["BindPadProfileTab"..i];
    tab:SetChecked((BindPadCore.GetCurrentProfileNum() == i));
    BindPadProfileTab_OnShow(tab);
  end

  for i = 1, BINDPAD_MAXSLOTS, 1 do
    local button = _G["BindPadSlot"..i];
    BindPadSlot_UpdateState(button);
  end
end

function BindPadFrame_OnHide(self)
  BindPadBindFrame:Hide();
  BindPadMacroPopupFrame:Hide();
  HideUIPanel(BindPadMacroFrame);
end

function BindPadFrameTab_OnClick(self)
  local id = self:GetID();
  local function f()
    if GetCurrentBindingSet() == 1 then
      local answer = BindPadCore.ShowDialog(BINDPAD_TEXT_CONFIRM_CHANGE_BINDING_PROFILE);
      if answer then
        LoadBindings(2);
        SaveBindings(2);
      else
        BindPadVars.tab = 1;
        return;
      end
    end
    BindPadVars.tab = id;
    BindPadFrame_OnShow();
  end

  -- Handles callback with coroutine.
  return coroutine.wrap(f)();
end

function BindPadFrameTab_OnEnter(self)
  local id = self:GetID();
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
  if id == 1 then
    GameTooltip:SetText(BINDPAD_TOOLTIP_TAB1, nil, nil, nil, nil, 1);
    GameTooltip:AddLine(BINDPAD_TOOLTIP_GENERAL_TAB_EXPLAIN, 1.0, 0.8, 0.8);
  else
    GameTooltip:SetText(format(_G["BINDPAD_TOOLTIP_TAB" .. id], UnitName("player")), nil, nil, nil, nil, 1);
    GameTooltip:AddLine(BINDPAD_TOOLTIP_SPECIFIC_TAB_EXPLAIN, 0.8, 1.0, 0.8);
  end
  GameTooltip:Show();
end

function BindPadBindFrame_Update()
  BindPadBindFrameAction:SetText(BindPadCore.selectedSlot.action);

  local key = GetBindingKey(BindPadCore.selectedSlot.action);
  if key then
    BindPadBindFrameKey:SetText(BINDPAD_TEXT_KEY..BindPadCore.GetBindingText(key, "KEY_"));
  else
    BindPadBindFrameKey:SetText(BINDPAD_TEXT_KEY..BINDPAD_TEXT_NOTBOUND);
  end
end

function BindPadBindFrame_OnKeyDown(self, keyOrButton)
  if keyOrButton=="ESCAPE" then
    BindPadBindFrame:Hide()
    return
  end

  if ( GetBindingFromClick(keyOrButton) == "SCREENSHOT" ) then
    RunBinding("SCREENSHOT");
    return;
  end

  local keyPressed = keyOrButton;

  if ( keyPressed == "UNKNOWN" ) then
    return;
  end

  -- Convert the mouse button names
  if ( keyPressed == "LeftButton" ) then
    keyPressed = "BUTTON1";
  elseif ( keyPressed == "RightButton" ) then
    keyPressed = "BUTTON2";
  elseif ( keyPressed == "MiddleButton" ) then
    keyPressed = "BUTTON3";
  elseif ( keyPressed == "Button4" ) then
    keyPressed = "BUTTON4"
  elseif ( keyOrButton == "Button5" ) then
    keyPressed = "BUTTON5"
  elseif ( keyPressed == "Button6" ) then
    keyPressed = "BUTTON6"
  elseif ( keyOrButton == "Button7" ) then
    keyPressed = "BUTTON7"
  elseif ( keyPressed == "Button8" ) then
    keyPressed = "BUTTON8"
  elseif ( keyOrButton == "Button9" ) then
    keyPressed = "BUTTON9"
  elseif ( keyPressed == "Button10" ) then
    keyPressed = "BUTTON10"
  elseif ( keyOrButton == "Button11" ) then
    keyPressed = "BUTTON11"
  elseif ( keyPressed == "Button12" ) then
    keyPressed = "BUTTON12"
  elseif ( keyOrButton == "Button13" ) then
    keyPressed = "BUTTON13"
  elseif ( keyPressed == "Button14" ) then
    keyPressed = "BUTTON14"
  elseif ( keyOrButton == "Button15" ) then
    keyPressed = "BUTTON15"
  elseif ( keyPressed == "Button16" ) then
    keyPressed = "BUTTON16"
  elseif ( keyOrButton == "Button17" ) then
    keyPressed = "BUTTON17"
  elseif ( keyPressed == "Button18" ) then
    keyPressed = "BUTTON18"
  elseif ( keyOrButton == "Button19" ) then
    keyPressed = "BUTTON19"
  elseif ( keyPressed == "Button20" ) then
    keyPressed = "BUTTON20"
  elseif ( keyOrButton == "Button21" ) then
    keyPressed = "BUTTON21"
  elseif ( keyPressed == "Button22" ) then
    keyPressed = "BUTTON22"
  elseif ( keyOrButton == "Button23" ) then
    keyPressed = "BUTTON23"
  elseif ( keyPressed == "Button24" ) then
    keyPressed = "BUTTON24"
  elseif ( keyOrButton == "Button25" ) then
    keyPressed = "BUTTON25"
  elseif ( keyPressed == "Button26" ) then
    keyPressed = "BUTTON26"
  elseif ( keyOrButton == "Button27" ) then
    keyPressed = "BUTTON27"
  elseif ( keyPressed == "Button28" ) then
    keyPressed = "BUTTON28"
  elseif ( keyOrButton == "Button29" ) then
    keyPressed = "BUTTON29"
  elseif ( keyPressed == "Button30" ) then
    keyPressed = "BUTTON30"
  elseif ( keyOrButton == "Button31" ) then
    keyPressed = "BUTTON31"
  end

  if ( keyPressed == "LSHIFT" or
       keyPressed == "RSHIFT" or
       keyPressed == "LCTRL" or
       keyPressed == "RCTRL" or
       keyPressed == "LALT" or
       keyPressed == "RALT" ) then
    return;
  end
  if ( IsShiftKeyDown() ) then
    keyPressed = "SHIFT-"..keyPressed
  end
  if ( IsControlKeyDown() ) then
    keyPressed = "CTRL-"..keyPressed
  end
  if ( IsAltKeyDown() ) then
    keyPressed = "ALT-"..keyPressed
  end
  if ( keyPressed == "BUTTON1" or keyPressed == "BUTTON2" ) then
    return;
  end
  if not keyPressed then return; end

  local function f()
    local answer;
    local padSlot = BindPadCore.selectedSlot;
    local oldAction = GetBindingAction(keyPressed)

    if oldAction ~= "" and oldAction ~= padSlot.action then
      local keyText = BindPadCore.GetBindingText(keyPressed, "KEY_");
      local text = format(BINDPAD_TEXT_CONFIRM_BINDING, keyText,
                          oldAction, keyText, padSlot.action);
      answer = BindPadCore.ShowDialog(text);
    else
      answer = true;
    end

    if answer then
      BindPadCore.BindKey(padSlot, keyPressed);
    end
    BindPadBindFrame_Update();
  end
  -- Handles callback with coroutine.
  return coroutine.wrap(f)();
end

function BindPadBindFrame_Unbind()
  BindPadCore.UnbindSlot(BindPadCore.selectedSlot);
  BindPadBindFrame_Update();
end

function BindPadBindFrame_OnHide(self)
  -- Close the confirmation dialog frame if it is still open.
  BindPadCore.CancelDialogs();
end

function BindPadSlot_OnUpdateBindings(self)
  if BindPadCore.character then
    BindPadSlot_UpdateState(self);
  end
end

function BindPadSlot_OnClick(self, button)
  if button == "RightButton" then
    if BindPadCore.CursorHasIcon() then
      BindPadCore.ClearCursor();
    else
      BindPadMacroFrame_Open(self);
    end
    return;
  end

  if BindPadCore.CursorHasIcon() then
    -- If cursor has icon to drop, drop it.
    BindPadSlot_OnReceiveDrag(self);
  elseif IsShiftKeyDown() then
    -- Shift+click to start drag.
    BindPadSlot_OnDragStart(self);
  else
    -- Otherwise open dialog window to set keybinding.
    if BindPadCore.GetSlotInfo(self:GetID()) then
      BindPadMacroPopupFrame:Hide();
      HideUIPanel(BindPadMacroFrame);
      BindPadCore.selectedSlot = BindPadCore.GetSlotInfo(self:GetID());
      BindPadCore.selectedSlotButton = self;
      BindPadBindFrame_Update();
      BindPadBindFrame:Show();
    end
  end
end

function BindPadSlot_OnDragStart(self)
  if not BindPadCore.CanPickupSlot(self) then
    return;
  end
  BindPadCore.PickupSlot(self, self:GetID(), true);
  BindPadSlot_UpdateState(self);
end

function BindPadSlot_OnReceiveDrag(self)
  if self == BindPadCore.selectedSlotButton then
    BindPadMacroPopupFrame:Hide();
    HideUIPanel(BindPadMacroFrame);
    BindPadBindFrame:Hide();
  end
  if not BindPadCore.CanPickupSlot(self) then
    return;
  end

  local type, detail, subdetail = GetCursorInfo();
  if type then
    if type == "petaction" then
      detail = BindPadCore.PickupSpellBookItem_slot;
      subdetail = BindPadCore.PickupSpellBookItem_bookType;
    end
    ClearCursor();
    ResetCursor();
    BindPadCore.PickupSlot(self, self:GetID());
    BindPadCore.PlaceIntoSlot(self:GetID(), type, detail, subdetail);

    BindPadSlot_UpdateState(self);
    BindPadSlot_OnEnter(self);
  elseif TYPE_BPMACRO == BindPadCore.drag.type then
    local drag = BindPadCore.drag;
    ClearCursor();
    ResetCursor();
    BindPadCore.PickupSlot(self, self:GetID());
    BindPadCore.PlaceVirtualIconIntoSlot(self:GetID(), drag);

    BindPadSlot_UpdateState(self);
    BindPadSlot_OnEnter(self);
  end
end

function BindPadSlot_OnEnter(self)
  BindPadCore.UpdateCursor();

  local padSlot = BindPadCore.GetSlotInfo(self:GetID());

  if padSlot == nil or padSlot.type == nil then
    return;
  end

  if BindPadCore.CheckCorruptedSlot(padSlot) then
    return;
  end

  GameTooltip:SetOwner(self, "ANCHOR_LEFT");

  if TYPE_ITEM == padSlot.type then
    GameTooltip:SetHyperlink(padSlot.linktext);
  elseif TYPE_SPELL == padSlot.type then
    if padSlot.spellid then
      GameTooltip:SetSpellByID(padSlot.spellid);
    else
      local spellBookId = BindPadCore.FindSpellBookIdByName(padSlot.name, padSlot.rank, padSlot.bookType);
      if spellBookId then
        GameTooltip:SetSpell(spellBookId, padSlot.bookType)
      else
        GameTooltip:SetText(BINDPAD_TOOLTIP_UNKNOWN_SPELL .. padSlot.name, 1.0, 1.0, 1.0);
      end
      if padSlot.rank then
        GameTooltip:AddLine(BINDPAD_TOOLTIP_DOWNRANK..padSlot.rank, 1.0, 0.7, 0.7);
      end
    end
  elseif TYPE_MACRO == padSlot.type then
    GameTooltip:SetText(BINDPAD_TOOLTIP_MACRO..padSlot.name, 1.0, 1.0, 1.0);
  elseif TYPE_BPMACRO == padSlot.type then
    GameTooltip:SetText(format(BINDPAD_TOOLTIP_BINDPADMACRO, padSlot.name), 1.0, 1.0, 1.0);
  end

  -- Spell or Item keybind is already shown if "Show Keys in Tooltip" option is ON.
  if not (BindPadVars.showKeyInTooltipFlag and (TYPE_ITEM == padSlot.type or TYPE_SPELL == padSlot.type)) then
    local key = GetBindingKey(padSlot.action);
    if key then
        GameTooltip:AddLine(BINDPAD_TOOLTIP_KEYBINDING .. BindPadCore.GetBindingText(key, "KEY_"), 0.8, 0.8, 1.0);
    end
  end

  if not BindPadCore.CursorHasIcon() then
    if TYPE_BPMACRO == padSlot.type then
      GameTooltip:AddLine(BINDPAD_TOOLTIP_CLICK_USAGE1, 0.8, 1.0, 0.8);
    else
      GameTooltip:AddLine(BINDPAD_TOOLTIP_CLICK_USAGE2, 0.8, 1.0, 0.8);
    end
  end

  GameTooltip:Show();
end

function BindPadSlot_UpdateState(self)
  local padSlot = BindPadCore.GetSlotInfo(self:GetID());

  local icon = _G[self:GetName().."Icon"];
  local name = _G[self:GetName().."Name"];
  local hotkey = _G[self:GetName().."HotKey"];
  local addbutton = _G[self:GetName().."AddButton"];
  local border = _G[self:GetName().."Border"];

  if padSlot and padSlot.type and padSlot.action then
    icon:SetTexture(padSlot.texture);
    icon:Show();
    addbutton:Hide();

    if name then
      name:SetText(padSlot.name);
    else
      name:SetText("");
    end

    local key = GetBindingKey(padSlot.action);
    if key then
      hotkey:SetText(BindPadCore.GetBindingText(key, "KEY_", 1));
    else
      hotkey:SetText("");
    end
    if TYPE_BPMACRO == padSlot.type then
      border:SetVertexColor(0, 1.0, 0, 0.35);
      border:Show();
    else
      border:Hide();
    end

  else
    icon:Hide();
    addbutton:Show();
    name:SetText("");
    hotkey:SetText("");
    border:Hide();
  end
end

local BindPadMacroPopup_oldPadSlot = {};
function BindPadMacroPopupFrame_Open(self)
  if InCombatLockdown() then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
    return;
  end
  local padSlot = BindPadCore.GetSlotInfo(self:GetID(), true);
  local newFlag = false;
  BindPadCore.CheckCorruptedSlot(padSlot);

  BindPadMacroPopup_oldPadSlot.action = padSlot.action;
  BindPadMacroPopup_oldPadSlot.id = padSlot.id;
  BindPadMacroPopup_oldPadSlot.macrotext = padSlot.macrotext;
  BindPadMacroPopup_oldPadSlot.name = padSlot.name;
  BindPadMacroPopup_oldPadSlot.texture = padSlot.texture;
  BindPadMacroPopup_oldPadSlot.type = padSlot.type;

  if nil == padSlot.type then
    newFlag = true;

    padSlot.type = TYPE_BPMACRO;
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, "1");
    padSlot.texture = GetMacroIconInfo(1);
    padSlot.macrotext = "";
    padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);
    BindPadSlot_UpdateState(self)
  end

  if TYPE_BPMACRO == padSlot.type then
    BindPadCore.selectedSlot = padSlot;
    BindPadCore.selectedSlotButton = self;

    BindPadMacroPopupEditBox:SetText(padSlot.name);
    BindPadMacroPopupFrame.selectedIconTexture = padSlot.texture;
    BindPadMacroPopupFrame.selectedIcon = nil;
    BindPadBindFrame:Hide();
    HideUIPanel(BindPadMacroFrame);
    BindPadMacroPopupFrame:Show();
    if newFlag then
      BindPadMacroPopupEditBox:HighlightText();
    end
  end
end

function BindPadMacroAddButton_OnClick(self)
  if BindPadCore.CursorHasIcon() then
    BindPadSlot_OnReceiveDrag(self);

  else
    HideUIPanel(BindPadMacroFrame);

    PlaySound("gsTitleOptionOK");
    BindPadMacroPopupFrame_Open(self);
  end
end

function BindPadMacroPopupFrame_OnShow(self)
  BindPadMacroPopupEditBox:SetFocus();
  BindPadMacroPopupFrame_Update(self);
  BindPadMacroPopupOkayButton_Update(self);
end

function BindPadMacroPopupFrame_OnHide(self)
  if not BindPadFrame:IsVisible() then
    ShowUIPanel(BindPadFrame);
  end
end

function BindPadMacroPopupFrame_Update(self)
  local numMacroIcons = GetNumMacroIcons();
  local macroPopupIcon, macroPopupButton;
  local macroPopupOffset = FauxScrollFrame_GetOffset(BindPadMacroPopupScrollFrame) or 0;
  local index;

  -- Icon list
  local texture;
  for i=1, NUM_MACRO_ICONS_SHOWN do
    macroPopupIcon = _G["BindPadMacroPopupButton"..i.."Icon"];
    macroPopupButton = _G["BindPadMacroPopupButton"..i];
    index = (macroPopupOffset * NUM_ICONS_PER_ROW) + i;
    texture = GetMacroIconInfo(index);
    if (index <= numMacroIcons and texture) then
      macroPopupIcon:SetTexture(texture);
      macroPopupButton:Show();
    else
      macroPopupIcon:SetTexture("");
      macroPopupButton:Hide();
    end
    if ( BindPadMacroPopupFrame.selectedIcon and (index == BindPadMacroPopupFrame.selectedIcon) ) then
      macroPopupButton:SetChecked(1);
    elseif ( BindPadMacroPopupFrame.selectedIconTexture ==  texture ) then
      macroPopupButton:SetChecked(1);
    else
      macroPopupButton:SetChecked(nil);
    end
  end

  -- Scrollbar stuff
  FauxScrollFrame_Update(BindPadMacroPopupScrollFrame, ceil(numMacroIcons / NUM_ICONS_PER_ROW) , NUM_ICON_ROWS, MACRO_ICON_ROW_HEIGHT );
end

function BindPadMacroPopupFrame_OnScroll(self, offset)
  FauxScrollFrame_OnVerticalScroll(self, offset, MACRO_ICON_ROW_HEIGHT, BindPadMacroPopupFrame_Update);
end

function BindPadMacroPopupEditBox_OnTextChanged(self)
  if InCombatLockdown() then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
    BindPadMacroPopupFrame:Hide();
    return;
  end

  local padSlot = BindPadCore.selectedSlot;
  BindPadCore.DeleteBindPadMacroID(padSlot);
  padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, self:GetText());
  if self:GetText() ~= padSlot.name then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_UNIQUENAME);
    self:SetText(padSlot.name);
  end
  BindPadCore.UpdateMacroText(padSlot);
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton)
end

function BindPadMacroPopupFrame_CancelEdit()
  local padSlot = BindPadCore.GetSlotInfo(BindPadCore.selectedSlotButton:GetID());
  if padSlot == nil then
    return;
  end

  BindPadMacroPopupFrame:Hide();

  if InCombatLockdown() then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
    return;
  end

  padSlot.action = BindPadMacroPopup_oldPadSlot.action;
  padSlot.id = BindPadMacroPopup_oldPadSlot.id;
  padSlot.macrotext = BindPadMacroPopup_oldPadSlot.macrotext;

  BindPadCore.DeleteBindPadMacroID(padSlot);
  padSlot.name = BindPadMacroPopup_oldPadSlot.name;
  BindPadCore.UpdateMacroText(padSlot);

  padSlot.texture = BindPadMacroPopup_oldPadSlot.texture;
  padSlot.type = BindPadMacroPopup_oldPadSlot.type;

  BindPadMacroPopupFrame.selectedIcon = nil;
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton)
end

function BindPadMacroPopupOkayButton_Update(self)
  if ( (strlen(BindPadMacroPopupEditBox:GetText()) > 0) and BindPadMacroPopupFrame.selectedIcon ) then
    BindPadMacroPopupOkayButton:Enable();
  else
    BindPadMacroPopupOkayButton:Disable();
  end
  if (strlen(BindPadMacroPopupEditBox:GetText()) > 0) then
    BindPadMacroPopupOkayButton:Enable();
  end
end

function BindPadMacroPopupButton_OnClick(self)
  BindPadMacroPopupFrame.selectedIcon = self:GetID() + (FauxScrollFrame_GetOffset(BindPadMacroPopupScrollFrame) * NUM_ICONS_PER_ROW);
  -- Clear out selected texture
  BindPadMacroPopupFrame.selectedIconTexture = nil;

  BindPadCore.selectedSlot.texture = GetMacroIconInfo(BindPadMacroPopupFrame.selectedIcon);
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);

  BindPadMacroPopupOkayButton_Update(self);
  BindPadMacroPopupFrame_Update(self);
end

function BindPadMacroPopupOkayButton_OnClick()
  BindPadMacroPopupFrame:Hide();
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
  BindPadMacroFrame_Open(BindPadCore.selectedSlotButton);
end

function BindPadMacroFrame_Open(self)
  HideUIPanel(BindPadMacroFrame);

  local id = self:GetID();
  local padSlot = BindPadCore.GetSlotInfo(id);

  if padSlot == nil or padSlot.type == nil then
    return;
  end

  BindPadCore.selectedSlot = padSlot;
  BindPadCore.selectedSlotButton = self;

  if TYPE_ITEM == padSlot.type or TYPE_SPELL == padSlot.type or TYPE_MACRO == padSlot.type then
    local function f()
      local answer = BindPadCore.ShowDialog(format(BINDPAD_TEXT_CONFIRM_CONVERT, padSlot.type, padSlot.name));
      if answer then BindPadCore.ConvertToBindPadMacro(); end
    end
    -- Handles callback with coroutine.
    return coroutine.wrap(f)();
  end

  BindPadMacroFrameSlotName:SetText(padSlot.name);
  BindPadMacroFrameSlotButtonIcon:SetTexture(padSlot.texture);
  BindPadMacroFrameText:SetText(padSlot.macrotext);
  if not InCombatLockdown() then
    BindPadMacroFrameTestButton:SetAttribute("macrotext", padSlot.macrotext);
  end

  BindPadBindFrame:Hide()
  BindPadMacroPopupFrame:Hide();
  ShowUIPanel(BindPadMacroFrame);
end

function BindPadMacroFrameEditButton_OnClick(self)
  BindPadMacroPopupFrame_Open(BindPadCore.selectedSlotButton);
end

function BindPadMacroDeleteButton_OnClick(self)
  HideUIPanel(self:GetParent());

  local padSlot = BindPadCore.GetSlotInfo(BindPadCore.selectedSlotButton:GetID());
  if padSlot == nil then
    return;
  end

  BindPadCore.DeleteBindPadMacroID(padSlot);

  table.wipe(padSlot);

  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
end

function BindPadMacroFrame_OnShow(self)
  BindPadMacroFrameText:SetFocus();
end

function BindPadMacroFrame_OnHide(self)
  if BindPadCore.selectedSlot.macrotext ~= BindPadMacroFrameText:GetText() then
    if InCombatLockdown() then
      BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
      BindPadMacroFrameText:SetText(BindPadCore.selectedSlot.macrotext);
    else
      BindPadCore.selectedSlot.macrotext = BindPadMacroFrameText:GetText();
      BindPadCore.UpdateMacroText(BindPadCore.selectedSlot);
    end
  end

  if not BindPadFrame:IsVisible() then
    ShowUIPanel(BindPadFrame);
  end
end

function BindPadProfileTab_OnShow(self)
  local normalTexture = self:GetNormalTexture();
  local texture = BindPadCore.GetSpecTexture(1);
  normalTexture:SetTexture(texture);

  if BindPadCore.GetCurrentProfileNum() == self:GetID() then
    self:SetChecked(1);
  end
end

function BindPadProfileTab_OnClick(self, button, down)
  if BindPadVars.tab == 1 and self:GetID() ~= BindPadCore.GetCurrentProfileNum() then
    BindPadFrameTab_OnClick(BindPadFrameTab2);
  end
  BindPadCore.SwitchProfile(self:GetID());
  BindPadFrame_OnShow();
  BindPadProfileTab_OnEnter(self);
end

function BindPadProfileTab_OnEnter(self, motion)
  local profileNum = self:GetID();
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
  GameTooltip:SetText(BINDPAD_TOOLTIP_EXTRA_PROFILE..profileNum);
  GameTooltip:Show();
end


--
-- BindPadCore:  A set of core functions
--

function BindPadCore.GetEquipmentSetTexture(setName)
  -- Replacement for buggy GetEquipmentSetInfoByName().
  local name, textureName;
  for idx = 1, GetNumEquipmentSets() do
    name, textureName = GetEquipmentSetInfo(idx);
    if name == setName then
      return textureName;
    end
  end
  return nil;
end

function BindPadCore.PlaceIntoSlot(id, type, detail, subdetail)
  local padSlot = BindPadCore.GetSlotInfo(id, true);

  if type == "item" then
    padSlot.type = TYPE_ITEM;
    padSlot.linktext = subdetail;
    local name,_,_,_,_,_,_,_,_,texture = GetItemInfo(padSlot.linktext);
    padSlot.name = name;
    padSlot.texture = texture;

  elseif type == "macro" then
    padSlot.type = TYPE_MACRO;
    local name, texture = GetMacroInfo(detail);
    padSlot.name = name;
    padSlot.texture = texture;

  elseif type == "spell" then
    padSlot.type = TYPE_SPELL;
    local spellName, spellRank = GetSpellName(detail, subdetail);
    local texture = GetSpellTexture(detail, subdetail);
    padSlot.bookType = subdetail;
    padSlot.name = spellName;
    if BindPadCore.IsHighestRank(detail, subdetail) then
      padSlot.rank = nil;
    else
      padSlot.rank = spellRank;
    end
    padSlot.texture = texture;

    elseif type == "petaction" then
      local spellName, spellRank = GetSpellBookItemName(detail, subdetail);
      local texture = GetSpellBookItemTexture(detail, subdetail);
      if BindPadPetAction[spellName] then
        padSlot.type = TYPE_BPMACRO;
        padSlot.bookType = nil;
        padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, BindPadPetAction[spellName]);
        padSlot.rank = nil;
        padSlot.texture = texture;
        padSlot.macrotext = BindPadPetAction[spellName];
      else
        padSlot.type = TYPE_SPELL;
        padSlot.bookType = subdetail;
        padSlot.name = spellName;
        padSlot.rank = nil;
        padSlot.texture = texture;
        padSlot.macrotext = nil;
      end

  elseif type == "merchant" then
    padSlot.type = TYPE_ITEM;
    padSlot.linktext = GetMerchantItemLink(detail);
    local name,_,_,_,_,_,_,_,_,texture = GetItemInfo(padSlot.linktext);
    padSlot.name = name;
    padSlot.texture = texture;

  elseif type == "companion" then
    padSlot.type = TYPE_BPMACRO;
    local creatureID, creatureName, creatureSpellID, texture = GetCompanionInfo(subdetail, detail);
    local spellName = GetSpellInfo(creatureSpellID);
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, spellName);
    padSlot.texture = texture;
    padSlot.macrotext = SLASH_CAST1 .. " " .. spellName;

  elseif type == "equipmentset" then
        padSlot.type = TYPE_BPMACRO;
    local textureName = BindPadCore.GetEquipmentSetTexture(detail);
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, detail);
    padSlot.texture = textureName;
    padSlot.type = TYPE_BPMACRO;
    padSlot.macrotext = SLASH_EQUIP_SET1 .. " " .. detail;

  else
    BindPadFrame_OutputText(format(BINDPAD_TEXT_CANNOT_PLACE, type));
    return;
  end

  padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);
  BindPadCore.UpdateMacroText(padSlot);
end

function BindPadCore.PlaceVirtualIconIntoSlot(id, drag)
  if TYPE_BPMACRO ~= drag.type then
    return;
  end

  local padSlot = BindPadCore.GetSlotInfo(id, true);

  padSlot.type = drag.type;
  padSlot.id = drag.id;
  padSlot.macrotext = drag.macrotext;
  padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, drag.name);
  padSlot.texture = drag.texture;
  padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);

  drag.type = nil;
  PlaySound("igAbilityIconDrop");
end

function BindPadCore.CheckCorruptedSlot(padSlot)
  if padSlot.type == TYPE_ITEM and
    padSlot.linktext and
    padSlot.name and
    padSlot.texture and
    padSlot.action then
    return false;
  end
  if padSlot.type == TYPE_MACRO and
    padSlot.name and
    padSlot.texture and
    padSlot.action then
    return false;
  end
  if padSlot.type == TYPE_SPELL and
    padSlot.bookType and
    padSlot.name and
    padSlot.texture and
    padSlot.action then
    return false;
  end
  if padSlot.type == TYPE_BPMACRO and
    padSlot.name and
    padSlot.texture and
    padSlot.macrotext and
    padSlot.action then
    return false;
  end

  table.wipe(padSlot);
  return true;
end

function BindPadCore.GetCurrentProfileNum()
  if nil == BindPadCore.profileNum then
    BindPadCore.profileNum = 1;
  end
  return BindPadCore.profileNum;
end

function BindPadCore.GetProfileData()
  local character = BindPadCore.character;
  if nil == character then
    return nil;
  end
  local profileNum = BindPadCore.GetCurrentProfileNum();
  local profile = BindPadVars[character][profileNum];

  return profile;
end

function BindPadCore.GetSlotInfo(id, newFlag)
  if id == nil then
    return nil;
  end
  local gid = id + ((BindPadVars.tab or 1) - 1) * BINDPAD_MAXSLOTS;
  return BindPadCore.GetAllSlotInfo(gid, newFlag);
end

function BindPadCore.GetAllSlotInfo(gid, newFlag)
  local padSlot;
  if nil == BindPadCore.character then
    BindPadFrame_OutputText("DEBUG: Something wrong.  Please report this message to the author of BindPad.");
    return nil;
  end
  if gid > BINDPAD_MAXSLOTS then
    local character = BindPadCore.character;
    local profileNum = BindPadCore.GetCurrentProfileNum();
    if nil == BindPadVars[character][profileNum] then
      BindPadVars[character][profileNum] = {};
    end
    local sid = gid - BINDPAD_MAXSLOTS;
    if nil == BindPadVars[character][profileNum][sid] then
      if newFlag then
        BindPadVars[character][profileNum][sid] = {};
      end
    else
      if not newFlag and BindPadVars[character][profileNum][sid].type == nil then
        BindPadVars[character][profileNum][sid] = nil;
      end
    end
    padSlot = BindPadVars[character][profileNum][sid];
  else
    if nil == BindPadVars[gid] then
      if newFlag then
        BindPadVars[gid] = {};
      end
    else
      if not newFlag and BindPadVars[gid].type == nil then
        BindPadVars[gid] = nil;
      end
    end
    padSlot = BindPadVars[gid];
  end
  return padSlot;
end

function BindPadCore.ConvertOldSlotInfo()
  local oldCharacter = GetRealmName().."_"..UnitName("player");
  local character = BindPadCore.character;

  local profileNum = BindPadCore.GetCurrentProfileNum();

  BindPadVars[character] = {};
  BindPadVars[character][profileNum] = {};

  if nil ~= BindPadVars[oldCharacter] then
    for i = 1, BINDPAD_MAXSLOTS do
      BindPadVars[character][profileNum][i] = BindPadVars[oldCharacter][i];
    end
    BindPadVars[oldCharacter] = nil;
  end
  if nil ~= BindPadVars[oldCharacter.."_3"] then
    for i = 1, BINDPAD_MAXSLOTS do
      BindPadVars[character][profileNum][i+BINDPAD_MAXSLOTS] = BindPadVars[oldCharacter.."_3"][i];
    end
    BindPadVars[oldCharacter.."_3"] = nil;
  end
  if nil ~= BindPadVars[oldCharacter.."_4"] then
    for i = 1, BINDPAD_MAXSLOTS do
      BindPadVars[character][profileNum][i+2*BINDPAD_MAXSLOTS] = BindPadVars[oldCharacter.."_4"][i];
    end
    BindPadVars[oldCharacter.."_4"] = nil;
  end
end

function BindPadCore.SwitchProfile(newProfileNum, force)
  local oldProfileNum = BindPadCore.GetCurrentProfileNum();
  if not force and newProfileNum == oldProfileNum then
    return;
  end

  if InCombatLockdown() then
    return;
  end

  -- Close any optional frames.
  BindPadMacroPopupFrame:Hide();
  HideUIPanel(BindPadMacroFrame);
  BindPadBindFrame:Hide();

  local character = BindPadCore.character;
  if nil == character then
    return;
  end

  BindPadCore.profileNum = newProfileNum;
  BindPadVars[character].activeProfile = newProfileNum;

  if nil == BindPadVars[character][newProfileNum] then
    BindPadVars[character][newProfileNum] = {};
    BindPadCore.DoSaveAllKeys();
    BindPadFrame_OutputText(BINDPAD_TEXT_CREATE_PROFILETAB);
  end

  if (BindPadCore.GetProfileData().version or 0) < BINDPAD_PROFILE_VERSION252 then
    BindPadCore.ConvertAllKeyBindingsFor252();
  end

  -- Restore all Blizzard's Key Bindings for this spec if possible.
  BindPadCore.DoRestoreAllKeys();
end

function BindPadCore.CanPickupSlot(self)
  if not InCombatLockdown() then
    return true;
  end
  local padSlot = BindPadCore.GetSlotInfo(self:GetID());
  if padSlot == nil then
    return false;
  end
  if TYPE_SPELL == padSlot.type then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_SPELL_INCOMBAT);
    return false;
  end
  if TYPE_MACRO == padSlot.type then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_MACRO_INCOMBAT);
    return false;
  end
  return true;
end

function BindPadCore.PickupSlot(self, id, isOnDragStart)
  local padSlot = BindPadCore.GetSlotInfo(id);
  if padSlot == nil then return; end
  if self == BindPadCore.selectedSlotButton then
    BindPadMacroPopupFrame:Hide();
    HideUIPanel(BindPadMacroFrame);
    BindPadBindFrame:Hide();
  end

  if TYPE_ITEM == padSlot.type then
    PickupItem(padSlot.linktext);
  elseif TYPE_SPELL == padSlot.type then
    local spellBookId = BindPadCore.FindSpellBookIdByName(padSlot.name, padSlot.rank, padSlot.bookType);
    if spellBookId then
      PickupSpell(spellBookId, padSlot.bookType);
    end
  elseif TYPE_MACRO == padSlot.type then
    PickupMacro(padSlot.name);
  elseif TYPE_BPMACRO == padSlot.type then
    local drag = BindPadCore.dragswap;
    BindPadCore.dragswap = BindPadCore.drag;
    BindPadCore.drag = drag;

    drag.action = padSlot.action;
    drag.id = padSlot.id;
    drag.macrotext = padSlot.macrotext;
    drag.name = padSlot.name;
    drag.texture = padSlot.texture;
    drag.type = padSlot.type;

    BindPadCore.UpdateCursor();
    PlaySound("igAbilityIconPickup");
  end

  if (not (isOnDragStart and IsModifierKeyDown())) then
    table.wipe(padSlot);
  end
end

function BindPadCore.SetBinding(key, action)
  SetBinding(key, action);

  -- Set common binding for all Profiles if it's general tab.
  if (BindPadVars.tab or 1) == 1 then
    local character = BindPadCore.character;
    for idx, profile in ipairs(BindPadVars[character]) do
      if (profile.version or 0) >= BINDPAD_PROFILE_VERSION252 then
        profile.AllKeyBindings[key] = action;
      end
    end
  end
end

function BindPadCore.BindKey(padSlot, keyPressed)
  if not InCombatLockdown() then
    BindPadCore.UnbindSlot(padSlot);
    BindPadCore.SetBinding(keyPressed, padSlot.action);
    SaveBindings(GetCurrentBindingSet());
  else
    BindPadFrame_OutputText(BINDPAD_TEXT_CANNOT_BIND);
  end
end

function BindPadCore.UnbindSlot(padSlot)
  if not InCombatLockdown() then
    repeat
      local key = GetBindingKey(padSlot.action);
      if key then
        BindPadCore.SetBinding(key);
      end
    until key == nil
    SaveBindings(GetCurrentBindingSet());
  end
end

function BindPadCore.GetSpellNum(bookType)
  local spellNum;
  if bookType == BOOKTYPE_PET then
    spellNum = HasPetSpells() or 0;
  else
    local i = 1;
    while (true) do
      local name, texture, offset, numSpells = GetSpellTabInfo(i);
      if not name then
        break
      end
      spellNum = offset + numSpells;
      i = i + 1;
    end
  end
  return spellNum;
end

function BindPadCore.InitCash()
  for k,v in pairs(BindPadCore.IsHighestCash) do
    BindPadCore.IsHighestCash[k] = nil;
  end

end

function BindPadCore.IsHighestRank(spellID, bookType)
  local cash = BindPadCore.IsHighestCash[spellID.."_"..bookType];
  if cash ~= nil then
    return cash;
  end

  local srchSpellName, srchSpellRank = GetSpellName(spellID, bookType);
  for i = BindPadCore.GetSpellNum(bookType), 1, -1 do
    spellName, spellRank = GetSpellName(i, bookType);
    if spellName == srchSpellName then
      local result = (srchSpellRank == spellRank);
      BindPadCore.IsHighestCash[spellID.."_"..bookType] = result;
      return result;
    end
  end
end

function BindPadCore.FindSpellBookIdByName(srchName, srchRank, bookType)
  for i = 1, BindPadCore.GetSpellNum(bookType), 1 do
    local spellName, spellRank = GetSpellName(i, bookType);
    if spellName == srchName and (nil == srchRank or spellRank == srchRank) then
      return i;
    end
  end
end

function BindPadCore.GetBindingText(name, prefix, returnAbbr)
  local modKeys = GetBindingText(name, prefix, nil);

  if ( returnAbbr ) then
    modKeys = gsub(modKeys, "CTRL", "c");
    modKeys = gsub(modKeys, "SHIFT", "s");
    modKeys = gsub(modKeys, "ALT", "a");
    modKeys = gsub(modKeys, "STRG", "st");
    modKeys = gsub(modKeys, "(%l)-(%l)-", "%1%2-");
    modKeys = gsub(modKeys, "Num Pad ", "#");
  end

  return modKeys;
end

function BindPadFrame_ChangeBindingProfile()
  if (GetCurrentBindingSet() == 1) then
    LoadBindings(2);
    SaveBindings(2);
    BindPadFrameCharacterButton:SetChecked(true);
  else
    local function f()
      local answer1 = BindPadCore.ShowDialog(CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS);
      if not answer1 then
        BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);
        return;
      end

      local answer2 = BindPadCore.ShowDialog(BINDPAD_TEXT_ARE_YOU_SURE);
      if not answer2 then
        BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);
        return;
      end

      LoadBindings(1);
      SaveBindings(1);
      BindPadVars.tab = 1;
      BindPadFrame_OnShow();
    end

    -- Handles callback with coroutine.
    return coroutine.wrap(f)();
  end
end

function BindPadCore.ChatEdit_InsertLinkHook(text)
  if (not text) then return; end
  local activeWindow = ChatEdit_GetActiveWindow();
  if (activeWindow) then return; end
  if (BrowseName and BrowseName:IsVisible()) then return; end
  if (MacroFrameText and MacroFrameText:IsVisible()) then return; end

  if ( BindPadMacroFrameText and BindPadMacroFrameText:IsVisible() ) then
    local item, spell;
    if ( strfind(text, "item:", 1, true) ) then
      item = GetItemInfo(text);
    else
      local _, _, kind, spellid = string.find(text, "^|c%x+|H(%a+):(%d+)[|:]");
    if spellid then
        local name, rank = GetSpellInfo(spellid);
        text = name;
      end
    end
    if ( BindPadMacroFrameText:GetText() == "" ) then
      if ( item ) then
        if ( GetItemSpell(text) ) then
          BindPadMacroFrameText:Insert(SLASH_USE1.." "..item);
        else
          BindPadMacroFrameText:Insert(SLASH_EQUIP1.." "..item);
        end
      else
        BindPadMacroFrameText:Insert(SLASH_CAST1.." "..text);
      end
    else
      BindPadMacroFrameText:Insert(item or text);
    end
  end
end

hooksecurefunc("ChatEdit_InsertLink", BindPadCore.ChatEdit_InsertLinkHook);

function BindPadCore.PickupSpellHook(slot, bookType)
    BindPadCore.PickupSpell_slot = slot;
    BindPadCore.PickupSpell_bookType = bookType;
end
hooksecurefunc("PickupSpell", BindPadCore.PickupSpellHook);


function BindPadCore.InitBindPad(event)
  if event == "PLAYER_LOGIN" then
    BindPadCore.flag_PLAYER_LOGIN = true;
  end
  if event == "VARIABLES_LOADED" then
    BindPadCore.flag_VARIABLES_LOADED = true;
  end
  if BindPadCore.flag_PLAYER_LOGIN and BindPadCore.flag_VARIABLES_LOADED then
    BindPadCore.InitProfile();
    BindPadCore.InitHotKeyList();
    BindPadCore.UpdateAllHotkeys();
  end
end

function BindPadCore.InitProfile()
  BindPadCore.character = "PROFILE_"..GetRealmName().."_"..UnitName("player");
  local character = BindPadCore.character;

  -- Savefile version 1.0 and 1.1 are obsolated.
  if BindPadVars.version == nil or
     BindPadVars.version < 1.2 then
    BindPadVars = {
      tab = BINDPAD_GENERAL_TAB,
      version = BINDPAD_SAVEFILE_VERSION,
    };
    BindPadFrame_OutputText(BINDPAD_TEXT_OBSOLATED);
  end

  if nil == BindPadVars[character] then
    BindPadCore.ConvertOldSlotInfo();
  end

  -- Make sure profileNum tab is set for current talent group.
  BindPadCore.SwitchProfile(BindPadVars[character].activeProfile or 1, true);

  BindPadMacro:SetAttribute("*type*", "macro");
  BindPadKey:SetAttribute("*checkselfcast*", true);
  BindPadKey:SetAttribute("*checkfocuscast*", true);

  BindPadFastMacro:SetAttribute("*type*", "macro");
  BindPadFastMacro:RegisterForClicks("AnyDown","AnyUp");

  BindPadFastKey:SetAttribute("*checkselfcast*", true);
  BindPadFastKey:SetAttribute("*checkfocuscast*", true);
  BindPadFastKey:RegisterForClicks("AnyDown","AnyUp");

  BindPadCore.SetTriggerOnKeydown();

  -- HACK: Making sure BindPadMacroFrame has UIPanelLayout defined.
  -- If we don't do this at the init, ShowUIPanel() may fail in combat.
  GetUIPanelWidth(BindPadMacroFrame);

  -- Set current version number
  BindPadVars.version = BINDPAD_SAVEFILE_VERSION;
end

function BindPadCore.UpdateMacroText(padSlot)
  if padSlot == nil then
    return;
  end

  BindPadCore.CheckCorruptedSlot(padSlot);
  if TYPE_ITEM == padSlot.type then
    BindPadKey:SetAttribute("*type-ITEM "..padSlot.name, "item");
    BindPadKey:SetAttribute("*item-ITEM "..padSlot.name, padSlot.name);
    BindPadFastKey:SetAttribute("*type-ITEM "..padSlot.name, "item");
    BindPadFastKey:SetAttribute("*item-ITEM "..padSlot.name, padSlot.name);

  elseif TYPE_SPELL == padSlot.type then
    local spellName = padSlot.name;
    BindPadKey:SetAttribute("*type-SPELL "..spellName, "spell");
    BindPadKey:SetAttribute("*spell-SPELL "..spellName, spellName);
    BindPadFastKey:SetAttribute("*type-SPELL "..spellName, "spell");
    BindPadFastKey:SetAttribute("*spell-SPELL "..spellName, spellName);

  elseif TYPE_MACRO == padSlot.type then
    BindPadKey:SetAttribute("*type-MACRO "..padSlot.name, "macro");
    BindPadKey:SetAttribute("*macro-MACRO "..padSlot.name, padSlot.name);
    BindPadFastKey:SetAttribute("*type-MACRO "..padSlot.name, "macro");
    BindPadFastKey:SetAttribute("*macro-MACRO "..padSlot.name, padSlot.name);

  elseif TYPE_BPMACRO == padSlot.type then
    BindPadMacro:SetAttribute("*macrotext-"..padSlot.name, padSlot.macrotext);
    BindPadFastMacro:SetAttribute("*macrotext-"..padSlot.name, padSlot.macrotext);

  else
    return;
  end

  -- Convert very old format to new format.
  local newAction = BindPadCore.CreateBindPadMacroAction(padSlot);
  if padSlot.action ~= newAction then
    local key = GetBindingKey(padSlot.action);
    if key then
      SetBinding(key, newAction);
      SaveBindings(GetCurrentBindingSet());
    end
    padSlot.action = newAction;
  end
end

function BindPadCore.NewBindPadMacroName(padSlot, name)
  local successFlag;
  repeat
    successFlag = true;
    for gid = 1, BINDPAD_TOTALSLOTS, 1 do
      local curSlot = BindPadCore.GetAllSlotInfo(gid);
      if curSlot then
        if (TYPE_BPMACRO == curSlot.type and padSlot ~= curSlot and curSlot.name ~= nil and strlower(name) == strlower(curSlot.name)) then
          local first, last, num = strfind(name, "(%d+)$");
          if nil == num then
              name = name .. "_2";
          else
              name = strsub(name, 0, first - 1) .. (num + 1);
          end
          successFlag = false;
          break
        end
      end
    end
  until successFlag;

  return name;
end

function BindPadCore.DeleteBindPadMacroID(padSlot)
  BindPadMacro:SetAttribute("*macrotext-"..padSlot.name, nil);
  BindPadFastMacro:SetAttribute("*macrotext-"..padSlot.name, nil);
end

function BindPadCore.UpdateCursor()
  local drag = BindPadCore.drag;
  if GetCursorInfo() then
    BindPadCore.ClearCursor();
  end
  if TYPE_BPMACRO == drag.type then
    SetCursor(drag.texture);
  end
end

function BindPadCore.CreateBindPadMacroAction(padSlot)
  if TYPE_ITEM == padSlot.type then
    return "CLICK BindPadKey:ITEM "..padSlot.name;
  elseif TYPE_SPELL == padSlot.type then
    return "CLICK BindPadKey:SPELL "..padSlot.name;
  elseif TYPE_MACRO == padSlot.type then
    return "CLICK BindPadKey:MACRO "..padSlot.name;
  elseif TYPE_BPMACRO == padSlot.type then
    return "CLICK BindPadMacro:"..padSlot.name;
  end

  return nil;
end

function BindPadCore.ConvertToBindPadMacro()
  local padSlot = BindPadCore.selectedSlot;

  if TYPE_ITEM == padSlot.type then
    padSlot.type = TYPE_BPMACRO;
    padSlot.linktext = nil;
    padSlot.macrotext = SLASH_USE1 .. " [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] " .. padSlot.name;

  elseif TYPE_SPELL == padSlot.type then
    padSlot.macrotext = SLASH_CAST1 .. " [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] ".. padSlot.name;
    padSlot.type = TYPE_BPMACRO;
    padSlot.bookType = nil;
    padSlot.rank = nil;
    padSlot.spellid = nil;

  elseif TYPE_MACRO == padSlot.type then
    local name, texture, macrotext = GetMacroInfo(padSlot.name);
    padSlot.type = TYPE_BPMACRO;
    padSlot.macrotext = (macrotext or "");

  else
    return;
  end

  padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, padSlot.name);
  padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);
  BindPadCore.UpdateMacroText(padSlot);

  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
  BindPadMacroFrame_Open(BindPadCore.selectedSlotButton);
end

function BindPadCore.CursorHasIcon()
  return (GetCursorInfo() or BindPadCore.drag.type)
end

function BindPadCore.ClearCursor()
  local drag = BindPadCore.drag;
  if TYPE_BPMACRO == drag.type then
    BindPadCore.DeleteBindPadMacroID(drag);
    ResetCursor();
    PlaySound("igAbilityIconDrop");
  end
  drag.type = nil;
end

-- function BindPadCore.CVAR_UPDATE(arg1, arg2)
--   if arg1 == "ACTION_BUTTON_USE_KEY_DOWN" then
--     BindPadCore.SetTriggerOnKeydown();
--   end
-- end

function BindPadCore.GetSpecInfoCache(talentGroup)
  if nil == talentGroup then
    return nil;
  end
  if nil == BindPadCore.specInfoCache[talentGroup] then
    BindPadCore.specInfoCache[talentGroup] = {};
  end
  local specInfoCache = BindPadCore.specInfoCache[talentGroup];
  if nil == specInfoCache.primaryTabIndex then
    TalentFrame_UpdateSpecInfoCache(specInfoCache, false, false, talentGroup);
  end
  return specInfoCache;
end

function BindPadCore.GetSpecTexture(talentGroup)
  local specInfoCache = BindPadCore.GetSpecInfoCache(talentGroup);
  if nil == specInfoCache then
    return nil;
  else
    local primaryTabIndex = specInfoCache.primaryTabIndex;
    if ( primaryTabIndex > 0 ) then
      -- the spec had a primary tab
      return specInfoCache[primaryTabIndex].icon;
    else
      return TALENT_HYBRID_ICON;
    end
  end
end

function BindPadCore.SetTriggerOnKeydown()
  if BindPadVars.triggerOnKeydown then
    -- Triggered on pressing a key instead of releasing.
    BindPadMacro:RegisterForClicks("AnyDown");
    BindPadKey:RegisterForClicks("AnyDown");
  else
    -- Triggered on releasing a key.
    BindPadMacro:RegisterForClicks("AnyUp");
    BindPadKey:RegisterForClicks("AnyUp");
  end
end

function BindPadCore.DoList(arg)
  for k, v in pairs(BindPadVars) do
    local name = string.match(k, "^PROFILE_(.*)");
    if name then print(name); end
  end
end

function BindPadCore.DoDelete(arg)
  local name = "PROFILE_" .. arg;
  if name == BindPadCore.character then
    BindPadFrame_OutputText(BINDPAD_TEXT_DO_DELETE_ERR_CURRENT);
  else
    if BindPadVars[name] then
      BindPadVars[name] = nil;
      BindPadFrame_OutputText(string.format(BINDPAD_TEXT_DO_DELETE, arg));
    else
      BindPadFrame_OutputText(string.format(BINDPAD_TEXT_DO_ERR_NOT_FOUND, arg));
    end
  end
end

function BindPadCore.DoCopyFrom(arg)
  local name = "PROFILE_" .. arg;
  if name == BindPadCore.character then
    BindPadFrame_OutputText(BINDPAD_TEXT_DO_COPY_ERR_CURRENT);
  else
    if BindPadVars[name] then
      local backupname = BindPadCore.character .. "_backup";
      if BindPadVars[backupname] == nil then
          BindPadVars[backupname] = BindPadVars[BindPadCore.character];
      end
      BindPadVars[BindPadCore.character] = BindPadCore.DuplicateTable(BindPadVars[name]);
      BindPadCore.InitProfile();

      if BindPadFrame:IsShown() then
        BindPadFrame_OnShow();
      end
      BindPadFrame_OutputText(string.format(BINDPAD_TEXT_DO_COPY, arg));
    else
      BindPadFrame_OutputText(string.format(BINDPAD_TEXT_DO_ERR_NOT_FOUND, arg));
    end
  end
end

function BindPadCore.DuplicateTable(table)
  local newtable = {};
  for k, v in pairs(table) do
    if type(v) == "table" then
      newtable[k] = BindPadCore.DuplicateTable(v);
    else
      newtable[k] = v;
    end
  end
  return newtable;
end

function BindPadCore.DoSetProfile(arg)
  local id = tonumber(arg) or 1;
  BindPadCore.SwitchProfile(id);
  if BindPadFrame:IsShown() then
    BindPadFrame_OnShow();
  end
end

function BindPadFrame_SaveAllKeysToggle(self)
  BindPadVars.saveAllKeysFlag = (self:GetChecked() == 1);
  BindPadCore.DoSaveAllKeys();
end

function BindPadFrame_ShowKeyInTooltipToggle(self)
  BindPadVars.showKeyInTooltipFlag = (self:GetChecked() == 1);
  BindPadCore.UpdateAllHotkeys();
end

function BindPadCore.DoSaveAllKeys()
  if BindPadCore.ChangingKeyBindings then return; end
  if nil == BindPadCore.character then return; end
  local profile = BindPadCore.GetProfileData();

  if profile.AllKeyBindings == nil then
    profile.AllKeyBindings = {};
  else
    table.wipe(profile.AllKeyBindings);
  end

  for i = 1, GetNumBindings() do
    local command, key1, key2 = GetBinding(i);
    if key1 then
      profile.AllKeyBindings[key1] = command;
      if key2 then profile.AllKeyBindings[key2] = command; end
    end
  end
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot then
      local key = GetBindingKey(padSlot.action);
      if key then profile.AllKeyBindings[key] = padSlot.action; end
    end
  end
end

function BindPadCore.DoRestoreAllKeys()
  local profile = BindPadCore.GetProfileData();
  if profile.AllKeyBindings == nil then
    -- Initialize keyBindings table if none available.
    BindPadCore.DoSaveAllKeys();
  end

  local count = 0;
  for k, v in pairs(profile.AllKeyBindings) do count = count + 1; end
  if count < 10 then
    BindPadFrame_OutputText("DEBUG: Something wrong.  profile.AllKeyBindings is most likely broken.");
    return;
  end

  BindPadCore.ChangingKeyBindings = true;

  -- Unbind Blizzard's key bindings only when "Save All Keys" option is ON.
  if BindPadVars.saveAllKeysFlag then
    for i = 1, GetNumBindings() do
      local command, key1, key2 = GetBinding(i);
      -- Ensure to be unbinded if not binded.
      if key1 and profile.AllKeyBindings[key1] == nil then
        SetBinding(key1, nil);
      end
      -- Ensure to be unbinded if not binded.
      if key2 and profile.AllKeyBindings[key2] == nil then
        SetBinding(key2, nil);
      end
    end
  end
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot then
      -- Ensure to be unbinded if not binded.
      local key = GetBindingKey(padSlot.action);
      if key and profile.AllKeyBindings[key] == nil then
        SetBinding(key, nil);
      end
    end
  end
  for k, v in pairs(profile.AllKeyBindings) do
    if BindPadVars.saveAllKeysFlag or strfind(v, "^CLICK BindPad") then
      local key1, key2 = GetBindingKey(v);
      if key1 ~= k and key2 ~= k then SetBinding(k, v); end
    end
  end

  BindPadCore.ChangingKeyBindings = false;

  local bindingset = GetCurrentBindingSet();
  if bindingset == 1 or bindingset == 2 then
    SaveBindings(bindingset);
  else
    -- GetCurrentBindingSet() sometimes returns invalid number at login.
    BindPadFrame_OutputText("GetCurrentBindingSet() returned:" .. (bindingset or "nil"));
  end

  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    -- Prepare macro text for every BindPad Macro for this profile.
    BindPadCore.UpdateMacroText(BindPadCore.GetAllSlotInfo(gid));
  end
end

function BindPadCore.ConvertAllKeyBindingsFor252()
  local profile = BindPadCore.GetProfileData();
  profile.AllKeyBindings = {};
  local keys_work = {};

  -- Convert SavedVariables older than BindPad 2.0.0
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot then
      if TYPE_ITEM ~= padSlot.type then padSlot.linktext = nil; end
      if padSlot.macrotext ~= nil and padSlot.id then
        if type(padSlot.id) == "number" then
          if strfind(padSlot.action, "^CLICK BindPadMacro%d+:") then
              -- Save old action value.
              padSlot.id = padSlot.action;
          end
        else
          -- Restore the saved value.
          -- Expecting that UpdateMacroText handles re-binding.
          padSlot.action = padSlot.id
        end
      end
    end
  end
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    BindPadCore.UpdateMacroText(BindPadCore.GetAllSlotInfo(gid));
  end

  -- Convert keybinding actions older than BindPad 2.2.0
  if profile.keys ~= nil then
    for k, v in pairs(profile.keys) do
      if strfind(k, "^SPELL ") or strfind(k, "^ITEM ") or strfind(k, "^MACRO ") then
        -- Create new element with converted action string.
        keys_work["CLICK BindPadKey:" .. k] = v;
      else
        -- Just copy if not too old format.
        keys_work[k] = v;
      end
    end
  end

  -- For character specific icons
  for gid = BINDPAD_MAXSLOTS + 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot then
      -- Bring registered key-action pairs
      -- and swap key and action to create new AllKeyBindings table.
      local key = keys_work[padSlot.action];
      if key then profile.AllKeyBindings[key] = padSlot.action; end
    end
  end

  -- For all BindPad icons including one in general tabs
  -- Save current key bind if the key is not registered yet.
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot then
      local key = GetBindingKey(padSlot.action);
      if key and profile.AllKeyBindings[key] == nil then
          profile.AllKeyBindings[key] = padSlot.action;
      end
    end
  end

  -- For all key bindings of Blizzard's Key Bindings Interface.
  -- Save current key bind only if the key is not registered yet.
  for i = 1, GetNumBindings() do
    local command, key1, key2 = GetBinding(i);
    if key1 and profile.AllKeyBindings[key1] == nil then
      profile.AllKeyBindings[key1] = command;
    end
    if key2 and profile.AllKeyBindings[key2] == nil then
      profile.AllKeyBindings[key2] = command;
    end
  end

  profile.keys = nil;
  profile.version = BINDPAD_PROFILE_VERSION252;
end

function BindPadCore.InsertBindingTooltip(action)
  local key = GetBindingKey("CLICK BindPadKey:" .. action);
  if key then
    -- Check if this keybind is ready to use. (or residue)
    if BindPadKey:GetAttribute("*type-" .. action) then
      GameTooltip:AddLine(BINDPAD_TOOLTIP_KEYBINDING .. BindPadCore.GetBindingText(key, "KEY_"), 0.8, 0.8, 1.0);
      GameTooltip:Show();
    end
  end
end

function BindPadCore.GameTooltipOnTooltipSetSpell(self, ...)
  if not BindPadVars.showKeyInTooltipFlag then
    return;
  end
  local name = self:GetSpell()
  if name then
    BindPadCore.InsertBindingTooltip("SPELL " .. name);
  end
end
GameTooltip:HookScript("OnTooltipSetSpell", function(...)
  return BindPadCore.GameTooltipOnTooltipSetSpell(...)
end);

function BindPadCore.GameTooltipOnTooltipSetItem(self, ...)
  if not BindPadVars.showKeyInTooltipFlag then return; end
  local name = self:GetItem()
  if name then BindPadCore.InsertBindingTooltip("ITEM " .. name); end
end
GameTooltip:HookScript("OnTooltipSetItem", function(...)
  return BindPadCore.GameTooltipOnTooltipSetItem(...)
end);

function BindPadCore.GameTooltipSetAction(self, slot)
  if not BindPadVars.showKeyInTooltipFlag then return; end
  local actionType, id, subType = GetActionInfo(slot);

  if actionType == "macro" then
    local name, texture, macrotext = GetMacroInfo(id);
    BindPadCore.InsertBindingTooltip("MACRO " .. name);
  end
end
hooksecurefunc(GameTooltip, "SetAction", function(...)
  return BindPadCore.GameTooltipSetAction(...) end
);

function BindPadCore.ShowDialog(text)
  BindPadCore.CancelDialogs();

  local dialog = BindPadDialogFrame;
  dialog.text:SetText(text);

  local height = 32 + dialog.text:GetHeight() + 8 + dialog.okaybutton:GetHeight();
  dialog:SetHeight(height);

  local co = coroutine.running();
  -- Making closures with current local value of co.
  dialog.okaybutton:SetScript("OnClick", function(self)
    self:GetParent():Hide();
    coroutine.resume(co, true);
  end);
  dialog.cancelbutton:SetScript("OnClick", function(self)
    self:GetParent():Hide();
    coroutine.resume(co, false)
  end);
  dialog:Show();

  return coroutine.yield();
end

function BindPadCore.CancelDialogs()
  local dialog = BindPadDialogFrame;
  if dialog:IsShown() then
    dialog.cancelbutton:Click();
  end
end

BindPadCore.HotKeyList = {};
BindPadCore.CreateFrameQueue = {};
function BindPadCore.InitHotKeyList()
  for k, button in pairs(ActionBarButtonEventsFrame.frames) do
    BindPadCore.CreateFrameQueue[button:GetName()] = "ActionBarButtonTemplate";
  end
end

function BindPadCore.AddHotKey(name, GetAction)
  if BindPadCore.HotKeyList[name] then return; end

  local button = _G[name];
  if not button then return; end

  local hotkey = _G[name .. "HotKey"];
  if not hotkey then return; end

  local info = {};
  info.GetAction = GetAction;
  info.button = button;
  info.hotkey = hotkey;

  info.bphotkey = button:CreateFontString(name .. "BPHotKey", "ARTWORK", "NumberFontNormalSmallGray");
  info.bphotkey:SetJustifyH("RIGHT")
  info.bphotkey:SetSize(36, 10)
  info.bphotkey:SetPoint("TOPLEFT", button, "TOPLEFT", -1, -3)
  info.bphotkey:Show();

  -- Copying the range indicator color change.
  hooksecurefunc(info.hotkey, "SetVertexColor", function(self, red, green, blue)
    return info.bphotkey:SetVertexColor(red, green, blue)
  end);

  BindPadCore.HotKeyList[name] = info;
end

function BindPadCore.AddAllHotKeys()
  for buttonname, buttontype in pairs(BindPadCore.CreateFrameQueue) do
    if buttontype == "ActionBarButtonTemplate" then
      BindPadCore.AddHotKey(buttonname, function(info)
        return info.button.action
      end);
    elseif buttontype == "LibActionButton" then
      BindPadCore.AddHotKey(buttonname, function(info)
        return select(2, info.button:GetAction())
      end);
    end
  end
  table.wipe(BindPadCore.CreateFrameQueue);
end

function BindPadCore.UpdateAllHotkeys()
  BindPadCore.AddAllHotKeys();
  for name, info in pairs(BindPadCore.HotKeyList) do
    BindPadCore.OverwriteHotKey(info);
  end
end

function BindPadFrame_TriggerOnKeydownToggle(self)
  BindPadVars.triggerOnKeydown = (self:GetChecked() == 1);
  BindPadCore.SetTriggerOnKeydown();
end

function BindPadCore.UpdateHotKey(slotID)
  BindPadCore.AddAllHotKeys();
  for name, info in pairs(BindPadCore.HotKeyList) do
    if info:GetAction() == slotID then
      BindPadCore.OverwriteHotKey(info);
    end
  end
end

function BindPadCore.OverwriteHotKey(info)
  if BindPadVars.showKeyInTooltipFlag then
    local action = BindPadCore.GetActionCommand(info:GetAction());
    if action then
      local key = GetBindingKey("CLICK BindPadKey:" .. action);
      if key then
        -- Check if this keybind is ready to use. (or residue)
        if BindPadKey:GetAttribute("*type-" .. action) then
          -- BindPad's ShowHotKey
          info.bphotkey:SetText(BindPadCore.GetBindingText(key, "KEY_", 1));
          info.bphotkey:SetAlpha(1);

          -- Making original hotkey transparent.
          info.hotkey:SetAlpha(0);
          return;
        end
      end
    end
  end

  -- Restoring original hotkey
  info.bphotkey:SetAlpha(0);
  info.hotkey:SetAlpha(1);
end

local function concat(arg1, arg2)
  if arg1 and arg2 then
    return arg1 .. arg2;
  end
end

function BindPadCore.GetActionCommand(actionSlot)
  local type, id, subType, subSubType = GetActionInfo(actionSlot);
  if type == "spell" then
    return concat("SPELL ", GetSpellInfo(id));
  elseif type == "item" then
    return concat("ITEM ", GetItemInfo(id));
  elseif type == "macro" then
    return concat("MACRO ", GetMacroInfo(id));
  else
    return nil;
  end
end

function BindPadCore.CreateFrameHook(frameType, frameName, parentFrame, inheritsFrame, id)
  if frameType == "CheckButton" and inheritsFrame then
    if inheritsFrame == "ActionBarButtonTemplate" then
      BindPadCore.CreateFrameQueue[frameName] = "ActionBarButtonTemplate";
    end
    if string.find(inheritsFrame, "SecureActionButtonTemplate%s*,%s*ActionButtonTemplate") then
      BindPadCore.CreateFrameQueue[frameName] = "LibActionButton";
    end
  end
end
hooksecurefunc("CreateFrame", BindPadCore.CreateFrameHook);