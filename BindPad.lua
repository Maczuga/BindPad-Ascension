--[[

  BindPad Addon for World of Warcraft

  Author: Tageshi

--]]

local NUM_MACRO_ICONS_SHOWN = 20;
local NUM_ICONS_PER_ROW = 5;
local NUM_ICON_ROWS = 4;
local MACRO_ICON_ROW_HEIGHT = 36;
local MACRO_ICON_FILENAMES = {};

-- Avoid taint of official lua codes.
local i, j;

-- Register BindPad frame to be controlled together with
-- other panels in standard UI.
UIPanelWindows["BindPadFrame"] = { area = "left", pushable = 8, whileDead = 1 };
UIPanelWindows["BindPadMacroFrame"] = { area = "left", pushable = 9, whileDead = 1 };

-- Register BindPad binding frame to be closed on Escape press.
tinsert(UISpecialFrames,"BindPadBindFrame");

local BINDPAD_MAXSLOTS = 42;
local BINDPAD_TOTALSLOTS = BINDPAD_MAXSLOTS * 4;
local BINDPAD_MAXPROFILETAB = 12;
local BINDPAD_GENERAL_TAB = 1;
local BINDPAD_SAVEFILE_VERSION = 1.3;

local TYPE_ITEM = TYPE_ITEM;
local TYPE_SPELL = TYPE_SPELL;
local TYPE_MACRO = TYPE_MACRO;
local TYPE_BPMACRO = TYPE_BPMACRO;

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
  actionButtonNames = {};
  actionButtonIds = {};
  IsHighestCash = {};
  hotkeyShownBefore = {};
  hotkeyTextBefore = {};
  hotkeyShownAfter = {};
  hotkeyTextAfter = {};
  drag = {};
  dragswap = {};
  specInfoCache = {};
};
local BindPadCore = BindPadCore;

