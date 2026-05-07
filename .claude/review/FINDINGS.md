# Review Findings — UlRemedy — 2026-05-04

> Run `/team-staging` to fix these automatically.

## 🔴 Critical

- [x] `KeyLink.lua:30` — `UlRemedy.enabled` is nil if a chat event fires before `ADDON_LOADED` (e.g. on `/reload` while in a group); causes hard crash `attempt to index a nil value`. *(Logic & Correctness, Safety & Robustness)*
- [x] `AutoJunkSeller.lua:9` — `info.isQuestItem` and `info.isLocked` are never checked before calling `UseContainerItem`; selling a quest item is permanent data loss. *(Safety & Robustness)*

## 🟡 Important

- [x] `AutoJunkSeller.lua:10` — `GetItemInfo` is async; returns all nils on cache miss, silently skipping junk items with no feedback to the player. *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*
- [x] `AutoJunkSeller.lua:13` — `UseContainerItem` called in a loop with no check that the merchant window is still open; if vendor closes mid-loop, item may be equipped or trigger an on-use effect. *(Logic & Correctness)*
- [x] `WarbankAutoDeposit.lua:13` — `hasDeposited = false` reset inside `BANKFRAME_OPENED` is redundant (`BANKFRAME_CLOSED` already resets it) and the fall-through without an early `return` makes the control flow fragile. *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*
- [x] `WarbankAutoDeposit.lua:21` — success message printed immediately after calling the async `C_Bank.AutoDepositItemsIntoBank`; fires even if nothing was deposited. *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*
- [x] `AutoGuildRepair.lua:5` — if `GetGuildBankWithdrawMoney` is unavailable, `CanPayWithGuild` returns `true` and spends guild funds anyway; wrong safe default. *(Structure & Maintainability)*
- [x] `AutoGuildRepair.lua:15` — `GetRepairAllCost()` returns `(cost, canRepair)`; only `cost` is captured. Should also check `canRepair` explicitly. *(Logic & Correctness, Safety & Robustness)*
- [x] `KeyLink.lua:34` — no rate-limit on `SendChatMessage`; multiple players spamming `!keys` can trigger Blizzard's chat throttle and silently drop the reply. *(Logic & Correctness)*
- [x] `KeyLink.lua:31` — `!keys` check is case-sensitive and not trimmed; `!Keys` or `!keys ` (trailing space) will not trigger a response. *(Safety & Robustness)*
- [x] `KeyLink.lua:13` — `FindKeystone` returns `info.hyperlink` which can be an empty string `""` for items not yet fully loaded; `if link then` passes for `""` and `SendChatMessage("", channel)` is called silently. *(Safety & Robustness)*
- [x] `Core.lua:1` — `name = ...` reads the WoW TOC vararg; silently becomes `nil` if the file is ever loaded outside the TOC loader, breaking every `UlRemedy.name` reference. *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*
- [x] `WarbankAutoDeposit.lua:6` — `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` is registered but never used to confirm the deposit completed; the print fires before any slot changes, and the event itself is a no-op due to `hasDeposited` already being `true`. *(Logic & Correctness)*

## 🟢 Suggestions

- [x] `KeyLink.lua:25` / `AutoGuildRepair.lua:29` / `AutoJunkSeller.lua:26` / `WarbankAutoDeposit.lua:2` / `Core.lua:60` — all five frames are anonymous; name them (e.g. `"UlRemedyKeyLinkFrame"`) for debuggability in `/framestack` and error traces. *(Structure & Maintainability)*
- [ ] `KeyLink.lua:14` / `AutoJunkSeller.lua:6` — bag loop uses `NUM_BAG_SLOTS` (= 4) in two places; excludes the Reagent Bag (slot 5). Keystones can't go there, but grey reagents can. Centralise the constant or use `C_PlayerInfo.GetPlayerSlottedBagSlots()`. *(Logic & Correctness, Structure & Maintainability, Safety & Robustness)*
- [ ] `Core.lua:25` — feature keys (`"keylink"`, `"repair"`, `"junk"`, `"warbank"`) are stringly-typed and duplicated across `FEATURES`, `DEFAULTS`, and all feature files; a single `UlRemedy.KEYS` table would make renames safe. *(Structure & Maintainability)*
- [ ] `AutoGuildRepair.lua:15` — `GetRepairAllCost` second return `canRepair` ignored (partially covered by `CanMerchantRepair` but not fully equivalent). *(Logic & Correctness)*
- [x] `Core.lua:InitDB` — `InitDB` adds missing keys from `DEFAULTS` but never prunes keys that no longer exist; stale feature keys accumulate in `UlRemedyDB` across addon versions. *(Logic & Correctness)*
