BindPad -- Created by Tageshi

-------------------------------------------------------------------------
1. WHAT IS "BindPad"?
-------------------------------------------------------------------------

BindPad is an addon to make KeyBindings for spells, items, and macros.
You no longer need actionbar slots just to make Key bindings for your macores etc.

BindPad addon provides many icon slots in its frame.  You can drag and drop
anything into one of these slots, and click the slot to set KeyBindings.



-------------------------------------------------------------------------
2. HOW TO USE "BindPad"?
-------------------------------------------------------------------------

  (1) Type /bindpad or /bp to display BindPad frame.
      (Also you can find "Toggle BindPad" Keybinding command in standard
       KeyBindings frame of Blizzard-UI.)

  (2) Open spellbook frame (p), you bag (b), or Macro Panel (/macro).
      (Also you can use three mini-icons on BindPad frame to open these windows.)

  (3) Drag an spell icon, item icon, or macro icon using left button drag and
      drop it onto the BindPad window.
      (Maybe you need shift key + left button drag if action bars are locked.)

  (4) Now you see the icon placed on BindPad frame.  Click it,
      and a dialog window "Press a key to bind" will appear.

  (5) Type a key to bind.  And click 'Close' button.

  (6) When you want to remove icons from BindPad frame, simply drag away the icon
      and press right click to delete it.

      Note that KeyBinding itself will not be unbinded when you delete the icon.
      To unbind it, click the icon and click Unbind button on the dialog window.
      Also you can simply override Keybindings.


-------------------------------------------------------------------------
3. HOW TO USE TABS
-------------------------------------------------------------------------

3.1. SLOTS TABS