StaticPopupDialogs["BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS"] = {
  text = CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function()
    StaticPopup_Show("BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS2");
  end,
  OnCancel = function()
    BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

StaticPopupDialogs["BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS2"] = {
  text = BINDPAD_TEXT_ARE_YOU_SURE,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function()
    LoadBindings(1);
    SaveBindings(1);
    BindPadVars.tab = 1;
    BindPadFrame_OnShow();
  end,
  OnCancel = function()
    BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

StaticPopupDialogs["BINDPAD_CONFIRM_CHANGE_BINDING_PROFILE"] = {
  text = BINDPAD_TEXT_CONFIRM_CHANGE_BINDING_PROFILE,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function()
    LoadBindings(2);
    SaveBindings(2);
    BindPadVars.tab = 2;
    BindPadFrame_OnShow();
  end,
  OnCancel = function()
    BindPadVars.tab = 1;
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

StaticPopupDialogs["BINDPAD_CONFIRM_CONVERT"] = {
  text = BINDPAD_TEXT_CONFIRM_CONVERT,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function(id)
    BindPadCore.ConvertToBindPadMacro(id);
  end,
  OnCancel = function()
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

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

  self:RegisterEvent("PLAYER_LOGIN");
  self:RegisterEvent("SPELLS_CHANGED");
  self:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
  self:RegisterEvent("UPDATE_BINDINGS");
  -- self:RegisterEvent("CVAR_UPDATE");

  GetMacroIcons(MACRO_ICON_FILENAMES);
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

  if event == "ACTIONBAR_SLOT_CHANGED" then
    BindPadCore.UpdateHotkey(arg1, BindPadCore.GetActionButton(arg1));
  elseif event == "UPDATE_BINDINGS" then
    -- Use a single shot of OnUpdate for update of hotkeys.
    BindPadUpdateFrame:Show();
  elseif event == "SPELLS_CHANGED" then
    BindPadCore.InitCash();
  elseif event == "PLAYER_LOGIN" then
    BindPadCore.InitBindPad();
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

function BindPadFrame_OnShow(id)
  if id then
    BindPadVars.tab = id;
  elseif nil == BindPadVars.tab then
    BindPadVars.tab = 1;
  end
  if GetCurrentBindingSet() == 1 then
    -- Don't show Character Specific Slots tab at first.
    BindPadVars.tab = 1;
    if id then
      StaticPopup_Show("BINDPAD_CONFIRM_CHANGE_BINDING_PROFILE");
    end
  end

  if BindPadVars.tab == 1 then
    BindPadFrameTitleText:SetText(BINDPAD_TITLE);
  else
    BindPadFrameTitleText:SetText(_G["BINDPAD_TITLE_" .. BindPadCore.GetCurrentProfileNum()]);
  end

  PanelTemplates_SetTab(BindPadFrame, BindPadVars.tab);

  -- Update character button
  BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);

  -- Update Show Hotkeys button
  BindPadFrameShowHotkeysButton:SetChecked(BindPadVars.showHotkey);

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

function BindPadUpdateFrame_OnUpdate(self)
  if BindPadVars.showHotkey == nil then
    BindPadVars.showHotkey = true;
  end

  self:Hide();
  BindPadCore.UpdateAllHotKeys();
end

function BindPadBindFrame_Update()
  StaticPopup_Hide("BINDPAD_CONFIRM_BINDING")
  BindPadBindFrameAction:SetText(BindPadCore.selectedSlot.action);

  local key = GetBindingKey(BindPadCore.selectedSlot.action);
  if key then
    BindPadBindFrameKey:SetText(BINDPAD_TEXT_KEY..BindPadCore.GetBindingText(key, "KEY_"));
  else
    BindPadBindFrameKey:SetText(BINDPAD_TEXT_KEY..BINDPAD_TEXT_NOTBOUND);
  end

  -- Update Fast Trigger button
  BindPadBindFrameFastTriggerButton:SetChecked(BindPadCore.selectedSlot.fastTrigger);
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
  if keyPressed then
    BindPadCore.keyPressed = keyPressed
    local oldAction = GetBindingAction(keyPressed)

    local keyText = BindPadCore.GetBindingText(keyPressed, "KEY_");
    if oldAction~="" and oldAction ~= BindPadCore.selectedSlot.action then
      if StaticPopupDialogs["BINDPAD_CONFIRM_BINDING"] == nil then
        StaticPopupDialogs["BINDPAD_CONFIRM_BINDING"] = {
          button1 = YES,
          button2 = NO,
          timeout = 0,
          hideOnEscape = 1,
          OnAccept = BindPadBindFrame_SetBindKey,
          OnCancel = BindPadBindFrame_Update,
          whileDead = 1
        }
      end
      StaticPopupDialogs["BINDPAD_CONFIRM_BINDING"].text = format(BINDPAD_TEXT_CONFIRM_BINDING, keyText, oldAction, keyText, BindPadCore.selectedSlot.action);
      StaticPopup_Show("BINDPAD_CONFIRM_BINDING")
    else
      BindPadBindFrame_SetBindKey();
    end
  end
end

function BindPadBindFrame_SetBindKey()
  BindPadCore.BindKey();
  BindPadBindFrame_Update();
end

function BindPadBindFrame_Unbind()
  BindPadCore.UnbindSlot(BindPadCore.selectedSlot);
  BindPadBindFrame_Update();
end

function BindPadBindFrame_OnHide(self)
  -- Close the confirmation dialog frame if it is still open.
  StaticPopup_Hide("BINDPAD_CONFIRM_BINDING")
end

function BindPadBindFrame_FastTriggerToggle(self)
  BindPadCore.selectedSlot.fastTrigger = (self:GetChecked() == 1);
  BindPadCore.UpdateMacroText(BindPadCore.selectedSlot);
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
  BindPadBindFrame_Update();
end

function BindPadSlot_OnUpdateBindings(self)
  if BindPadCore.character then
    BindPadSlot_UpdateState(self);
  end
end

function BindPadSlot_OnClick(self, button, down)
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
    if nil ~= BindPadCore.GetSlotInfo(self:GetID()).type then
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
  BindPadCore.PickupSlot(self, self:GetID());
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
    local spellID = BindPadCore.FindSpellIdByName(padSlot.name, padSlot.rank, padSlot.bookType);
    if spellID then
      GameTooltip:SetSpell(spellID, padSlot.bookType)
    else
      GameTooltip:SetText(BINDPAD_TOOLTIP_UNKNOWN_SPELL..padSlot.name, 1.0, 1.0, 1.0);
    end
    if padSlot.rank then
      GameTooltip:AddLine(BINDPAD_TOOLTIP_DOWNRANK..padSlot.rank, 1.0, 0.7, 0.7);
    end
  elseif TYPE_MACRO == padSlot.type then
    GameTooltip:SetText(BINDPAD_TOOLTIP_MACRO..padSlot.name, 1.0, 1.0, 1.0);
  elseif TYPE_BPMACRO == padSlot.type then
    GameTooltip:SetText(format(BINDPAD_TOOLTIP_BINDPADMACRO, padSlot.name), 1.0, 1.0, 1.0);
  end

  local key = GetBindingKey(padSlot.action);
  if key then
    GameTooltip:AddLine(BINDPAD_TOOLTIP_KEYBINDING..BindPadCore.GetBindingText(key, "KEY_"), 0.8, 0.8, 1.0);
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
  local padSlot = BindPadCore.GetSlotInfo(self:GetID());
  local newFlag = false;
  BindPadCore.CheckCorruptedSlot(padSlot);

  BindPadMacroPopup_oldPadSlot.action = padSlot.action;
  BindPadMacroPopup_oldPadSlot.id = padSlot.id;
  BindPadMacroPopup_oldPadSlot.macrotext = padSlot.macrotext;
  BindPadMacroPopup_oldPadSlot.name = padSlot.name;
  BindPadMacroPopup_oldPadSlot.texture = padSlot.texture;
  BindPadMacroPopup_oldPadSlot.type = padSlot.type;
  BindPadMacroPopup_oldPadSlot.fastTrigger = padSlot.fastTrigger;

  if nil == padSlot.type then
    newFlag = true;

    padSlot.type = TYPE_BPMACRO;
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, "1");
    padSlot.texture = BindPadCore.GetMacroIconInfo(1);
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
  local numMacroIcons = #MACRO_ICON_FILENAMES;
  local macroPopupIcon, macroPopupButton;
  local macroPopupOffset = FauxScrollFrame_GetOffset(BindPadMacroPopupScrollFrame) or 0;
  local index;

  -- Icon list
  local texture;
  for i=1, NUM_MACRO_ICONS_SHOWN do
    macroPopupIcon = _G["BindPadMacroPopupButton"..i.."Icon"];
    macroPopupButton = _G["BindPadMacroPopupButton"..i];
    index = (macroPopupOffset * NUM_ICONS_PER_ROW) + i;
    texture = BindPadCore.GetMacroIconInfo(index);
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
  padSlot.fastTrigger = BindPadMacroPopup_oldPadSlot.fastTrigger;

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

  BindPadCore.selectedSlot.texture = BindPadCore.GetMacroIconInfo(BindPadMacroPopupFrame.selectedIcon);
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

  if nil == padSlot.type then
    return;
  end
  BindPadCore.selectedSlot = padSlot;
  BindPadCore.selectedSlotButton = self;

  if TYPE_ITEM == padSlot.type or TYPE_SPELL == padSlot.type or TYPE_MACRO == padSlot.type then
    StaticPopup_Show("BINDPAD_CONFIRM_CONVERT", padSlot.type, padSlot.name);
    return;
  end

  BindPadMacroFrameSelectedMacroName:SetText(padSlot.name);
  BindPadMacroFrameSelectedMacroButtonIcon:SetTexture(padSlot.texture);
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

  BindPadCore.DeleteBindPadMacroID(padSlot);

  padSlot.action = nil;
  padSlot.bookType = nil;
  padSlot.id = nil;
  padSlot.linktext = nil;
  padSlot.macrotext = nil;
  padSlot.name = nil;
  padSlot.rank = nil;
  padSlot.texture = nil;
  padSlot.type = nil;
  padSlot.fastTrigger = nil;

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
  normalTexture:SetTexture(texture);

  if BindPadCore.GetCurrentProfileNum() == self:GetID() then
    self:SetChecked(1);
  end
end

function BindPadProfileTab_OnClick(self, button, down)
  if BindPadVars.tab == 1 and self:GetID() ~= BindPadCore.GetCurrentProfileNum() then
    BindPadFrame_OnShow(2);
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

  local padSlot = BindPadCore.GetSlotInfo(id);

  if type == "item" then
    padSlot.linktext = subdetail;
    local name,_,_,_,_,_,_,_,_,texture = GetItemInfo(padSlot.linktext);
    padSlot.name = name;
    padSlot.texture = texture;
    padSlot.type = TYPE_ITEM;

  elseif type == "macro" then
    local name, texture = GetMacroInfo(detail);
    padSlot.name = name;
    padSlot.texture = texture;
    padSlot.type = TYPE_MACRO;

  elseif type == "spell" then
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
    padSlot.type = TYPE_SPELL;

    elseif type == "petaction" then
      local spellName, spellRank = GetSpellBookItemName(detail, subdetail);
      local texture = GetSpellBookItemTexture(detail, subdetail);
      if BindPadPetAction[spellName] then
        padSlot.bookType = nil;
        padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, BindPadPetAction[spellName]);
        padSlot.rank = nil;
        padSlot.texture = texture;
        padSlot.type = TYPE_BPMACRO;
        padSlot.macrotext = BindPadPetAction[spellName];
      else
        padSlot.bookType = subdetail;
        padSlot.name = spellName;
        padSlot.rank = nil;
        padSlot.texture = texture;
        padSlot.type = TYPE_SPELL;
        padSlot.macrotext = nil;
      end

  elseif type == "merchant" then
    padSlot.linktext = GetMerchantItemLink(detail);
    local name,_,_,_,_,_,_,_,_,texture = GetItemInfo(padSlot.linktext);
    padSlot.name = name;
    padSlot.texture = texture;
    padSlot.type = TYPE_ITEM;

  elseif type == "companion" then
    local creatureID, creatureName, creatureSpellID, texture = GetCompanionInfo(subdetail, detail);
    local spellName = GetSpellInfo(creatureSpellID);
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, spellName);
    padSlot.texture = texture;
    padSlot.type = TYPE_BPMACRO;
    padSlot.macrotext = "/cast "..spellName;

  elseif type == "equipmentset" then
    local textureName = BindPadCore.GetEquipmentSetTexture(detail);
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, detail);
    padSlot.texture = textureName;
    padSlot.type = TYPE_BPMACRO;
    padSlot.macrotext = "/equipset "..detail;

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

  local padSlot = BindPadCore.GetSlotInfo(id);

  padSlot.id = drag.id;
  padSlot.macrotext = drag.macrotext;
  padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, drag.name);
  padSlot.texture = drag.texture;
  padSlot.type = drag.type;
  padSlot.fastTrigger = drag.fastTrigger;
  padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);

  drag.type = nil;
  PlaySound("igAbilityIconDrop");
