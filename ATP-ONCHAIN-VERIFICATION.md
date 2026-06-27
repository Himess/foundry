# ATP-ONCHAIN-VERIFICATION

**Finding under test:** A **MATP** beneficiary upgrades its staker to a *claimable* staker (`ATPWithdrawableAndClaimableStaker(V2)` containing `withdrawAllTokensToBeneficiary()`) via `upgradeStaker`, then drains the full allocation while the milestone is still `Pending` — bypassing milestone-gating **and** revocation.

**Mode:** READ-ONLY precondition check (responsible disclosure). No state-changing tx, no exploitation, no keys.

---

## ⚠️ STATUS: on-chain reads could NOT be executed from this environment

This session's egress policy **blocks every Ethereum RPC endpoint and the etherscan API** (HTTP 403 "policy denial" on `CONNECT`). Only `github.com` + language package registries are allowed. No `$RPC` or `$ETHERSCAN_KEY` was provided to the session either.

Evidence (proxy-side relay failures, captured 2026-06-27):

| Host attempted | Result |
|----------------|--------|
| `ethereum-rpc.publicnode.com:443` | 403 policy denial |
| `eth.llamarpc.com:443`, `cloudflare-eth.com:443`, `rpc.ankr.com:443` | 403 policy denial |
| `mainnet.gateway.tenderly.co`, `rpc.flashbots.net`, `eth.drpc.org`, `1rpc.io` | 403 policy denial |
| `api.etherscan.io:443` (curl **and** WebFetch) | 403 policy denial |

Per the proxy README, policy denials must be reported, not routed around — so **ADIM 1–5 on-chain values are NOT in this document.** Instead:

1. **§A below** — the part verifiable *here*: a **source-level** confirmation that the finding's three root-cause preconditions exist in the pinned ignition contracts. (Real, checked against code — clearly labelled "source-level, not on-chain".)
2. **`ATP-ONCHAIN-VERIFY.sh`** (delivered alongside) — a ready-to-run script implementing ADIM 1–5 verbatim with `cast`/etherscan, ABI signatures pre-verified against source. Run it where you have RPC access; it writes the on-chain half of this file:

```bash
export RPC=<your-mainnet-rpc>           # e.g. Alchemy/Infura/your node
export ETHERSCAN_KEY=<your-key>         # for ADIM 4 (creation block + ATPCreated scan)
foundryup                               # if cast not installed
bash ATP-ONCHAIN-VERIFY.sh              # READ-ONLY: cast call/logs/code/block only
```

---

## §A — Source-level precondition confirmation (ignition-contracts @ `0e56191`)

> Verified by reading the pinned source (BUNDLE-A). This proves the *mechanism* exists in the audited code; it does **not** prove the *deployed* system is wired/timed to be live-exploitable — that is exactly what ADIM 1–5 (the script) must confirm on-chain.

**P1 — `withdrawAllTokensToBeneficiary` bypasses `getClaimable()` accounting.** ✅ CONFIRMED
`ATPWithdrawableAndClaimableStaker.sol:150` reads `STAKING_ASSET.balanceOf(atp)` and `safeTransferFrom(atp, beneficiary, atpBalance)` — the **entire ATP balance**, with no reference to `getClaimable()` / unlock schedule. Gated only by `onlyOperator`, `hasStaked()`, and `block.timestamp >= WITHDRAWAL_TIMESTAMP` (`:154`). `WITHDRAWAL_TIMESTAMP` is an `immutable` on the staker impl (`:44`).

**P2 — `upgradeStaker` has NO ATP-type restriction.** ✅ CONFIRMED
`MATPCore.sol:107` `upgradeStaker(StakerVersion _version)` → `impl = REGISTRY.getStakerImplementation(_version)` → `upgradeToAndCall(impl, "")`, post-checked only by `staker.getATP() == address(this)`. The registry exposes a **single global** `getStakerImplementation(StakerVersion)` (no per-type Linear/Milestone split), so a Milestone ATP can upgrade to **any** registered version, including a claimable one. *(Note: the old TGE-audit `_initdata` re-entrancy vector is gone — current signature takes no `_initdata`. This finding is the orthogonal "type confusion" path: a claimable staker registered as a valid version.)*