There are four tabs called Slots Tab on the top of BindPad frame
(like Blizzard's Macro frame).

[General Slots] is for common icons used for every characters and every specs.
[<Character> Specific Slots] is for icons specific to current character
and current spec.

[2] and [3] (aka. 2nd and 3rd <Character> specific slots) will act
in the same way as [<Character> Specific Slots].


Note that you can use [<Character> Specific Slots] tab only after you click
'Character Specific Key Bindings' check box at standard KeyBindings frame of Blizzard-UI.
From BindPad version 1.5, you can see this checkbox on BindPad window itself too.
(Also BindPad will inform you about 'Character Specific Key Bindings' and automatically
activate it for you when you click [<Character> Specific Slots] tab.)


3.2. PROFILE TABS

There are another three tabs called Profile Tab on the side of BindPad frame.
(like Blizzard's Talent frame)

Different Profile can hold different contents in [<Character> Specific Slots].
You can click a Profile tab to switch current Profile, and your choice of
Profile is saved for each Talent specs and automatically reverted to former
profile when you change talent spec. If you choose same Profile for both
talent specs this automatic change will not happen.

Note that [General Slots] tab is not effected by Profile change, as all
contents of [General Slots] tab is common for all characters AND all specs.
If you change Profile while [General Slots] tab is shown,
BindPad will automatically shows [<Character> Specific Slots] tab of
specified Profile.


3.3. CAN I SWITCH PROFILE IN COMBAT? ON STANCE CHANGE?

No, you cannot.


If you need different skills binded for different stances/forms,
simply use the stance condition to decide on what skill to use.

Example: /cast [stance:1/2] Berserker Stance; [stance:3] Intercept

Where [Stance:1/2] is conditioning the macro for you to be in battle stance
or defensive stance and [stance:3] is conditioning you to be in berserker stance.
This works for all classes with stances (Including rogues for stealth [stance:1]
and shadow dance [stance:2] or none of the previous [stance:0]).

Druid example: /cast [stance:1] Bash; [nostance:1] Healing Touch

[nostance] = Caster, [stance:1] = Bear, [stance:2] = Aquatic, [stance:3] = Cat,
[stance:4] = Travel, [stance:5] = Tree/Moonkin if available else Flight,
[stance:6] = Flight if Tree/Moonkin is not available.



-------------------------------------------------------------------------
4.  "You want to convert this icon into a BINDPAD MACRO?"... What?
-------------------------------------------------------------------------

"BindPad Macro" is a new feature from BidPad version 1.8.0 ;
which allow you to make almost unlimited number of virtual macro icons.

Older versions of BindPad just let you save your limited action bar slots.
This new BindPad will let you save your limited macro slots on the standard
"Create Macro" panel.

Usage:
  - Click the small red "+" icon to create an empty BindPad Macro.
  - Right-click an existing spell/item/macro icon on BindPad to convert it into a BindPad Macro.
  - Right-click the "BindPad Macro" to edit macro-text.
  - ...and you can use left-click to set keybindings as usual.

Note that BindPad Macro will only exist within the BindPad frame;
You can drag-and-drop them within BindPad, but you cannot drop them outside.


-------------------------------------------------------------------------
5.  DETAILS AND MORE INFORMATIONS
-------------------------------------------------------------------------

BindPad addon utilizes new functions added from WoW API 2.0 .

You can use these functions (and many others) in any addons or macros.

  GetBindingKey("command")
  SetBinding("KEY", "command")
  SetBindingSpell("KEY", "Spell Name")
  SetBindingItem("KEY", "itemname")
  SetBindingMacro("KEY", "macroname"|macroid)

Just don't forget to save changes by
  SaveBindings(GetCurrentBindingSet());


There are some other similar addons by other authors.
Try them and choose what you like.

SpellBinder
http://www.wowinterface.com/downloads/info5614-SpellBinder.html

qUserKey
http://wow.curse.com/downloads/wow-addons/details/q-user-key-bind-a-key-to-any-spe.aspx

mBindings
http://www.wowinterface.com/downloads/info11614-2.html

ncBindings
http://www.wowinterface.com/downloads/fileinfo.php?id=15270

ProKeybinds
http://www.wowinterface.com/downloads/fileinfo.php?id=18841


Visit these links for more informations about keybindings and macros.
WoWWiki
http://www.wowwiki.com/Making_a_macro



-------------------------------------------------------------------------
6.  WHERE CAN I GET LATEST VERSION?
-------------------------------------------------------------------------

You can get latest version of BindPad from www.wowinterface.com:

http://www.wowinterface.com/downloads/fileinfo.php?id=6385

Or from Curse:

http://wow.curse.com/downloads/wow-addons/details/bind-pad.aspx



-------------------------------------------------------------------------
7.  CHANGES
-------------------------------------------------------------------------

Version 2.5.6
- Show Hotkeys option is back and now more efficient.
- Show Hotkeys now supports every actionbar addons as far as I know.
- "Show Keys in Tooltip" is included in Show HotKeys option for now.


Version 2.5.5
- Fixed a display bug: "Show Keys in Tooltip" toggle option was
  going to be unchecked at login.


Version 2.5.4
- Fixed Lua error related to AddSpellByID at Mastery tooltip.
- Internal change: replaced StaticPopup_Show with BindPad's own function.


Version 2.5.3
- Added new feature: Show Keys in Tooltip option;
  which adds a text to describe keybindings in tooltip
  for spells, items, and macros on ActionBar and Spellbook.
  (to compensate removal of Show HotKey option.)


Version 2.5.2
- Added new feature: SaveAllKeys option;
  which automatically saves all keys of Blizzard's Key Bindings Interface
  for current BindPad Profile and restore them when switching Profiles.
- Reduced memory consumption by removing empty tables.


Version 2.5.1
- Fixed "script run too long" error.
- Removed broken Show-Hotkeys option which was pertially broken from long before.
- Added support for "Assist" pet skill.
- Added support for battlepet icon.
- Fixed bug: Was unable to pick up class spells from BindPad slot.
- Fixed bug: shift-clicking an icon no longer insert itemlink to BindPad Macro frame
  when you meant to insert the itemlink into an active Chat Frame instead.


Version 2.5.0
- Updated for Mist of Pandaria beta 15799.


Version 2.4.1
- Updated for patch 4.3 .


Version 2.4.0
- Fixed bug: Tooltip for Fishing and First Aid was not correctly shown.
- Added new slash sub-commands to manage profiles.
  /bindpad list : List profiles in saved variables.
  /bindpad delete REALMNAME_CHARACTERNAME : Delete a profile for REALMNAME_CHARACTERNAME.
  /bindpad copyfrom REALMNAME_CHARACTERNAME : Copy a profile from REALMNAME_CHARACTERNAME.


Version 2.3.9
- Updated for 4.1 .
- Added more detailed tooltip text for Profile tabs and Slots tabs.
- BindPad will automatically shows [<Character> Specific Slots] tab
  of specified Profile when you click Profile Tab.
  (To reduce unnecessary confusion, because contents of
   the General Slots tab are common for every Profiles anyway.)
- Trigger on Keydown checkbox is now hidden.
  (It now follows Blizzard's "Cast action keybinds on key down"
   in Combat option.)
- Added support for "Move To" pet skill.
- Added more description about tabs in readme.txt


Version 2.3.8
- Updated for 4.0.6, and fixed huge tab bug.


Version 2.3.7
- Added more error check to repair corrupted variables.


Version 2.3.6
- Added error check for when your pet is dismissed while dragging a pet skill icon.
- Fixed error produced by corrupted variables made by the above error.


Version 2.3.5
- Added support for Pet skills (except Move To).


Version 2.3.4
- Removed (now useless) Fast Trigger option.
  (WoW client patch 4.0.1 introduced "ability queue" system,
   that's why we no longer need Fast Trigger.)
- Fixed a tooltip for zhTW and zhCN localization.


Version 2.3.3
- Actually fixed problem for Feral Charge (Cat Form), Mangle (Cat Form) now.


Version 2.3.1
- Fixed problem for Feral Charge (Cat Form), Mangle (Cat Form) (it's lie!)
- Fixed "Show Hotkeys" for standard ActionBar.
  (May not work for other action bar addons.)


Version 2.3.0
- Now support Cataclysm Beta Build 12857.


Version 2.2.4
- Added a workaround for a strange bug of GetCurrentBindingSet() API function.


Version 2.2.3 (beta)
- 2.2.3 is an experimental version.


Version 2.2.2
- Fixed a bug which breaks keybindings for Downranking spells.


Version 2.2.1
- Fixed a SavedVariable conversion bug introduced in 2.2.0
  which breaks existing keybindings.


Version 2.2.0
- Now all keybindings made by BindPad is triggered on key-down instead of key-up.
  (You can disable this future by a toggle button.)
- Added "Fast Trigger" option toggle button on the Keybinding frame;
  keybindings with this option enabled will be triggered on
  both pressing and releasing a key.
- Fixed a bug which prevent a BindPadMacro to work after converting
  from spell/item/macro icon.
- Fixed a bug which made some broken action string when using
  control+drag to duplicate a BindPadMacro.


Version 2.1.7
- Fixed bug introduced in 2.1.6 which prevented Escape key to close the frame.


Version 2.1.6
- Added support for maximum 31 mouse buttons.
  (for World of Warcraft Gaming Mouse)


Version 2.1.5
- Switching profile is now much faster when both profiles have same keybindings.
- Now allows bindings to left/right mouse button with modifiers.
  (Control+LeftButton etc.)


Version 2.1.4
- Fixed bug: Couldn't use Bronze Drake because its mount name
  is "Bronze Drake Mount" instead of the spell name "Bronze Drake".
- Fixed bug: When you drop two same mount/pet icon on BindPad,
  the second one used wrong name and didn't work.


Version 2.1.3
- Fixed bug: When you bind different keys to same spell/item/macro for
  different profiles, unused keys were not correctly unbinded when
  switching profile; which also caused display problem of tooltip.


Version 2.1.2
- You can duplicate any icon on BindPad by shift-click & drag now.
  So that you can copy icons from a profile tab to another profile tab.
- Fixed bug: BindPadMacro was not updated correctly on switching profile
  when you have BindPadMacro icons with same name on each profile tab.


Version 2.1.1
- Changed behavior of profile tabs; BindPad now remembers which
  profile tab was used for each talent spec.
  Three profile tabs are now equal each other.
- BindPadMacro edit frame now accepts shift-click on spell or items
  to insert as a macro text. (Same as standard macro frame.)


Version 2.1.0
- Added three profile tabs; switching profile will
  save & load whole character specific icons and their keybindings.
- First two of the three profile tabs are linked to Dual Spec of
  WotLK 3.1.0, and will be automatically switched when you swtich spec.
- The third profile tab is just an extra.
- All character specific icons and keybindings are duplicated at the
  first time you use a profile.


Version 2.0.2b
- Fixed: Modifier keys couldn't be used for keybinding of BindPadMacro.


Version 2.0.1
- Correctly support spells which have a pair of bracket in its name;
  For example, "Faerie Fire (Feral)", "Swipe (Cat)"


Version 2.0.0
- Updated for WotLK 3.1.0
- You can drag&drop companion icons and use it as a BindPadMacro. (WotLK 3.1.0 only)
- You can drag&drop new equipmentset icons from Equiment Manager too. (WotLK 3.1.0 only)

- Changed keybinding name of BindPadMacro; now it sees like "BindPadMacro:<name>" instead of "BindPadMacro101:" etc.
- Now you can use "/click BindPadMacro <name>" slash command to run the BindPadMacro from within a macro.
- Added various error checks to avoid calling protected functions in combat.
- Fixed: BindPadMacro text was sometimes overwritten by different icon's macro text.


Version 1.9.1
- Release for 3.0.2


Version 1.9.0
- Updated for WotLK beta


Version 1.8.6
- Fixed a drawing order problem of "Show Hotkeys"
  for Bartendar4 and probably for Bartendar3.
- Added locatization for zhCN and zhTW. (Thanks xinsonic)


Version 1.8.5
"Show Hotkeys" now supports Bartendar4.


Version 1.8.4
Added a workaround for error message "GetSpellName(): Invalid spell slot".


Version 1.8.3
- (Really) fixed the display issue of "Show Hotkeys" on compatibility with Bongos3.
- Added "Test" button on the BindPad Macro frame to test the macro while editing.
- Improved the keybinding confirmation window when the key is already
  bound to a BindPad Macro.

Version 1.8.2
Fixed a bug which sometimes prevented BindPad to detect correct spell
rank after respeccing talent or training new spells.


Version 1.8.1
Fixed display issue of "Show Hotkeys" function introduced in 1.7.1; Compatibility with Bongos3 fixed.
(EDIT: Actually it was not yet fixed.)


Version 1.8.0

"BindPad Macro" : New feature to make almost unlimited number of virtual macro icons.
BindPad Macro is made for you to save limited macro slots on the standard Blizzard UI.
BindPad Macro will only exist within the BindPad frame, and allow you to make keybindings on them.

  - Click the small red "+" icon to create an empty BindPad Macro.
  - Right-click an existing spell/item/macro icon on BindPad frame to convert it into a BindPad Macro.
  - Right-click the "BindPad Macro" to edit macro-text.
  - ...and you can use left-click to set keybindings as usual.


Version 1.7.1
Added an option checkbox "Show Hotkeys".
The hotkey function now supports all ActionBar AddOns in addition to Blizard UI.
(Only tested for Bartendar3 addon.)


Version 1.7.0
Added an ability to automatically display binded hotkeys on ActionBar buttons.
(Suggested by Pheon)


Version 1.6.1
Updated for WoW client 2.3.0 .
Fixed a bug causing macro icons sometimes not working.


Version 1.6
Added two extra tabs for heavy users.


Version 1.5.1
TOC update.


Version 1.5
TOC update.
Added the 'Character Specific Key Bindings' check box at upper right corner of BindPad frame.
Added some functions to inform about 'Character Specific Key Bindings'.


Version 1.4
TOC update.
Added three mini-icons to open Spellbook, Macros Panel, and All bags.
Now uses new GetCursorInfo() API. (Slouken have kindly added it for me.)
You can now drag&drop icons from Action Bars too.
You can now use mouse wheel up/down as a keybind.


Version 1.3 (Now really updated version):
Added slash command /bindpad and /bp


Version 1.2 (not uploaded!):
More bug fixes.
Savefile format was changed and not compatible to 1.0 and 1.1.
(Old save data will be deleted when you use version 1.2; that don't unbind but you need to drag icons again.)


Version 1.1 (not uploaded!):
Fixed some tainting bug.


Version 1.0
Initial release.