end

function BindPadCore.CheckCorruptedSlot(padSlot)
  if padSlot.type == TYPE_ITEM and padSlot.linktext and padSlot.name and
    padSlot.texture and padSlot.action then return false; end
  if padSlot.type == TYPE_MACRO and padSlot.name and padSlot.texture and
    padSlot.action then return false; end
  if padSlot.type == TYPE_SPELL and padSlot.bookType and padSlot.name and
    padSlot.texture and padSlot.action then return false; end
  if padSlot.type == TYPE_BPMACRO and padSlot.name and padSlot.texture and
    padSlot.macrotext and padSlot.action then return false; end

  padSlot.action = nil;
  padSlot.bookType = nil;
  padSlot.id = nil;
  padSlot.linktext = nil;
  padSlot.macrotext = nil;
  padSlot.name = nil;
  padSlot.rank = nil;
  padSlot.texture = nil;
  padSlot.type = nil;
  padSlot.fastTrigger = nil;
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
  if nil == profile.keys then
    profile.keys = {};
  end
  return profile;
end

function BindPadCore.GetSlotInfo(id)
  if id == nil then
    return nil;
  end
  local gid = id + ((BindPadVars.tab or 1) - 1) * BINDPAD_MAXSLOTS;
  return BindPadCore.GetAllSlotInfo(gid);
