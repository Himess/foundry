# BUNDLE-AUDITS — Aztec audit-reports dedup (ATP / staker / milestone / revocation / vesting)

Source repo: **`AztecProtocol/audit-reports`** @ `b3b60cefe2d136763d841957daa5e9bfcff0421f` (2026-04-06, default branch HEAD).
Cloned `--depth 1` (no `--recursive`). All reports are PDFs; text extracted with PyMuPDF, image-only PDF (ZKSecurity TGE) read via rendered-page OCR.

**Scope of this bundle:** every finding touching **ATP / MATP / LATP / staker / `withdrawAllTokensToBeneficiary` / milestone / revocation / vesting / unlock-schedule-bypass**. The two **TGE reports are extracted in full** (all findings). The two ATP-relevant `l1-contracts` reports (Protocol Treasury, Staking Registry) are included with on-topic findings. Reports with **no** ATP/vesting findings are listed under §5 for completeness.

> ⚠️ The TGE audits reviewed the historical private **`teegeeee`/`aztec-teegeee`** repo (pre-public). Its contracts are the direct ancestors of the current public `ignition-contracts/src/` ATP cluster (BUNDLE-A). File paths and function names referenced below (`src/atps/...`, `upgradeStaker`, `LATPCore`, `MATPCore`, `LockLib`) map onto today's `ignition-contracts/src/token-vaults/atps/...`, `staking/`, `staking-registry/`, and `libraries/LockLib.sol`. Treat severities/fix-status as historical context for dedup, not a verdict on the current bounty commit.

---

## NAVIGATION

```
1  — Report index (dedup table)
2  — ZKSecurity — "Audit of Aztec's TGE Contract" (FULL, 3 findings)
3  — Spearbit — "Aztec teegeee Security Review" (FULL, 22 findings)
4  — Cantina l1-contracts reports with ATP/staker findings (Protocol Treasury, Staking Registry)
5  — Reports scanned with NO ATP/staker/vesting findings
```

---

## 1 — Report index (dedup table)

| # | Report | Auditor | Target repo @ commit | Date | Findings (C/H/M/L/Gas/Info) | ATP-relevant |
|---|--------|---------|----------------------|------|------------------------------|--------------|
| R1 | Audit of Aztec's TGE Contract | **ZKSecurity** | `AztecProtocol/teegeeee` @ `8432c82584731813a2197dd3b715ba2db0dbe3f9` | 2025-02-24 | 0/1/0/0/0/2 = **3** | ✅ ALL |
| R2 | Aztec teegeee Security Review | **Spearbit / Cantina** | `aztec-teegeee` @ `8062e3a6` | 2025-02-25→28 (rep. 03-17) | 0/1/0/4/1/16 = **22** | ✅ ALL |
| R3 | Cantina — Protocol Treasury | **Cantina** (R0bert) | `ignition-monorepo` @ `2a2c7909` | 2025-11-10→11 | 0/0/0/1/1/2 = **4** | ✅ 1 (ATP gate) |
| R4 | Cantina — Staking Registry | **Cantina** | `ignition-monorepo` @ `c9efabac` | 2025-08-22→29 | 0/0/1/2/4/4 = **11** | ✅ staking/withdrawal |
| — | 14 other reports (governance, rollup, barretenberg, etc.) | various | aztec-packages / barretenberg | — | — | ❌ none (see §5) |

