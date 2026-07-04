# UlRemedy

A lightweight quality-of-life collection — eleven small utilities in one WoW addon, each individually toggleable with a slash command. Settings persist between sessions.

## Features

**KeyLink** — Links your Mythic Keystone in chat when anyone (including you) types `!keys`, responding in the right channel.

**Auto Repair** — Repairs your gear when you open a vendor. Guild bank funds first, your own gold as fallback.

**Junk Seller** — Sells all grey items when you open a vendor.

**Warband Auto Deposit** — Deposits warbound items into the Warband Bank when you open it (consumables are skipped). Off by default.

**Group Invite** — Auto-accepts group invites from friends, Battle.net friends and guildmates. Unknown inviters are left for you to handle.

**Enhanced Trainer** — Adds a **Train All** button to profession trainers that learns everything you can afford in one click.

**Item Level Display** — Shows item level on equippable gear in your bags and bank.

**Auto Quest** — Accepts quest offers and turns in completed quests. If there's more than one reward choice, the window stays open so you pick yourself.

**Cinematic Skip** — Skips movies and in-game cutscenes you've already seen on any of your characters.

**Auto Gossip** — Clicks through single-option NPC dialogs ("I'm ready", dungeon transport books and the like). Vendors, taxis and multi-option dialogs are never touched.

**Cursor Ring** — A dusty purple ring with a soft silver glow that follows your mouse cursor, visible on light and dark backgrounds alike.

Hold **Shift** while interacting to bypass the quest, gossip and cinematic automation for that one interaction.

## Commands

Type `/ur` to list every feature and its current state.

| Command | Description |
|---------|-------------|
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
