# UlRemedy — Code Review

**Date:** 2026-05-04
**Reviewed by:** Multi-agent review (Logic & Correctness · Structure & Maintainability · Safety & Robustness)

---

## 🔴 Critical

**1. `AutoJunkSeller.lua:9–13` — Quest items and locked items not checked before selling**
Grey-quality quest items exist in WoW. `GetContainerItemInfo` returns `isQuestItem` and `isLocked` flags that are never checked. `UseContainerItem` on a quest item sells it permanently. This is a data-loss bug.
```lua
-- add before the vendorPrice check:
if info.isLocked or info.isQuestItem then ... end  -- skip
```

**2. `AutoJunkSeller.lua:13` — `UseContainerItem` triggers on-use effect for grey items with explicit on-use**
Rare but real: some grey items have on-use actions. At a vendor, `UseContainerItem` *should* sell — but for items with an explicit on-use effect, the client may fire the use action instead. No item-type guard exists.

**3. `KeyLink.lua:30` — Nil crash on `UlRemedy.enabled` if a chat event fires before `ADDON_LOADED`**
If you're in a party at login, `CHAT_MSG_PARTY` fires before `ADDON_LOADED` completes. `UlRemedy.enabled` is `nil` at that point → `UlRemedy.enabled.keylink` throws `attempt to index a nil value`. Hard crash, no recovery.
Fix: guard `if not UlRemedy.enabled or not UlRemedy.enabled.keylink then return end`, or better — pre-populate `UlRemedy.enabled` with DEFAULTS at table declaration in `Core.lua` so it's never nil.

**4. `KeyLink.lua:4–10` — `CHAT_MSG_RAID_LEADER` and `CHAT_MSG_PARTY_LEADER` are not real WoW events**
These events do not exist in the WoW client. `RegisterEvent` silently ignores them — they never fire. If the intent was to detect when a *leader* sends `!keys`, this is completely broken (it responds to everyone via the valid events). If the intent is respond-to-anyone, remove the dead entries.

---

## 🟡 Important

**5. `AutoJunkSeller.lua:10` — `GetItemInfo` cache miss silently skips junk items**
On first login or after `/reload`, item data may not be cached. `GetItemInfo` returns nil → `vendorPrice = 0` → item skipped with no feedback. The player thinks junk was sold when it wasn't.
Fix: call `C_Item.RequestLoadItemDataByID(info.itemID)` for uncached items and listen for `GET_ITEM_INFO_RECEIVED` to retry, or at minimum print a warning listing what was skipped.

**6. `AutoGuildRepair.lua:5–7` — Fails *open* on guild bank when `GetGuildBankWithdrawMoney` is unavailable**
If the API doesn't exist (future patch, early load), `CanPayWithGuild` returns `true` and proceeds to spend guild funds. That's the wrong safe default. Should return `false` when the limit can't be determined.

**7. `AutoGuildRepair.lua:15` — `GetRepairAllCost()` second return value `canRepair` ignored**
The function returns `(cost, canRepair)`. `CanMerchantRepair()` provides partial cover, but the proper check is:
```lua
local cost, canRepair = GetRepairAllCost()
if not canRepair or not cost or cost <= 0 then return end
```

**8. `KeyLink.lua:31` — No self-sender check; addon can respond to its own messages**
`SendChatMessage` echoes back as a chat event. If the addon (or another addon) sends `!keys`, the frame will catch it and reply again. Fix: `if sender == UnitName("player") then return end`.

**9. `KeyLink.lua:33` — Silent no-op when no keystone found or hyperlink is uncached**
A party member types `!keys`, gets no response. No indication of whether the keystone is missing or just not cached yet. Add a reply in the same channel: `"No keystone found."` / `"Keystone data not yet loaded, try again."`.

**10. `KeyLink.lua` — No rate-limit on `!keys` replies**
Multiple players spamming `!keys` triggers WoW's server-side chat throttle and silently drops the legitimate reply. Add a `GetTime()`-based cooldown (e.g. 3 seconds between replies).

**11. `WarbankAutoDeposit.lua:13` — `BANKFRAME_OPENED` reset of `hasDeposited` enables duplicate deposits**
If `BANKFRAME_OPENED` fires without a preceding `BANKFRAME_CLOSED` (UI quirks, some addon interactions), `hasDeposited` is reset to false and a second deposit fires. The reset belongs only in `BANKFRAME_CLOSED`. Remove it from the `BANKFRAME_OPENED` branch.

**12. `Core.lua:15` — `UlRemedy.enabled` is nil until `ADDON_LOADED` fires**
Every module guards with `if not UlRemedy.enabled.X` — which crashes if `enabled` itself is nil (see #3). The safest fix is to make `enabled` always valid at table creation:
```lua
UlRemedy = { name = "UlRemedy", enabled = { keylink=true, repair=true, junk=true, warbank=false } }
```
`InitDB` can still sync from SavedVariables on top of this.

---

## 🟢 Suggestions

**13. All modules — Anonymous frames make debugging painful**
`CreateFrame("Frame")` with no name shows up as unnamed in `/framestack`, Bugsack, and profilers. Name them: `CreateFrame("Frame", "UlRemedyKeyLinkFrame")` etc.

**14. All modules — `UlRemedy.name .. ": "` duplicated in every print statement**
One helper in `Core.lua` eliminates the repetition and makes future prefix changes a one-line edit:
```lua
function UlRemedy.Print(msg) print(UlRemedy.name .. ": " .. msg) end
```

**15. `WarbankAutoDeposit.lua:21` — Success print fires before async deposit confirms**
`AutoDepositItemsIntoBank` is async. The print on line 21 fires immediately, before items actually move. Move the print into the `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` handler where you know something changed.

**16. `Core.lua:1` — `name = ...` is fragile; prefer a string literal**
`UlRemedy = { name = "UlRemedy" }` is explicit and won't silently break if the file is ever loaded outside the WoW addon loader (e.g. in tests or tools).

**17. `AutoJunkSeller.lua:22` — "Sold N junk item(s)" counts units, not stacks**
Selling one stack of 20 grey items prints "Sold 20 junk item(s)." Consider "Sold 5 stacks (20 items)..." for clarity.

**18. `Core.lua:InitDB` — No stale key pruning between addon versions**
`InitDB` adds missing keys but never removes keys that no longer exist. Old feature keys linger in `UlRemedyDB` forever. Add a pruning pass keyed against DEFAULTS.

**19. `KeyLink.lua:14`, `AutoJunkSeller.lua:6` — `NUM_BAG_SLOTS` vs `C_Container.NUM_TOTAL_EQUIPPED_BAG_SLOTS`**
Both evaluate to 4 in TWW. The latter is consistent with the `C_Container.*` API you're already using everywhere else.

---

**Verdict: critical blockers.** The quest item sell bug (#1) is a real data-loss risk, and the KeyLink nil crash (#3) will hit any player who logs in while already in a group. Fix those two before this goes on Curseforge.