end

function BindPadCore.GetAllSlotInfo(gid)
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
      BindPadVars[character][profileNum][sid] = {};
    end
    padSlot = BindPadVars[character][profileNum][sid];
  else
    if nil == BindPadVars[gid] then
      BindPadVars[gid] = {};
    end
    padSlot = BindPadVars[gid];
  end
  return padSlot;
end

function BindPadCore.CreateKeysArray()
  -- Save keybindings for all slots
  for gid = BINDPAD_MAXSLOTS + 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot.action then
      if nil == BindPadCore.GetProfileData().keys[padSlot.action] then
        BindPadCore.GetProfileData().keys[padSlot.action] = GetBindingKey(padSlot.action);
      end
    end
  end
end

function BindPadCore.ConvertOldSlotInfo()
  local oldCharacter = GetRealmName().."_"..UnitName("player");
  local character = BindPadCore.character;

  local profileNum = BindPadCore.GetCurrentProfileNum();

  BindPadVars[character] = {};
  BindPadVars[character][profileNum] = {};
  BindPadVars[character][profileNum].keys = {};

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

  BindPadCore.CreateKeysArray();
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

  local oldProfile = BindPadCore.GetProfileData();
  BindPadCore.profileNum = newProfileNum;
  BindPadVars[character].activeProfile = newProfileNum;

  if nil == BindPadVars[character][newProfileNum] then
    BindPadVars[character][newProfileNum] = {};
    BindPadVars[character][newProfileNum].keys = {};
    local newProfile = BindPadCore.GetProfileData();
    for sid = 1, BINDPAD_TOTALSLOTS - BINDPAD_MAXSLOTS, 1 do
      newProfile[sid] = {};
      for k,v in pairs(oldProfile[sid]) do
        newProfile[sid][k] = v;
      end
    end
    for k,v in pairs(oldProfile.keys) do
      newProfile.keys[k] = v;
    end
    BindPadFrame_OutputText(BINDPAD_TEXT_CREATE_PROFILETAB);
  end

  for k,v in pairs(BindPadCore.GetProfileData().keys) do
    if strfind(k, "^SPELL ") or strfind(k, "^ITEM ") or strfind(k, "^MACRO ") then
      -- Create new element with converted action string.
      -- Don't delete old elements yet to ensure full iteration.
      BindPadCore.GetProfileData().keys["CLICK BindPadKey:"..k] = v;
    end
  end

  for gid = BINDPAD_MAXSLOTS + 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot.action then
      local newKey = BindPadCore.GetProfileData().keys[padSlot.action];
      BindPadCore.UpdateMacroText(padSlot);

      -- Unbind keys for this action except the new key.
      local alreadyBound = false;
      repeat
        local oldKey1, oldKey2 = GetBindingKey(padSlot.action);
        if oldKey1 then
          if oldKey1 == newKey then
            alreadyBound = true;
          else
            SetBinding(oldKey1);
          end
        end
        if oldKey2 then
          if oldKey2 ~= newKey then
            alreadyBound = true;
          else
            SetBinding(oldKey2);
          end
        end
      until oldKey2 == nil

      if newKey and not alreadyBound then
        SetBinding(newKey, padSlot.action);
        BindPadCore.GetProfileData().keys[padSlot.action] = newKey;
      end
    end
  end
  local bindingset = GetCurrentBindingSet();
  if bindingset == 1 or bindingset == 2 then
    SaveBindings(bindingset);
  else
    BindPadFrame_OutputText("GetCurrentBindingSet() returned:"..(bindingset or "nil"));
  end

  for k,v in pairs(BindPadCore.GetProfileData().keys) do
    if strfind(k, "^SPELL ") or strfind(k, "^ITEM ") or strfind(k, "^MACRO ") then
      -- Delete old elements *after* creating all the new elements.
      BindPadCore.GetProfileData().keys[k] = nil;
    end
  end

  BindPadFrameTitleText:SetText(_G["BINDPAD_TITLE_"..newProfileNum]);
