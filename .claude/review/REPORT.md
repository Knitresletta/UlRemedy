# UlRemedy — Code Review Report
**Date:** 2026-05-04
**Reviewed by:** Multi-agent review (Logic & Correctness · Structure & Maintainability · Safety & Robustness)

---

## 🔴 Critical

**1. `KeyLink.lua:30` — Nil crash on `UlRemedy.enabled` before `ADDON_LOADED`** *(Logic & Correctness, Safety & Robustness)*

All feature frames register their events at file-load time, before `ADDON_LOADED` fires and before `InitDB()` populates `UlRemedy.enabled`. Chat events (`CHAT_MSG_PARTY`, etc.) can arrive before `ADDON_LOADED` on `/reload` when the player is already in a group. When they do, line 30 in KeyLink.lua hits `UlRemedy.enabled.keylink` on a nil table → hard crash: `attempt to index a nil value (field 'enabled')`.

Fix: add `if not UlRemedy.enabled then return end` at the top of every feature handler — or pre-populate `UlRemedy.enabled` with `DEFAULTS` at table creation in Core.lua so it is never nil:
```lua
UlRemedy = { name = "UlRemedy", enabled = { keylink=true, repair=true, junk=true, warbank=false } }
```
`InitDB` can still sync from `UlRemedyDB` on top of this; the pre-populated table just closes the nil-window.

---

**2. `AutoJunkSeller.lua:9` — Quest and locked items not checked before selling** *(Safety & Robustness)*

`GetContainerItemInfo` returns `isQuestItem` and `isLocked` flags that are never inspected. `UseContainerItem` on a quest item at a vendor sells it permanently — this is a real data-loss bug. Some grey-quality quest items exist in WoW.

Fix:
```lua
if info.isLocked or info.isQuestItem then
    -- skip
else
    -- existing sell logic
end
```

---

## 🟡 Important

**3. `AutoJunkSeller.lua:10` — `GetItemInfo` cache miss silently skips junk** *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*

`GetItemInfo` is asynchronous. On a fresh login or after `/reload`, item data may not be in the client cache. The return is all nils, `vendorPrice` becomes 0, and the item is silently skipped. No feedback to the player — they believe junk was sold when it wasn't. There is no retry mechanism, so those items stay in the bag until the next vendor visit.

Approaches: (a) use `GetItemInfoInstant` for a synchronous quality check then only call `GetItemInfo` when you know the data is hot, or (b) call `C_Item.RequestLoadItemDataByID(info.itemID)` and listen for `ITEM_DATA_LOAD_RESULT` to retry, or (c) at minimum print which items were skipped.

---

**4. `AutoJunkSeller.lua:13` — `UseContainerItem` without active-merchant guard** *(Logic & Correctness)*

The bag loop starts on `MERCHANT_SHOW` but iterates over multiple slots. If the merchant window closes between iterations (disconnection, another event), `UseContainerItem` on a grey item without an open vendor may trigger an on-use effect rather than a sale. Add a `MerchantFrame:IsShown()` check inside the loop before each call, or break early if the frame closes.

---

**5. `WarbankAutoDeposit.lua:13` — Redundant reset and missing early return on `BANKFRAME_OPENED`** *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*

The `BANKFRAME_CLOSED` handler already resets `hasDeposited = false`. The identical reset inside the `BANKFRAME_OPENED` branch is dead code. More importantly, there is no `return` after the reset, so the handler falls through to the deposit logic on the same event. This means `BANKFRAME_OPENED` always triggers a deposit immediately (bypassing the `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` retry path), and the intent of the `hasDeposited` guard is obscured.

Fix: add `return` after the `BANKFRAME_OPENED` reset and let `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` be the trigger for the actual deposit attempt. Remove the duplicate reset from `BANKFRAME_OPENED` entirely.

---

**6. `WarbankAutoDeposit.lua:21` — Async deposit success message** *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*

`C_Bank.AutoDepositItemsIntoBank` is asynchronous. The print on line 21 fires immediately, before any items have actually moved — and fires even when there is nothing eligible to deposit. `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` (already registered) fires only when slots actually change; moving the print there would make it accurate.

---

**7. `AutoGuildRepair.lua:5` — Guild repair fails open when `GetGuildBankWithdrawMoney` is unavailable** *(Structure & Maintainability)*

