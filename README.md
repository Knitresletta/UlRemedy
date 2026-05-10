# UlRemedy

A lightweight WoW utility addon combining five quality-of-life features into one. All features are toggleable via `/ur` commands and settings persist between sessions.

## Features

**KeyLink** — Automatically links your Mythic Keystone in chat when someone types `!keys`. Responds in the correct channel (say, party, raid, instance chat).

**Auto Repair** — Repairs your gear automatically when you open a vendor. Prioritizes guild bank funds, falls back to personal gold.

**Junk Seller** — Automatically sells all grey (poor quality) items when you open a vendor.

**Warband Auto Deposit** — Deposits warbound equipment and reagents into your Warband Bank automatically when you open it. Runs once per bank session.

**Group Invite** — Automatically accepts group invitations from friends and guild members. Unknown inviters are ignored for manual handling.

## Commands

| Command | Description |
|---------|-------------|
| `/ur` | List all commands and current status |
| `/ur keylink` | Toggle keystone linking |
| `/ur repair` | Toggle auto repair |
| `/ur junk` | Toggle junk seller |
| `/ur warbank` | Toggle warband auto deposit |
| `/ur groupinvite` | Toggle group invite auto-accept |

## Installation

Install via CurseForge, or copy the `UlRemedy` folder into:
```
World of Warcraft/_retail_/Interface/AddOns/
```