end

function BindPadCore.CanPickupSlot(self)
  if not InCombatLockdown() then
    return true;
  end
  local padSlot = BindPadCore.GetSlotInfo(self:GetID());
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

function BindPadCore.PickupSlot(self, id)
  local padSlot = BindPadCore.GetSlotInfo(id);
  if TYPE_ITEM == padSlot.type then
    PickupItem(padSlot.linktext);
  elseif TYPE_SPELL == padSlot.type then
    local spellID = BindPadCore.FindSpellIdByName(padSlot.name, padSlot.rank, padSlot.bookType);
    if spellID then
      PickupSpell(spellID, padSlot.bookType);
    end
  elseif TYPE_MACRO == padSlot.type then
    PickupMacro(padSlot.name);
  elseif TYPE_BPMACRO == padSlot.type then
    if self == BindPadCore.selectedSlotButton then
      BindPadMacroPopupFrame:Hide();
      HideUIPanel(BindPadMacroFrame);
      BindPadBindFrame:Hide();
    end

    local drag = BindPadCore.dragswap;
    BindPadCore.dragswap = BindPadCore.drag;
    BindPadCore.drag = drag;

    drag.action = padSlot.action;
    drag.id = padSlot.id;
    drag.macrotext = padSlot.macrotext;
    drag.name = padSlot.name;
    drag.texture = padSlot.texture;
    drag.type = padSlot.type;
    drag.fastTrigger = padSlot.fastTrigger;

    BindPadCore.UpdateCursor();
    PlaySound("igAbilityIconPickup");
  end

  if (not IsModifierKeyDown()) then
    padSlot.action = nil;
    padSlot.bookType = nil;
    padSlot.id = nil;
    padSlot.linktext = nil;
    padSlot.macrotext = nil;
    padSlot.name = nil;
    padSlot.rank = nil;
    padSlot.texture = nil;
    padSlot.type = nil;
    padSlot.fastTrigger = nil;
  end
