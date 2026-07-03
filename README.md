# UlRemedy

A lightweight WoW utility addon combining eleven quality-of-life features into one. All features are toggleable via `/ur` commands and settings persist between sessions.

## Features

**KeyLink** — Automatically links your Mythic Keystone in chat when anyone (including you) types `!keys`. Responds in the correct channel (say, party, raid, instance chat).

**Auto Repair** — Repairs your gear automatically when you open a vendor. Prioritizes guild bank funds, falls back to personal gold.

**Junk Seller** — Automatically sells all grey (poor quality) items when you open a vendor.

**Warband Auto Deposit** — Deposits warbound items into your Warband Bank automatically when you open it (consumables are skipped). Runs once per bank session.

**Group Invite** — Automatically accepts group invitations from friends and guild members. Unknown inviters are ignored for manual handling.

**Enhanced Trainer** — Adds a **Train All** button to the profession trainer window that trains every available skill you can afford in one click, and tells you if any were skipped for lack of gold.

**Item Level Display** — Shows the item level on equippable gear (weapons and armor) in your bags and bank.

**Auto Quest** — Accepts quest offers and turns in completed quests automatically. Quests with more than one reward choice stay open so you pick the reward yourself. Hold **Shift** while talking to an NPC to bypass the automation.

**Cinematic Skip** — Skips movies and in-game cutscenes you have already seen on any character. Hold **Shift** as one starts to watch it again.

**Auto Gossip** — Clicks through NPC dialog automatically — "I'm ready" prompts, dungeon transports and similar — when it's safe: exactly one plain chat option and no quests on the NPC. Vendors, taxis and multi-option dialogs are never touched. Hold **Shift** to leave the dialog open.

**Cursor Ring** — A dusty purple ring that follows your mouse cursor, with a dark outline and a faint silver glow so it stays visible on both light and dark backgrounds.

## Commands

| Command | Description |
|---------|-------------|
| `/ur` | List all commands and current status |
| `/ur keylink` | Toggle keystone linking |
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

## Installation

Install via CurseForge, or copy the `UlRemedy` folder into:
```
World of Warcraft/_retail_/Interface/AddOns/
```