**P3 — MATP `approveStaker` has NO stakeable cap.** ✅ CONFIRMED
`MATPCore.sol:156` `approveStaker(uint256 _allowance)` → `TOKEN.approve(address(staker), _allowance)` with a caller-chosen `_allowance` (can be the full allocation), gated only by `block.timestamp >= REGISTRY.getExecuteAllowedAt()`.

**P4 — Revocation window.** `MATPCore.revoke()` requires `MilestoneStatus.Pending` — consistent with the hypothesis that the drain must occur while `Pending` (before a revoker can act), and that draining defeats the revoker's recovery.

**Conclusion (source-level):** all three mechanism preconditions are present in the pinned code. The finding is **structurally valid**; whether it is *live* depends on the on-chain facts below.

---

## §B — On-chain results (TO BE FILLED by `ATP-ONCHAIN-VERIFY.sh`)

> Not executed in this container (see STATUS). The script emits the sections below.

### 1 — Registered staker versions  ⬜ pending
`version → impl → claimable? → WITHDRAWAL_TIMESTAMP`, plus **the claimable staker's version number** (the answer to "can a MATP `upgradeStaker(v)` reach it?" — yes the moment it is registered).

### 2 — Attack-window timestamps  ⬜ pending
`executeAllowedAt`, `unlockStartTime`, `getGlobalLockParams`, `revoker`, `revokerOperator` vs `now` (UTC). Both `executeAllowedAt` (approveStaker gate) and the claimable staker's `WITHDRAWAL_TIMESTAMP` (withdraw gate) must be in the past for a *live* drain.

### 3 — activationThreshold  ⬜ pending
`ROLLUP.getActivationThreshold()` — minimum stake amount.

### 4 — Deployed ATP inventory  ⬜ pending
ATPFactory address + total `ATPCreated` count; per-ATP type / allocation / staker-impl (upgraded?); per-MATP milestone status + revoked flag; non-revocable LATPs noted separately.

### 5 — Verdict  ⬜ pending  (script computes GREEN / AMBER / RED)
- 🟢 **GREEN** — a deployed MATP with `allocation ≥ activationThreshold`, `status == Pending`, `isRevoked == false`, AND both `executeAllowedAt` + claimable `WITHDRAWAL_TIMESTAMP` in the past.
- 🟡 **AMBER** — suitable MATP + claimable staker registered, but a timestamp gate is still future-dated → window opens `<date>`.
- 🔴 **RED** — mechanism present but no qualifying MATP and/or claimable staker not yet registered.

---

## Addresses used (from task)

| Role | Address |
|------|---------|
| ATP_REGISTRY (`$REG`) | `0x63841bAD6B35b6419e15cA9bBBbDf446D4dC3dde` |
| ROLLUP (`$ROLLUP`) | `0x603bb2c05D474794ea97805e8De69bCcFb3bCA12` |
| AZTEC_TOKEN | `0xA27EC0006e59f245217Ff08CD52A7E8b169E62D2` |
| ROLLUP_REGISTRY | `0x35b22e09Ee0390539439E24f06Da43D83f90e298` |

## ABI signatures (verified against ignition source — safe to trust in the script)

- `StakerVersion is uint256`, `MilestoneId is uint96`
- `MilestoneStatus { Pending=0, Failed=1, Succeeded=2 }`, `ATPType { Linear=0, Milestone=1, NonClaim=2 }`
- `LockParams = (uint256 startTime, uint256 cliffDuration, uint256 lockDuration)` → `getGlobalLockParams()((uint256,uint256,uint256))`
- `event ATPCreated(address indexed beneficiary, address indexed atp, uint256 allocation)` — emitted by **ATPFactory**
- staker: `WITHDRAWAL_TIMESTAMP()(uint256)` (claimable only), `getImplementation()(address)`, `withdrawAllTokensToBeneficiary()`