end


function BindPadCore.BindKey()
  if not InCombatLockdown() then
    local padSlot = BindPadCore.selectedSlot;
    BindPadCore.UnbindSlot(padSlot);

    SetBinding(BindPadCore.keyPressed, padSlot.action);
    SaveBindings(GetCurrentBindingSet());
    for k,v in pairs(BindPadCore.GetProfileData().keys) do
      if v == BindPadCore.keyPressed then
        BindPadCore.GetProfileData().keys[k] = nil;
      end
    end
    BindPadCore.GetProfileData().keys[padSlot.action] = BindPadCore.keyPressed;
  else
    BindPadFrame_OutputText(BINDPAD_TEXT_CANNOT_BIND);
  end
end

function BindPadCore.UnbindSlot(padSlot)
  if not InCombatLockdown() then
    repeat
      local key = GetBindingKey(padSlot.action);
      if key then
        SetBinding(key);
        for k,v in pairs(BindPadCore.GetProfileData().keys) do
          if v == key then
            BindPadCore.GetProfileData().keys[k] = nil;
          end
        end
      end
    until key == nil
    SaveBindings(GetCurrentBindingSet());
    BindPadCore.GetProfileData().keys[padSlot.action] = nil;
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
      if not name then break end
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

function BindPadCore.FindSpellIdByName(srchName, srchRank, bookType)
  for i = BindPadCore.GetSpellNum(bookType), 1, -1 do
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
  if ( GetCurrentBindingSet() == 1 ) then
    LoadBindings(2);
    SaveBindings(2);
    BindPadFrameCharacterButton:SetChecked(true);
  else
    StaticPopup_Show("BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS");
  end
end

function BindPadCore.GetActionCommand(actionSlot, fastTrigger)
  local type, id, subType, subSubType = GetActionInfo(actionSlot);
  local commandType, name;

  local prefix = fastTrigger and "BindPadFast" or "BindPad";

  if type == "spell" then
    if id == 0 then
      -- When player is training new rank of the spell,
      -- two GetActionInfo events fired and 1st one returns invalid id from GetActionInfo.
      return nil;
    end

    commandType = "CLICK " .. prefix .. "Key:SPELL ";
    local spellName, spellRank = GetSpellName(id, subType);
    if BindPadCore.IsHighestRank(id, subType) then
      spellRank = nil;
    end
    name = BindPadCore.GetSpellName(spellName, spellRank);
  elseif type == "item" then
    commandType = "CLICK " .. prefix .. "Key:ITEM ";
    name,_ = GetItemInfo(id);
  elseif type == "macro" then
    commandType = "CLICK " .. prefix .. "Key:MACRO ";
    name,_ = GetMacroInfo(id);
  else
    return nil;
  end

  if name then
    return commandType..name;
  end
end

