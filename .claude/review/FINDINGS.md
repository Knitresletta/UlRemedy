# Review Findings — UlRemedy — 2026-05-14 (Round 2: in-game testing)

> Run `/team-staging` to fix these automatically.

## 🔴 Critical

- [x] `KeyLink.lua:4-10` — Regresjonsfix: `CHAT_MSG_PARTY_LEADER` og `CHAT_MSG_RAID_LEADER` ble fjernet i forrige runde basert på feil informasjon — disse eventene eksisterer faktisk og fyrer når party-/raid-LEDEREN snakker. Resultat: KeyLink svarer ikke når lederen (typisk keyholderen) skriver `!keys`. Legg tilbake i `EVENT_TO_CHANNEL`: `CHAT_MSG_PARTY_LEADER = "PARTY"` og `CHAT_MSG_RAID_LEADER = "RAID"`. *(Logic & Correctness)*

- [x] `WarbankAutoDeposit.lua:21` — Consumables (f.eks. Hearty Feast) blir auto-deponert i warband bank fordi `C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)` respekterer Blizzards tab-flagg for Consumables. Erstatt med manuell loop: iterer bager 0..`C_Container.NUM_TOTAL_EQUIPPED_BAG_SLOTS`, hopp over `info.classID == Enum.ItemClass.Consumable`, sjekk `C_Bank.IsItemAllowedInBankType(location, Enum.BankType.Account)`, finn tom slot via `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)` + `C_Container.GetContainerNumSlots`, og flytt med `C_Container.PickupContainerItem` (pickup + drop). Bruk `ClearCursor()` rundt operasjonene. *(Logic & Correctness)*

## 🟡 Important

- [x] `AutoGuildRepair.lua:18-26` — Print-meldingen lyver om kilde til repair-gull. `GetGuildBankWithdrawMoney()` returnerer spillerens daglige withdraw-grense, ikke guild bank-saldoen. Hvis banken er tom men grensen høy, kaller `RepairAllItems(true)` Blizzards API som bruker guild for det den kan og personlig gull for resten — men vi printer "Repaired with guild funds". Fix: snapshot `GetMoney()` før `RepairAllItems`, regn ut `spentPersonal = before - GetMoney()` og `spentGuild = cost - spentPersonal`, print én av tre meldinger basert på faktisk gold-delta: kun guild, blandet (guild X / personal Y), eller kun personal. *(Logic & Correctness)*

- [x] `AutoGroupInvite.lua:18-26` — `GetNumGuildMembers()` returnerer 0 til guild-rosteret er lastet (få sekunder etter login eller reload). Hvis en guildie inviterer rett etter login, avvises auto-accept. Fix: registrer `PLAYER_LOGIN`-event i AutoGroupInvite-framen og kall `C_GuildInfo.GuildRoster()` ved login for å trigge en refresh. *(Logic & Correctness)*

- [x] `AutoGroupInvite.lua:31-37` — Ingen rate-limit på auto-accept; spam-invites blir alle akseptert. Legg til `lastAccept = 0` modul-lokal + 3 sek cooldown via `GetTime()` før `AcceptGroup()`. *(Safety & Robustness)*

## 🟢 Suggestions

- [x] `Core.lua:51` — Legg til `SLASH_ULREMEDY2 = "/ulremedy"` som lang-alias for `/ur` — discoverability for nye brukere som ikke gjetter den korte forma. *(Structure & Maintainability)*
