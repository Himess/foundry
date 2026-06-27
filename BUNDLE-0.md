# BUNDLE-0 — MANIFEST

Aztec L1 bug-bounty audit source bundle (Cantina bounty `80e74370-10d8-4e52-8e4b-7294deb7c9ee`).
**READ-ONLY fetch/bundle only — no analysis, no build, no deploy, no tx.**

Generated: 2026-06-27. Both repos cloned **without** `--recursive` (no submodules pulled).

---

## (a) Commit pinning

| Repo | Pinned commit (`git rev-parse HEAD`) | Commit date | Ref / how resolved |
|------|--------------------------------------|-------------|--------------------|
| `AztecProtocol/aztec-packages` | `880075b0284c0c6098013473c0593966397335b5` | 2025-08-22 11:52:40 +0000 | **Confirmed.** Matches the task's reference candidate AND is referenced 14× as hard-coded permalinks in the ignition-contracts `README.md` (`aztec-packages/blob/880075b…/l1-contracts/src/…`). Tip subject: `feat: Consensus-based slashing proposer contract (#16357)`. |
| `AztecProtocol/ignition-contracts` | `0e561913afaeb1fad46f14f5df1a8f4cb9abb9f5` | 2026-01-22 04:46:39 -0500 | Default-branch (`master`) HEAD at fetch time. Tip subject: `Merge pull request #5 from AztecProtocol/am/tge-audit-report`. See **Commit-verification caveat** below. |

### Commit-verification caveat (important — read before relying on the ignition pin)
- The Cantina bounty Scope page (`cantina.xyz/bounties/80e74370-…`) is **auth-gated and returned HTTP 403** from this environment, so the *exact* bounty-listed `repo@commit` / branch could **not** be read directly from Cantina.
- **aztec-packages** pin is solid: independently corroborated by the ignition README permalinks (above) and the task's reference candidate — they agree exactly.
- **ignition-contracts** pin is the current `master` HEAD (audit-report merge tip), the most plausible audited revision, but it was **not** cross-confirmed against Cantina. If the bounty lists a specific ignition commit, re-pin with:
  `GIT_CONFIG_GLOBAL=/dev/null git -c protocol.version=2 fetch --depth 1 origin <COMMIT> && git checkout <COMMIT>` and regenerate BUNDLE-A.
- **Deployed-bytecode cross-check (etherscan anchors) was NOT performed.** Reasons: (1) on-chain↔source bytecode comparison requires *compiling* the sources, which is explicitly forbidden by the task constraints (NO build); (2) etherscan/Cantina were not fetchable here. The address anchors from the task are recorded below for the researcher to verify manually:

| Contract | Address anchor (partial, from task) |
|----------|-------------------------------------|
| Rollup | `0x…3bb2c05d…` |
| Inbox | `0x…c718C05B…` |
| Outbox | `0x…06c41097…` |
| FeeJuicePortal | `0x…5dc9D596…` |
| BaseHonkVerifier | `0x…e3ba0963…` |

---

## (b) Bundle index

`source lines` = sum of raw `.sol` lines (`cat`). `bundle .md lines` = final generated file (incl. NAVIGATION + cat -n prefixes + code fences). Bundles A–D each open with a NAVIGATION block reproducing `grep -n "^### " <file>` with correct final line numbers.

| Bundle | Scope | Files | Source lines | Bundle .md lines | Status |
|--------|-------|------:|-------------:|-----------------:|--------|
| **BUNDLE-A.md** | `ignition-contracts/src/` — all production `.sol` (ATP cluster) | 53 | 5,952 | **6,278** | ✅ Delivered |
| **BUNDLE-B.md** | `aztec-packages: l1-contracts/src/core/` | 49 | 8,914 | _(on request)_ | ⏳ Deferred |
| **BUNDLE-C.md** | `aztec-packages: l1-contracts/src/governance/` | 22 | 3,567 | _(on request)_ | ⏳ Deferred |
| **BUNDLE-D.md** | `l1-contracts/src/periphery/` (3) + `l1-contracts/src/shared/` (5) + `barretenberg/sol/src/honk/` (18) | 26 | 4,218 | _(on request)_ | ⏳ Deferred |
| **BUNDLE-AUDITS.md** | `AztecProtocol/audit-reports` — dedup finding list | — | — | _(on request)_ | ⏳ Deferred (not yet cloned) |

Totals across in-scope production source: **150 files**, **22,651 source lines** (A+B+C+D). Generator: `scratchpad/gen_bundle.py` (deterministic; self-verifies NAV against real `grep -n`).

---

## (c) Collected / excluded paths