function BindPadCore.UpdateHotkey(actionSlot, ...)
  local thisName = select(1, ...);
  if thisName == nil then
    return;
  end
  local thisButton = _G[thisName];
  local hotkey = _G[thisName.."HotKey"] or thisButton.hotkey;
  local text = hotkey:GetText();
  local shown = not (not hotkey:IsShown());  -- true or false (it never be nil.)
  local textBefore, shownBefore;
  local textNew, shownNew;

  if (BindPadCore.hotkeyShownAfter[thisName] ~= nil) and
     (BindPadCore.hotkeyTextAfter[thisName] == text) then
    -- Revert back to original text if it is still my own autobinding text.
    textBefore = BindPadCore.hotkeyTextBefore[thisName];
    if BindPadCore.hotkeyShownAfter[thisName] == shown then
      shownBefore = BindPadCore.hotkeyShownBefore[thisName];
    end
  else
    -- Keep any text and stat if someone changed it.
    BindPadCore.hotkeyTextBefore[thisName] = text;
    BindPadCore.hotkeyShownBefore[thisName] = shown;
    textBefore = text;
    shownBefore = shown;
  end

  if (BindPadVars.showHotkey and
     (not shownBefore or textBefore == nil or textBefore == "" or textBefore == RANGE_INDICATOR)) then
    local command = BindPadCore.GetActionCommand(actionSlot);
    if command then
      local key = GetBindingKey(command);
      if key then
        local _, _, virtualButton = string.find(command, "^CLICK BindPadKey:(.+)");
        if virtualButton and not BindPadKey:GetAttribute("*type-"..virtualButton) then
          -- This binding is deleted on BindPadFrame already.
          key = nil;
        end
      end
      textNew = BindPadCore.GetBindingText(key, "KEY_", 1);
    end
  end

  if textNew == nil or textNew == "" then
    textNew = textBefore;
    shownNew = shownBefore;
    BindPadCore.hotkeyShownAfter[thisName] = nil;
  else
    shownNew = true;
    BindPadCore.hotkeyShownAfter[thisName] = true;
    BindPadCore.hotkeyTextAfter[thisName] = textNew;
  end

  if text ~= textNew then
    hotkey:SetText(textNew);
  end
  if textNew == RANGE_INDICATOR and text ~= RANGE_INDICATOR then
    hotkey:SetPoint("TOPLEFT", thisButton, "TOPLEFT", 1, -2);
  elseif textNew ~= RANGE_INDICATOR and text == RANGE_INDICATOR then
    hotkey:SetPoint("TOPLEFT", thisButton, "TOPLEFT", -2, -2);
  end
  if shown and not shownNew then
    hotkey:Hide();
  elseif not shown and shownNew then
    hotkey:Show();
  end

  -- Recursive call of UpdateHotkey.
  if select("#", ...) >= 2 then
    BindPadCore.UpdateHotkey(actionSlot, select(2, ...));
  end
end

function BindPadCore.AddActionButton(actionSlot, buttonName)
  local oldSlot = BindPadCore.actionButtonIds[buttonName];
  if oldSlot == actionSlot then
    return;
  elseif oldSlot ~= nil then
    local oldElement = BindPadCore.actionButtonNames[oldSlot];
    if type(oldElement) == "table" then
      for k,v in pairs(oldElement) do
        if v == buttonName then
          tremove(oldElement, k);
        end
      end
    elseif oldElement == buttonName then
      BindPadCore.actionButtonNames[oldSlot] = nil;
    end
  end
  local element = BindPadCore.actionButtonNames[actionSlot];
  if type(element) == "table" then
    tinsert(element, buttonName);
  elseif type(element) == "string" then
    BindPadCore.actionButtonNames[actionSlot] = {element, buttonName};
  else
    BindPadCore.actionButtonNames[actionSlot] = buttonName;
  end
  BindPadCore.actionButtonIds[buttonName] = actionSlot;
end

function BindPadCore.GetActionButton(actionSlot)
  local element = BindPadCore.actionButtonNames[actionSlot];
  if type(element) == "table" then
    return unpack(element);
  else
    return element;
  end
end

function BindPadCore.UpdateAllHotKeys()
  for k,v in pairs(BindPadCore.actionButtonNames) do
    BindPadCore.UpdateHotkey(k, BindPadCore.GetActionButton(k));
  end
end

function BindPadFrame_ShowHotkeysToggle(self)
  BindPadVars.showHotkey = (self:GetChecked() == 1);

  BindPadCore.UpdateAllHotKeys();
end

function BindPadFrame_TriggerOnKeydownToggle(self)
  BindPadVars.triggerOnKeydown = (self:GetChecked() == 1);

  BindPadCore.SetTriggerOnKeydown();
end

function BindPadCore.GetActionTextureHook(actionSlot)
  local self = this;
  if not self then return; end

  local thisName = self:GetName();
  if not thisName then return; end

  local hotkey = _G[thisName.."HotKey"] or self.hotkey;
  if not hotkey then return; end

  BindPadCore.AddActionButton(actionSlot, thisName);

  -- Use a single shot of OnUpdate for intial update of hotkeys.
  BindPadUpdateFrame:Show();
end
-- As far as I know, GetActionTexture is only called by various ActionButtons.
-- hooksecurefunc("GetActionTexture", BindPadCore.GetActionTextureHook);

function BindPadCore.ActionButton_UpdateHook(self)
  if not self then return; end

  if not self.action then return; end

  local thisName = self:GetName();
  if not thisName then return; end

  local hotkey = _G[thisName .. "HotKey"] or self.hotkey;
  if not hotkey then return; end

  BindPadCore.AddActionButton(self.action, thisName);

  -- Use a single shot of OnUpdate for intial update of hotkeys.
  BindPadUpdateFrame:Show();
end
hooksecurefunc("ActionButton_Update", BindPadCore.ActionButton_UpdateHook);


