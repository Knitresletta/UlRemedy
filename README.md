# UlRemedy

A lightweight quality-of-life collection — twenty-three small utilities in one WoW addon, each individually toggleable with a slash command. Settings persist between sessions.

## Features

**KeyLink** — Links your Mythic Keystone in chat when anyone (including you) types `!key` or `!keys`, responding in the right channel.

**Auto Repair** — Repairs your gear when you open a vendor. Guild bank funds first when they actually cover the cost, your own gold as fallback — and it only reports success once the repair is confirmed.

**Junk Seller** — Sells all grey items when you open a vendor.

**Warband Auto Deposit** — Deposits warbound items into the Warband Bank when you open it (consumables and grey/junk items are skipped). Off by default.

**Group Invite** — Auto-accepts group invites from friends, Battle.net friends and guildmates. Unknown inviters are left for you to handle.

**Enhanced Trainer** — Adds a **Train All** button to profession trainers that learns everything you can afford in one click.

**Item Level Display** — Shows item level on equippable gear in your bags and bank.

**Auto Quest** — Accepts quest offers and turns in completed quests. If there's more than one reward choice, or the turn-in costs gold or currency, the window stays open so you decide yourself.

**Cinematic Skip** — Skips movies and in-game cutscenes you've already seen on any of your characters.

**Auto Gossip** — Clicks through single-option NPC dialogs ("I'm ready", dungeon transport books and the like). Vendors, taxis and multi-option dialogs are never touched.

**Cursor Ring** — A dusty purple ring with a soft silver glow that follows your mouse cursor, visible on light and dark backgrounds alike.

**Auto Companion** — Summons a random favorite battle pet after loading screens if you don't have one out. Never in combat, while dead or stealthed, or in arenas/battlegrounds. Dismissing a pet manually sticks until the next loading screen.

**Auto Marker** — Puts diamond on the tank and moon on the healer in 5-man dungeon groups. Off by default. The independent *Correct Marker on Player* toggle fixes your own mark if another addon or party member sets the wrong one on you — it works even with the main marker off, and never places a mark on its own, only corrects a wrong one.

**Chat Copy** — A small *Copy* button above the chat frame opens the chat log in a window where the text is selected and ready for Ctrl+C. Colour codes and link wrappers are stripped, so what you paste is plain text. `/ur chat` opens it too.

**Playtime** — Remembers `/played` for every character you log in with. `/ur played` opens a window with one bar per class in class colour, longest first, and the total across all characters at the top. Hover a bar to see the characters of that class with level, realm and time. The addon asks the client once a few seconds after login and keeps that answer out of chat; a `/played` you type yourself prints as usual.

**Auto Macro** — Keeps six account macros (General tab, shared by all your characters and rewritten by whoever is logged in) up to date. `UR Heal` is a `/castsequence` chain: the self-heals your class and race know (shortest cooldown first), a Healthstone when you carry one (Soulburn first for a Warlock who has it), then the best healing potion, starting over when combat ends. `UR Mana`, `UR Flask`, `UR Food`, `UR Drink` and `UR Bandage` use the best of each in your bags; food prefers Well Fed food and falls back to whatever restores health, conjured first, and drink works the same for mana. Drag them to your bars once; they are edited in place whenever the bags, talents or spec change, out of combat. The *UR Heal Stops Casting* toggle adds `/stopcasting` for casters. "Best" comes from a ranked list by name (Midnight first, older expansions as fallbacks; best crafting rank wins, Hearty food beats plain, equal flasks go by stack size), with a guess from the item's tooltip for anything unlisted. Feasts are left out. `/ur macrolist` shows what each macro uses and why. The list and the tooltip words are English.

**Inventory** — Remembers gold, bag contents and bank contents for every character you log in with, plus the Warband bank. Hovering an item shows which of your characters have it and whether it sits in their bags or bank, with a total. `/ur inv` opens a browser: pick a character for their items and gold, or *All characters* for every item once with the counts added up and the holders named; search by name. Bags and gold update live, the bank each time you open it. *Forget character* removes someone you no longer play. The tooltip lines have their own toggle, `/ur inventorytooltip`.

**Vendor Window** — A bigger merchant window. Every item the vendor sells is shown in one scrollable grid instead of ten per page, with a search box, a quality filter (all, uncommon+, rare+, epic+), a usable-only checkbox and a sort order (vendor order, name, price, quality). Drag the grip in the bottom-right corner to resize; the size is remembered across characters. Buying works exactly as before (right-click buys, shift-click buys a stack, drag to the cursor), because the grid uses Blizzard's own item slots. The buyback tab uses the same grid. `/ur vendorreset` restores the default size.