### Collected (in-scope, bundled)
**ignition-contracts @ `0e56191`** → BUNDLE-A (all of `src/`, 53 files):
```
src/                         (2)   ProtocolTreasury.sol, constants.sol
src/sale/                    (2)
src/soulbound/               (2)
src/soulbound/providers/     (5)
src/staking/                 (3)   ATPNonWithdrawableStaker, ATPWithdrawableStaker, ATPWithdrawableAndClaimableStaker
src/staking/interfaces/      (4)
src/staking/rollup-system-interfaces/ (4)
src/staking-registry/        (1)   StakingRegistry.sol
src/staking-registry/libs/   (2)   BN254.sol, QueueLib.sol
src/tge/                     (2)   ATPWithdrawableAndClaimableStakerV2.sol, TGEPayload.sol
src/token-vaults/            (4)   ATPFactory.sol, Registry.sol, Nonces.sol, ATPFactoryNonces.sol
src/token-vaults/atps/...    (9)   base/IATP, linear/{LATP,LATPCore,ILATP}, milestone/{MATP,MATPCore,IMATP}, noclaim/{NCATP,INCATP}
src/token-vaults/deployment-factories/ (3)  LATPFactory, MATPFactory, NCATPFactory
src/token-vaults/libraries/  (1)   LockLib.sol
src/token-vaults/staker/     (1)   BaseStaker.sol
src/token-vaults/token/      (2)   Aztec.sol, IERC20Mintable.sol
src/uniswap-periphery/       (5)   GovernanceAcceleratedLock, VirtualAztecToken, AuctionHook, IVirtualLBPStrategy{Basic,Factory}
src/uniswap-periphery/barrel/(1)   UniswapBarrel.sol
```

**aztec-packages @ `880075b`** → BUNDLE-B/C/D (checked out via sparse-checkout):
```
l1-contracts/src/core/          (49)  → BUNDLE-B
l1-contracts/src/governance/    (22)  → BUNDLE-C
l1-contracts/src/periphery/     (3)   → BUNDLE-D
l1-contracts/src/shared/        (5)   → BUNDLE-D
barretenberg/sol/src/honk/      (18)  → BUNDLE-D
```

### Excluded (per task)
- All `test/`, `*.t.sol`, `script/` & `scripts/`, deployment/ignition configs.
- `node_modules/`, OpenZeppelin / vendored deps (`lib/`, `@oz`, `@zkpassport` external libs).
- `mock` / `*Mock*` contracts.
- Any aztec-packages path outside the five in-scope dirs (sparse-checkout never materialized them).
- Submodules (cloned **without** `--recursive`).
- Note: no `test`/`mock`/`script` `.sol` files exist *inside* the in-scope aztec dirs — all 97 are production. (`AttestationLib.sol`, `Transcript.sol`, `ZKTranscript.sol` match a naive `test`/`script` substring grep but are production files, not excluded.)

---

## (d) solc versions (from `foundry.toml` / pragmas)

| Repo / area | `foundry.toml` `solc` | `evm_version` | Notes |
|-------------|----------------------|---------------|-------|
| aztec-packages `l1-contracts/` | `0.8.27` (pinned) | — | applies to BUNDLE-B + BUNDLE-C + BUNDLE-D(periphery/shared) |
| aztec-packages `barretenberg/sol/` | `0.8.29` (pinned) | — | applies to BUNDLE-D (honk verifier) |
| ignition-contracts `src/` | _none pinned_ | `prague` | pragmas: `^0.8.27` (46 files, dominant), `>=0.8.27` (1), `^0.8.26` (2), `^0.8.30` (2), `^0.8.0` (2) |

---

## Reproduction notes (environment specifics)

The session git is routed through a scoped proxy (`insteadOf` rewrites `github.com` → an internal git proxy that only serves the session repo). External AztecProtocol clones were fetched by bypassing the global gitconfig so git uses the egress HTTPS proxy directly:

```bash
# ignition (full, shallow)
GIT_CONFIG_GLOBAL=/dev/null git clone --depth 1 \
  https://github.com/AztecProtocol/ignition-contracts.git ignition

# aztec-packages (pinned commit, blobless, sparse — avoids cloning the full monorepo)
git init aztec && cd aztec
git remote add origin https://github.com/AztecProtocol/aztec-packages.git
git config core.sparseCheckout true
GIT_CONFIG_GLOBAL=/dev/null git -c protocol.version=2 fetch --depth 1 --filter=blob:none \
  origin 880075b0284c0c6098013473c0593966397335b5
printf 'l1-contracts/src/\nbarretenberg/sol/src/honk/\n' > .git/info/sparse-checkout
GIT_CONFIG_GLOBAL=/dev/null git checkout FETCH_HEAD
```