function BindPadCore.ChatEdit_InsertLinkHook(text)
  if ( BindPadMacroFrameText and BindPadMacroFrameText:IsVisible() ) then
    local item, spell;
    if ( strfind(text, "item:", 1, true) ) then
      item = GetItemInfo(text);
    else
      local _, _, kind, spellid = string.find(text, "^|c%x+|H(%a+):(%d+)[|:]");
    if spellid then
        local name, rank = GetSpellInfo(spellid);
        text = BindPadCore.GetSpellName(name, rank);
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


function BindPadCore.InitBindPad()
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

  -- Convert SavedVariables older than BindPad 2.0.0
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if TYPE_ITEM ~= padSlot.type then
      padSlot.linktext = nil;
    end
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
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    BindPadCore.UpdateMacroText(BindPadCore.GetAllSlotInfo(gid));
  end
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
  if TYPE_ITEM == padSlot.type then
    BindPadKey:SetAttribute("*type-ITEM "..padSlot.name, "item");
    BindPadKey:SetAttribute("*item-ITEM "..padSlot.name, padSlot.name);
    BindPadFastKey:SetAttribute("*type-ITEM "..padSlot.name, "item");
    BindPadFastKey:SetAttribute("*item-ITEM "..padSlot.name, padSlot.name);

  elseif TYPE_SPELL == padSlot.type then
    local spellName = BindPadCore.GetSpellName(padSlot.name, padSlot.rank);
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

  local newAction = BindPadCore.CreateBindPadMacroAction(padSlot);
  if padSlot.action ~= newAction then
    local key = GetBindingKey(padSlot.action);
    if key then
      SetBinding(key, newAction);
      SaveBindings(GetCurrentBindingSet());
      BindPadCore.GetProfileData().keys[padSlot.action] = nil;
      BindPadCore.GetProfileData().keys[newAction] = key;
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
      if (TYPE_BPMACRO == curSlot.type and padSlot ~= curSlot and curSlot.name ~= nil and strlower(name) == strlower(curSlot.name)) then
        local first, last, num = strfind(name, "(%d+)$");
        if nil == num then
          name = name.."_2";
        else
          name = strsub(name, 0, first - 1)..(num+1);
        end
        successFlag = false;
        break;
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

function BindPadCore.GetSpellName(name, rank)
  if name == nil then return nil; end
  if rank == nil then
    if strfind(name, "(", 1, true) then
      -- Workaround for the issue of SetBinding API;
      -- Add an empty pair of bracket when the spell includes a pair of bracket in its name.
      -- For example the spell "Faerie Fire(Feral)" must be "Faerie Fire(Feral)()"
      return name.."()";
    else
      return name;
    end
  else
    return name.."("..rank..")";
  end
end

function BindPadCore.CreateBindPadMacroAction(padSlot)
  local prefix = padSlot.fastTrigger and "BindPadFast" or "BindPad";

  if TYPE_ITEM == padSlot.type then
    return "CLICK " .. prefix .. "Key:ITEM "..padSlot.name;
  elseif TYPE_SPELL == padSlot.type then
    return "CLICK " .. prefix .. "Key:SPELL "..BindPadCore.GetSpellName(padSlot.name, padSlot.rank);
  elseif TYPE_MACRO == padSlot.type then
    return "CLICK " .. prefix .. "Key:MACRO "..padSlot.name;
  elseif TYPE_BPMACRO == padSlot.type then
    return "CLICK " .. prefix .. "Macro:"..padSlot.name;
  end

  return nil;
end

function BindPadCore.ConvertToBindPadMacro()
  local padSlot = BindPadCore.selectedSlot;

  if TYPE_ITEM == padSlot.type then
    padSlot.type = TYPE_BPMACRO;
    padSlot.linktext = nil;
    padSlot.macrotext = "/use [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] "..padSlot.name;

  elseif TYPE_SPELL == padSlot.type then
    padSlot.macrotext = "/cast [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] "..BindPadCore.GetSpellName(padSlot.name, padSlot.rank);
    padSlot.type = TYPE_BPMACRO;
    padSlot.rank = nil;

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
      BindPadCore.InitBindPad();

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

function BindPadCore.GetMacroIconInfo(index)
  if (not index) then return; end
  local texture = MACRO_ICON_FILENAMES[index];
  if (texture) then
    return "INTERFACE\\ICONS\\" .. texture;
  else
    return nil;
  end
end