If `GetGuildBankWithdrawMoney` doesn't exist (future API change, patched out), `CanPayWithGuild` returns `true` and repair proceeds using guild funds. The correct safe default is `false` — if the limit cannot be determined, fall back to personal gold:
```lua
if not GetGuildBankWithdrawMoney then
    return false  -- not true
end
```

---

**8. `AutoGuildRepair.lua:15` — `GetRepairAllCost()` second return ignored** *(Logic & Correctness, Safety & Robustness)*

`GetRepairAllCost()` returns `(cost, canRepair)`. The `canRepair` flag is never captured. `CanMerchantRepair()` partially covers this but is not equivalent. Explicit check:
```lua
local cost, canRepair = GetRepairAllCost()
if not canRepair or not cost or cost <= 0 then return end
```

---

**9. `KeyLink.lua:34` — No rate-limit on `SendChatMessage`** *(Logic & Correctness)*

Every `!keys` from any player in any registered channel triggers a `SendChatMessage`. In a busy instance or raid, multiple simultaneous triggers hit Blizzard's server-side chat throttle and the legitimate reply is silently dropped. A `GetTime()`-based cooldown (e.g. refuse to reply within 5 seconds of the last reply) prevents this.

---

**10. `KeyLink.lua:31` — `!keys` check is case-sensitive and untrimmed** *(Safety & Robustness)*

`message == "!keys"` fails for `!Keys`, `!KEYS`, or `!keys ` (trailing space). Add `:lower():match("^!keys%s*$")` or equivalent.

---

**11. `KeyLink.lua:13` — `FindKeystone` may return an empty string hyperlink** *(Safety & Robustness)*

`GetContainerItemInfo` can return `hyperlink = ""` for items whose data isn't fully loaded. `if link then` is truthy for an empty string, so `SendChatMessage("", channel)` is called silently. Guard with `if link and link ~= "" then`.

---

**12. `Core.lua:1` — `name = ...` vararg is fragile** *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*

`...` captures the addon name from the WoW TOC loader — a valid WoW pattern, but silent and non-obvious. If `name` is nil (file loaded outside the WoW loader), every `UlRemedy.name` reference across all modules fails quietly. The explicit `name = "UlRemedy"` is equally correct, immediately readable, and safe.

---

**13. `WarbankAutoDeposit.lua:6` — `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` registered but not used for confirmation** *(Logic & Correctness)*

The event is registered (correctly — it fires when items actually move) but the handler never reaches the print via this event path: by the time `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` fires, `hasDeposited` is already `true` and the handler returns early. Either remove the event registration if unused, or restructure so `BANKFRAME_OPENED` arms the system and `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` actually performs the deposit and prints confirmation.

---

## 🟢 Suggestions

**14. All feature files — Anonymous frames**
All five `CreateFrame("Frame")` calls have no name. Named frames (`"UlRemedyKeyLinkFrame"`, etc.) show up correctly in `/framestack`, Bugsack traces, and profilers.

**15. `KeyLink.lua:14` / `AutoJunkSeller.lua:6` — Bag loop duplicated, reagent bag excluded**
The `for bag = 0, NUM_BAG_SLOTS` pattern appears in two files with no comment. The Reagent Bag (slot 5) is excluded — fine for keystones, but grey crafting reagents in that bag won't be sold. Centralise the bag iteration or use `C_PlayerInfo.GetPlayerSlottedBagSlots()`.

**16. `Core.lua:25` — Feature keys stringly typed across three locations**
`"keylink"`, `"repair"`, `"junk"`, `"warbank"` are duplicated across `FEATURES`, `DEFAULTS`, and every feature file's `UlRemedy.enabled.*` access. A shared `UlRemedy.KEYS` constant table makes future renames safe.

**17. `Core.lua:InitDB` — No stale key pruning**
`InitDB` adds missing keys but never removes keys that no longer exist in `DEFAULTS`. Old feature keys accumulate in `UlRemedyDB` across addon versions. Add a pruning pass:
```lua
for k in pairs(UlRemedyDB) do
    if DEFAULTS[k] == nil then UlRemedyDB[k] = nil end
end
```

---

## Verdict

**Critical blockers present.** The nil crash in KeyLink (#1) will hit any player who reloads while in a group. The quest-item sell bug (#2) is a real data-loss risk. Both must be fixed before publishing to CurseForge. Issues #5 and #6 (WarbankAutoDeposit control flow and async print) also warrant fixing in the same pass. The remaining Important items are quality improvements that significantly improve robustness but are not release-blockers.