**Vendor Bags** — A bag panel docked to the right of the vendor showing everything in your bags. One click sells an item; green and better items ask first, locked items, quest items and items without a vendor value are never sold. Shift-click links an item in chat. A search box dims everything that does not match. While the panel is on, Blizzard's own bags stay closed at vendors; `/ur vendorbags` turns it off to get them back.

**Reminders** — A small panel at the top of the screen that says what you are missing, out of combat only. *Class Reminders*, anywhere: a Rogue without a lethal or non-lethal poison, an Enhancement Shaman without imbues on both weapons (other Shamans oil their weapon like everyone else, since imbue and oil share the slot), a Beast Mastery or Survival Hunter or a Warlock without a pet, and a Mage, Priest, Warrior, Druid or Shaman not wearing their own raid buff. *Instance Reminders*, in Mythic and Mythic+ dungeons and every raid: no flask, not Well Fed, no oil or stone on the weapon, and a warning when one has under ten minutes left; one chat line on entry. Only things your class can actually do are checked. While the game hides buffs from addons (an active Mythic+ key, a boss encounter, combat), the buff-based checks pause instead of guessing; pet and weapon checks keep going. Drag the panel where you want it. `/ur remind` prints what it sees.

**Loot Helper** — For personal loot (items that go through a loot roll are ignored). When a boss drops gear to someone in your group that suits your class and spec and beats what you wear in that slot, a small card pops up with the item so you can ask for a trade. When you get a piece that is not an upgrade for you, the card names the group members it would be an upgrade for, from their spec and the item levels they wear. Cards go away after half a minute or a click; drag one to move the stack, `/ur loottest` shows a sample. Group members are inspected out of combat and in range, when the roster changes and after each boss. `/ur loot` shows what has been read.

**Minimap Button** — One button on the minimap. Left-click opens a menu with the windows that show information: Inventory, Playtime and the chat log. Right-click opens the options window. Drag it around the minimap's edge; the spot is remembered.

Hold **Shift** while interacting to bypass the quest, gossip and cinematic automation for that one interaction.

## Commands

Type `/ur` to open the options window, one checkbox per feature, grouped by Vendor, Group, Quests and Interface. The window can be dragged and closes with Escape. `/ur help` lists every feature and its current state in chat.

| Command | Description |
|---------|-------------|
| `/ur` | Open or close the options window |
| `/ur help` | List every feature and command in chat |
| `/ur chat` | Open the chat log copy window |
| `/ur played` | Open the playtime window |
| `/ur macrolist` | Show what the four auto macros use right now |
| `/ur keylink` | Toggle keystone linking |
| `/ur errors` | Save this session's Lua errors and warnings, and the blocked actions behind the alert icon in the AddOns list (which function, how often, where from), to the saved variables and print a summary. Also done automatically on reload and logout, so a silent failure can be read from `WTF/Account/<account>/SavedVariables/UlRemedy.lua` afterwards. |
| `/ur repair` | Toggle auto repair |
| `/ur junk` | Toggle junk seller |
| `/ur warbank` | Toggle warband auto deposit |
| `/ur groupinvite` | Toggle group invite auto-accept |
| `/ur trainer` | Toggle the trainer Train All button |
| `/ur ilvl` | Toggle item level display |
| `/ur quest` | Toggle quest auto-accept/turn-in |
| `/ur cinematic` | Toggle cinematic skip |
| `/ur gossip` | Toggle auto gossip |
| `/ur cursor` | Toggle the cursor ring |
| `/ur companion` | Toggle auto companion summon |
| `/ur marker` | Toggle auto marker (off by default) |
| `/ur markerfix` | Toggle correcting your own mark (works independently of `marker`) |
| `/ur chatcopy` | Toggle the Copy button by the chat |
| `/ur playtime` | Toggle playtime tracking |
| `/ur macros` | Toggle the auto macros |
| `/ur macrostopcast` | Toggle `/stopcasting` at the top of UR Heal |
| `/ur inventory` | Toggle inventory tracking and the browser |
| `/ur inventorytooltip` | Toggle the inventory lines in item tooltips |
| `/ur vendor` | Toggle the vendor window |
| `/ur vendorbags` | Toggle the bag panel at vendors |
| `/ur loothelper` | Toggle the personal loot helper |
| `/ur minimap` | Toggle the minimap button |
| `/ur reminders` | Toggle class reminders |
| `/ur instancereminders` | Toggle flask, food and weapon reminders in Mythic dungeons and raids |

## Installation

Install via CurseForge, or copy the `UlRemedy` folder into:
```
World of Warcraft/_retail_/Interface/AddOns/
```