**Cross-report dedup — the single recurring high-severity theme:**
> **`upgradeStaker` arbitrary-staker takeover → unlock-schedule bypass.** Found *independently* by **ZKSecurity (R1 #00, High)** and **Spearbit (R2 5.1.1, High)**. Same root cause: the beneficiary-supplied `_initdata` to `upgradeStaker` is unrestricted, so it can embed a *second* `upgradeToAndCall` (nested delegatecall) that points the staker proxy at an attacker implementation, draining locked/staked tokens and defeating the vesting lock. Both reported fixed (Aztec commit `2aac8775`). **This is the marquee item for the ATP cluster** — verify whether the current bounty-commit `ATPWithdrawable*Staker` / `BaseStaker` upgrade path reintroduces it.

---

## 2 — ZKSecurity: "Audit of Aztec's TGE Contract" (FULL)

- **Auditor:** ZKSecurity · **Date:** February 24th, 2025 · **Duration:** 3 workdays, 1 consultant
- **Target:** private repo `github.com/AztecProtocol/teegeeee` @ commit `8432c82584731813a2197dd3b715ba2db0dbe3f9`
- **Scope:** `src/token` (AZTEC ERC20), `src/atps` (ATP incl. **MATP** + **LATP**), `src/libraries` (schedule-lock helper), `src/staker` (no-op test staker), `src/ATPFactory.sol`, `src/Registry.sol`
- **Result:** 1 major + 2 informational.

| ID | Severity | Affected contract | Title |
|----|----------|-------------------|-------|
| #00 | **High** | `src/atps` (ATP core) | The ATP contract can upgrade the Staker to arbitrary address and withdraw the locked token |
| #01 | Informational | `src/atps/linear/LATPCore.sol` | The beneficiary can claim additional transferred AZTEC tokens before the global lock ends |
| #02 | Informational | `src/libraries/LockLib.sol` | Possible overflow in arithmetic |

### R1 #00 — ATP can upgrade Staker to arbitrary address & withdraw locked token — **High** — `src/atps`
**Description.** Locked AZTEC in an ATP may participate in staking; the ATP approves the locked token to its staker. Staking must NOT bypass the unlock schedule, so an ATP should only use staker implementations whitelisted by the `Registry`. Due to an oversight, `upgradeStaker(StakerVersion _version, bytes _initdata)` (`onlyBeneficiary`) fetches `impl = REGISTRY.getMilestoneStakerImplementation(_version)` then calls `UUPSUpgradeable(staker).upgradeToAndCall(impl, _initdata)`. `_initdata` is **unrestricted** — the beneficiary can encode another `upgradeToAndCall` so the call triggers **two** upgrades: the first impl is registry-checked, but the second (embedded in `_initdata`) is **not**. Result: staker upgraded to an arbitrary implementation.
**PoC.** `test/btt/atps/milestone/upgradeStaker/upgradeStaker.t.sol::test_arbitraryUpgrade` deploys `FakeMilestoneStaker badStaker`, calls `atp.upgradeStaker(StakerVersion.wrap(0), abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(badStaker), "")))`; asserts `atp.getStaker().getImplementation() == badStaker`.
**Impact.** Beneficiary upgrades staker to a malicious impl and withdraws the locked token from the staker (vesting/unlock bypass).
**Recommendation.** Restrict `_initdata` — e.g. only allow calling `initialize` during the upgrade.

### R1 #01 — Beneficiary can claim extra transferred AZTEC before global lock ends — **Informational** — `LATPCore.sol`
**Description.** Docs state "Any additional tokens transferred to the ATP after its creation cannot be retrieved until after the global lock ends." But `LATPCore.getClaimable()` returns `Math.min(TOKEN.balanceOf(this) - getRevokableAmount(), unlocked)`; when accumulated < global unlock, the claimable is `balanceOf - getRevokableAmount`, which **includes** stray transferred tokens — so they can be claimed early.
**Impact.** Not critical; inconsistent with documentation. **Rec.** Align docs with behavior (or vice-versa).

### R1 #02 — Possible overflow in arithmetic — **Informational** — `LockLib.sol`
**Description.** `LockLib.createLock` computes `cliff = startTime + cliffDuration` and `endTime = startTime + lockDuration`; sums can overflow `uint256` for large inputs. Also `ATP.claim()` does `claimed += amount`, which could overflow if amounts are huge and the beneficiary cyclically claims+transfers (additional transferred tokens are claimable). **Impact.** Improbable in practice. **Rec.** Use SafeMath-style checked arithmetic.

---

## 3 — Spearbit: "Aztec teegeee Security Review" (FULL)

- **Auditors:** Noah Marconi, Xmxanuel (Leads), Cryptara, Chinmay Farkya · report by Lucas Goiriz · **March 17, 2025**
- **Target:** `aztec-teegeee` @ commit `8062e3a6` · **Timeline:** Feb 25th–28th (3 days) · Type: Governance, Staking
- **Totals:** 22 issues — Critical 0 · **High 1** · Medium 0 · Low 4 · Gas 1 · Informational 16 (9 fixed / 13 acknowledged)

| ID | Severity | Affected contract | Title | Status |
|----|----------|-------------------|-------|--------|
| 5.1.1 | **High** | ATP core (`upgradeStaker`) | beneficiary can withdraw all their tokens in staking by exploiting `ATP.upgradeStaker` | Fixed `2aac8775` |
| 5.2.1 | Low | `ATPFactory`, `Registry`, `Aztec` | Ownership transfer lacks two-step process | Fixed PR#69 (renounce remains) |
| 5.2.2 | Low | `MATPCore.sol#L193` | `MATPCore.updateStakerOperator` callable by revoker after revoke with no impact | Fixed `a8d58db3` |
| 5.2.3 | Low | `MATPCore.sol#L164` | beneficiary might not avoid slashing in MATP if milestone is known-unreachable | Acknowledged |
| 5.2.4 | Low | `MATPCore.sol#L142` | Differing treatment of rescued tokens for revoked ATP beneficiaries | Fixed `50f0c1d4` |
| 5.3.1 | Gas | `LATPCore.sol#L140` | Duplicate checks for `store.isRevokable` (3× via getAccumulationLock) | Acknowledged |
| 5.4.1 | Info | `ATPFactory.sol#L73` | Comment says "any token" when only TOKEN may be recovered | Fixed `a0fded65` |
| 5.4.2 | Info | `LATPCore.sol#L117` | `StakerVersion.wrap(0)` is the only version confirmed initialized (out-of-order upgrades) | Acknowledged |
| 5.4.3 | Info | `LinearBaseStaker.sol#L49-51` | Add event when operator is updated | Fixed `890ff671` |
| 5.4.4 | Info | `LATPCore.sol#L54-60` | Consider restricting initialization on implementation contracts | Fixed `85802245` |
| 5.4.5 | Info | `Registry.sol#L68-69` | Hardcoded timing variables (`unlockStartTime`, `executeAllowedAt`) | Acknowledged |
| 5.4.6 | Info | `LATPCore.sol#L82` | Missing allocation integrity check in `LATPCore.initialize` | Acknowledged |
| 5.4.7 | Info | `LATPCore.sol#L112-116` | Unrestricted downgrading of staker version | Acknowledged (intentional) |
| 5.4.8 | Info | `LATPCore.sol#L211` | Typos in contract & docs (`alowance`, `teegeee`) | Fixed `91b97447` |
| 5.4.9 | Info | `MATPCore` | Improper claim handling & dynamic beneficiary issues (revoker reuses `claim`) | Acknowledged |
| 5.4.10 | Info | `LATPCore.sol#L97` | `revokeBeneficiary` cannot be changed by governance in LATP | Acknowledged (intentional) |
| 5.4.11 | Info | LATP vs MATP | LATP and MATP handle staking rewards differently on revoke | Acknowledged (intentional) |
| 5.4.12 | Info | `Aztec.sol#L10` | Prevent sending Aztec tokens to the Aztec contract (lock-up) | Acknowledged |
| 5.4.13 | Info | `LATPCore.sol#L118` | Add sanity checks to `upgradeStaker` (verify `staker.getATP()==this`) | Fixed `745b2898` |
| 5.4.14 | Info | `Registry.sol#L199` | Consider range checks for `registry.setUnlockStartTime` | Acknowledged |
| 5.4.15 | Info | `LATPCore.sol#L139` | revoker can access tokens before global lock cliff ends | Acknowledged |
| 5.4.16 | Info | `MATPCore.sol#L252` | `REGISTRY.getRevokerOperator` can be `address(0)`; revoker can't change revokeOperator | Acknowledged |

### R2 5.1.1 — beneficiary can withdraw all staked tokens via `ATP.upgradeStaker` — **High** — ATP core
**Description.** Beneficiary can upgrade the Staker logic via `upgradeStaker`; only registry-approved versions should be usable, guaranteeing no access to staked tokens. But `_initdata` is beneficiary-controlled and passed to `UUPSUpgradeable(staker).upgradeToAndCall(impl, _initdata)`. Instead of calling `initialize`, the beneficiary embeds another `upgradeToAndCall` pointing at a malicious impl — nested delegatecalls where `msg.sender` stays the ATP.
**Call flow:** `beneficiary → atp.upgradeStaker → stakerProxy ⇒ currImpl.upgradeToAndCall ⇒ stakerProxy ⇒ correctVersionImpl.upgradeToAndCall ⇒ stakerProxy ⇒ attackerImpl.getAllTokens` (`→`=CALL, `⇒`=DELEGATECALL).
**PoC.** `test/btt/atps/linear/upgradeStaker/upgradeStaker.t.sol::test_upgradeStakerAttack` — `AttackStaker.getAllTokens` calls `STAKING.unstake(target, amount)`; after `atp.upgradeStaker(fakeStakerVersion, data)` the attacker address receives `amountToTake`.
**Recommendation.** Don't let beneficiary supply full `_initdata`; track required `initialize` signature in the registry per version and construct `_initdata` inside `upgradeStaker`; consider allowing only next-version upgrades; or add a `nonReentrant onlyATP` override of `upgradeToAndCall` in `LinearBaseStaker`/`MilestoneBaseStaker`. **Fixed in `2aac8775`.**

### Selected detail — the revocation/milestone Low/Info cluster (key for vesting-bypass review)
- **5.2.2 (Low, `MATPCore#L193`):** after revoke, `getOperator()` always returns `REGISTRY.getRevokerOperator()`, yet `updateStakerOperator` still writes storage with no effect → false assumption operator changed. Rec: revert after revoke. *Fixed `a8d58db3`.*
- **5.2.4 (Low, `MATPCore#L142`):** post-revoke, LATP beneficiary can still `rescueFunds` (non-TOKEN), but MATP beneficiary is replaced by revoker → rescue impossible. Unify treatment. *Fixed `50f0c1d4`.*
- **5.4.9 (Info, MATPCore):** after milestone fail / revoke, the registry **revoker reuses `claim`** → misleading `Claimed` events & `claimed` updates; `onlyBeneficiary` dynamically returns revoker, letting revoker call `approveStaker` etc. Rec: separate `revokeWithdraw`, make `onlyBeneficiary` non-dynamic. *Acknowledged.*
- **5.4.15 (Info, `LATPCore#L139`):** revoker can pull tokens out of an ATP **before the global unlock ends**. *Acknowledged — revoker == admin, trusted.*
- **5.4.7 (Info, `LATPCore#L112-116`):** `upgradeStaker` allows **downgrading** to older staker versions (rollback to a flawed/vulnerable impl). *Acknowledged — intentional "change not strictly upgrade".*
- **5.4.6 (Info, `LATPCore#L82`):** `initialize` does not verify `TOKEN.balanceOf(this) >= _allocation` (relies on factory). *Acknowledged.*

---

## 4 — Cantina `l1-contracts` reports with ATP/staker findings

### R3 — Cantina: Protocol Treasury (`ignition-monorepo` @ `2a2c7909`, 2025-11-10→11)
4 issues (Low 1 / Gas 1 / Info 2).

| ID | Severity | Contract | Title | Status |
|----|----------|----------|-------|--------|
| 3.1.1 | **Low** | `ProtocolTreasury.sol#L118-121` | Governance could bypass insider gate by lowering **ATP registry** timestamp when colluding with registry owner | Acknowledged |
| 3.2.1 | Gas | `ProtocolTreasury.sol#L123-124` | Zero-value relays pay unnecessary BALANCE gas | Fixed PR#690 |
| 3.3.1 | Info | `ProtocolTreasury.sol#L46` | ProtocolTreasury ineffective bootstrap on mature governance (`markNext` 1/tx) | Acknowledged |
| 3.3.2 | Info | `ProtocolTreasury.sol#L125` | Relay strips governance caller identity | Acknowledged |

**3.1.1 (Low) — ATP-gate bypass.** `relay()` recomputes `insiderCanActTimestamp()` each call from `ATP_REGISTRY.getExecuteAllowedAt() + 7 days`. The ATP registry owner can **decrease** `executeAllowedAt` arbitrarily via `Registry.setExecuteAllowedAt`. A colluding/compromised owner can lower it for one tx so the insider gate passes immediately, then `relay()` to drain funds / push approvals before insiders were genuinely allowed to act — defeating the ≥1-week insider participation guarantee. Rec: store the unlock timestamp immutably at deployment (with 7-day buffer), or cache first-observed `executeAllowedAt` and never allow decreases; move registry ownership to an independent contract. *Acknowledged — registry owner is a separate entity; only decreasable.*

### R4 — Cantina: Staking Registry (`ignition-monorepo` @ `c9efabac`, 2025-08-22→29)
11 issues (Medium 1 / Low 2 / Gas 4 / Info 4). Covers ignition `src/staking-registry/` (`StakingRegistry.sol`, `QueueLib`, provider keystore / rollup deposit / withdrawal queue).

| ID | Severity | Title |
|----|----------|-------|
| 3.1.1 | **Medium** | Provider can atomically increase its take rate (front-run stakers' rate assumption) |
| 3.2.1 | Low | Admin role transfer lacks validation and acceptance mechanism |
| 3.2.2 | Low | Duplicate KeyStores can be added causing rollup deposit failures |
| 3.3.1 | Gas | Inefficient mechanism for removing multiple keys from provider queue |
| 3.3.2 | Gas | Loop initialization can be optimized by using default zero value |
| 3.3.3 | Gas | `finaliseWithdrawal()` can be permissionless |
| 3.3.4 | Gas | `enqueue()` has redundant return value |
| 3.4.1 | Info | Inconsistent increment syntax in queue operations |
| 3.4.2 | Info | Key addition management code-quality improvements |
| 3.4.3 | Info | Typographical errors |
| 3.4.4 | Info | **Slashing-induced exits enable earlier withdrawals** (staking/withdrawal timing) |

---

## 5 — Reports scanned with NO ATP / staker / milestone / vesting findings

These were extracted and keyword-scanned; they concern aztec-packages L1 governance/rollup or Barretenberg cryptography, **not** the ATP/vesting domain — listed for audit-trail completeness:

| Report | Auditor | Domain |
|--------|---------|--------|
| Cantina — Governance | Cantina | aztec-packages Governance |
| Veridise — Governance | Veridise | aztec-packages Governance |
| Igor Konnov, Thomas Pani — Governance Formal Verification | — | Governance (formal verification) |
| Cantina — Rollup Contracts | Cantina | l1-contracts Rollup |
| Cantina — Escape Hatch | Cantina | l1-contracts EscapeHatch |
| Cantina — CoinIssuer | Cantina | l1-contracts CoinIssuer |
| Cantina — Payload 2025.03.05 | Cantina | Governance payload |
| Cantina — Soulbound | Cantina | Soulbound (incidental "beneficiary"/"stake" hits only) |
| Cantina — Uniswap TWAP | Cantina | Uniswap-periphery TWAP (high "lock/unlock" hit count is TWAP liquidity-lock, not ATP vesting) |
| Cantina/Zellic/ZKSecurity/Veridise/Sherlock/Cyfrin — Barretenberg (Bigfield, Bool/Bytearray, Field, Logic, RAM/ROM, CycleGroup) | various | Barretenberg ZK primitives |

> Note: "Cantina — Uniswap TWAP" and "Cantina — Soulbound" matched the keyword `unlock`/`beneficiary`/`stake` but on inspection contain no ATP/MATP/LATP/milestone/revocation/vesting-schedule findings. If you want either pulled in full as well, say so and I'll extract them.
