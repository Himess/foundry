#!/usr/bin/env bash
# ATP-ONCHAIN-VERIFY.sh — READ-ONLY precondition check for the MATP upgradeStaker→claimable-staker finding.
# Implements ADIM 1..5 of ATPONCHAINVERIFICATIONTASK.md using only `cast call/logs/code/block` + etherscan read.
# NO state-changing tx. NO private keys. NO exploitation. Writes ATP-ONCHAIN-VERIFICATION.md.
#
# Requirements: foundry `cast`, `curl`, `jq`, `date` (GNU). Env: $RPC (mainnet), $ETHERSCAN_KEY.
# ABI signatures verified against ignition-contracts source (Registry.sol / IATP.sol / staker):
#   StakerVersion is uint256 ; MilestoneId is uint96 ; MilestoneStatus{Pending=0,Failed=1,Succeeded=2}
#   ATPType{Linear=0,Milestone=1,NonClaim=2} ; LockParams=(uint256 startTime,uint256 cliffDuration,uint256 lockDuration)
#   event ATPCreated(address indexed beneficiary,address indexed atp,uint256 allocation)  [emitted by ATPFactory]
set -uo pipefail

: "${RPC:?set RPC to a mainnet RPC URL}"
ETHERSCAN_KEY="${ETHERSCAN_KEY:-}"
OUT="ATP-ONCHAIN-VERIFICATION.md"

REG=0x63841bAD6B35b6419e15cA9bBBbDf446D4dC3dde      # ATP_REGISTRY (ignition token-vaults Registry)
ROLLUP=0x603bb2c05D474794ea97805e8De69bCcFb3bCA12   # ROLLUP (aztec-packages)
AZTEC=0xA27EC0006e59f245217Ff08CD52A7E8b169E62D2    # AZTEC token
ROLLUP_REGISTRY=0x35b22e09Ee0390539439E24f06Da43D83f90e298

c(){ cast call "$@" --rpc-url "$RPC" 2>/dev/null; }
utc(){ date -u -d "@$1" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || echo "n/a"; }
WAL_SEL=$(cast sig "withdrawAllTokensToBeneficiary()" | sed 's/0x//')

echo "# ATP on-chain precondition verification" > "$OUT"
echo >> "$OUT"

# ---- chain sanity ----
CODE=$(cast code "$AZTEC" --rpc-url "$RPC" 2>/dev/null)
CHAINID=$(cast chain-id --rpc-url "$RPC" 2>/dev/null)
NOW=$(cast block latest --rpc-url "$RPC" --field timestamp 2>/dev/null)
BLK=$(cast block-number --rpc-url "$RPC" 2>/dev/null)
if [ -z "$CODE" ] || [ "$CODE" = "0x" ]; then
  echo "WARNING: AZTEC token has NO code on chainId=$CHAINID. Wrong chain? Try Sepolia." | tee -a "$OUT"
fi
{
echo "- chainId: \`$CHAINID\`  (AZTEC token code present: $([ "${CODE:-0x}" != 0x ] && echo yes || echo NO))"
echo "- block: \`$BLK\`  now: \`$NOW\` ($(utc "$NOW"))"
echo
} >> "$OUT"

# ---- ADIM 1: staker versions ----
echo "## 1 — Registered staker versions" >> "$OUT"
echo "| version | impl | claimable? | WITHDRAWAL_TIMESTAMP |" >> "$OUT"
echo "|--------|------|-----------|----------------------|" >> "$OUT"
N=$(c "$REG" "getNextStakerVersion()(uint256)"); N=${N:-0}
CLAIMABLE_VERSIONS=""
for ((v=0; v<N; v++)); do
  IMPL=$(c "$REG" "getStakerImplementation(uint256)(address)" "$v")
  WT=$(c "$IMPL" "WITHDRAWAL_TIMESTAMP()(uint256)")
  ICODE=$(cast code "$IMPL" --rpc-url "$RPC" 2>/dev/null)
  HASWAL=$(echo "$ICODE" | grep -iqo "$WAL_SEL" && echo yes || echo no)
  CLAIM=no; [ -n "$WT" ] && [ "$HASWAL" = yes ] && { CLAIM=yes; CLAIMABLE_VERSIONS="$CLAIMABLE_VERSIONS $v"; }
  echo "| $v | \`$IMPL\` | $CLAIM (withdrawSel:$HASWAL) | ${WT:-—} $([ -n "$WT" ] && echo "($(utc "$WT"))") |" >> "$OUT"
done
echo >> "$OUT"
echo "**Claimable staker version(s):** ${CLAIMABLE_VERSIONS:-NONE registered}" >> "$OUT"
echo >> "$OUT"

# ---- ADIM 2: attack-window timestamps ----
echo "## 2 — Attack-window timestamps" >> "$OUT"
EAA=$(c "$REG" "getExecuteAllowedAt()(uint256)")
UST=$(c "$REG" "getUnlockStartTime()(uint256)")
GLP=$(c "$REG" "getGlobalLockParams()((uint256,uint256,uint256))")
REVOKER=$(c "$REG" "getRevoker()(address)")
REVOP=$(c "$REG" "getRevokerOperator()(address)")
cmp(){ [ -n "$1" ] && { [ "$1" -le "$NOW" ] 2>/dev/null && echo "PAST (open)" || echo "FUTURE (opens $(utc "$1"))"; } || echo "n/a"; }
{
echo "- executeAllowedAt: \`$EAA\` ($(utc "$EAA")) → approveStaker gate: $(cmp "$EAA")"
echo "- unlockStartTime: \`$UST\` ($(utc "$UST"))"
echo "- globalLockParams (start,cliffDur,lockDur): \`$GLP\`"
echo "- revoker: \`$REVOKER\`  revokerOperator: \`$REVOP\`"
echo
} >> "$OUT"

# ---- ADIM 3: activation threshold ----
echo "## 3 — activationThreshold" >> "$OUT"
ACT=$(c "$ROLLUP" "getActivationThreshold()(uint256)")
echo "- ROLLUP.getActivationThreshold(): \`$ACT\`" >> "$OUT"; echo >> "$OUT"

# ---- ADIM 4: deployed ATP inventory ----
echo "## 4 — Deployed ATP inventory" >> "$OUT"
FACTORY=""; CREATION_BLOCK=""
if [ -n "$ETHERSCAN_KEY" ]; then
  CRJSON=$(curl -sS "https://api.etherscan.io/api?module=contract&action=getcontractcreation&contractaddresses=$REG&apikey=$ETHERSCAN_KEY")
  CRTX=$(echo "$CRJSON" | jq -r '.result[0].txHash // empty')
  echo "- Registry creation tx: \`${CRTX:-unknown}\`" >> "$OUT"
  if [ -n "$CRTX" ]; then
    CREATION_BLOCK=$(cast tx "$CRTX" --rpc-url "$RPC" --field blockNumber 2>/dev/null)
    FACTORY=$(cast tx "$CRTX" --rpc-url "$RPC" --field to 2>/dev/null)   # ATPFactory deploys Registry in ctor
  fi
fi
FROMBLK=${CREATION_BLOCK:-0}
echo "- inferred ATPFactory (creator/to): \`${FACTORY:-unknown — set manually}\`" >> "$OUT"
echo "- scanning ATPCreated from block: \`$FROMBLK\`" >> "$OUT"; echo >> "$OUT"

LOGS=$(cast logs --from-block "$FROMBLK" --to-block latest \
        "ATPCreated(address,address,uint256)" ${FACTORY:+--address "$FACTORY"} \
        --rpc-url "$RPC" --json 2>/dev/null)
COUNT=$(echo "$LOGS" | jq 'length' 2>/dev/null || echo 0)
echo "- total ATPCreated events: **${COUNT:-0}**" >> "$OUT"; echo >> "$OUT"
echo "| atp | type | allocation | staker impl | milestone status | revoked |" >> "$OUT"
echo "|-----|------|-----------|-------------|------------------|---------|" >> "$OUT"

LIVE_MATP=0
mapfile -t ATPS < <(echo "$LOGS" | jq -r '.[].topics[2] // empty' | sed 's/0x000000000000000000000000/0x/')
for ATP in "${ATPS[@]}"; do
  [ -z "$ATP" ] && continue
  T=$(c "$ATP" "getType()(uint8)")
  ALLOC=$(c "$ATP" "getAllocation()(uint256)")
  STK=$(c "$ATP" "getStaker()(address)")
  SIMPL=$(c "$STK" "getImplementation()(address)")
  MS="—"; RV="—"
  if [ "${T:-x}" = "1" ]; then
    MID=$(c "$ATP" "getMilestoneId()(uint96)")
    RV=$(c "$ATP" "getIsRevoked()(bool)")
    MSN=$(c "$REG" "getMilestoneStatus(uint96)(uint8)" "$MID")
    case "$MSN" in 0) MS="Pending";; 1) MS="Failed";; 2) MS="Succeeded";; *) MS="?($MSN)";; esac
    if [ "$MS" = Pending ] && [ "$RV" = false ] && [ -n "$ALLOC" ] && [ -n "$ACT" ] \
       && [ "$(echo "$ALLOC >= $ACT" | bc 2>/dev/null)" = 1 ]; then LIVE_MATP=$((LIVE_MATP+1)); fi
  elif [ "${T:-x}" = "0" ]; then
    RV="revokable=$(c "$ATP" "getIsRevokable()(bool)")"
  fi
  TN=Linear; [ "$T" = 1 ] && TN=Milestone; [ "$T" = 2 ] && TN=NonClaim
  echo "| \`$ATP\` | $TN | ${ALLOC:-?} | \`$SIMPL\` | $MS | $RV |" >> "$OUT"
done
echo >> "$OUT"

# ---- ADIM 5: verdict ----
echo "## 5 — Exploitability verdict" >> "$OUT"
WINDOW_OPEN=no; [ -n "$EAA" ] && [ "$EAA" -le "$NOW" ] 2>/dev/null && WINDOW_OPEN=yes
{
echo "- claimable staker registered: $([ -n "$CLAIMABLE_VERSIONS" ] && echo "YES ($CLAIMABLE_VERSIONS)" || echo NO)"
echo "- executeAllowedAt in past: $WINDOW_OPEN"
echo "- live candidate MATP (Pending, !revoked, allocation≥activationThreshold): $LIVE_MATP"
echo
if [ -n "$CLAIMABLE_VERSIONS" ] && [ "$WINDOW_OPEN" = yes ] && [ "$LIVE_MATP" -gt 0 ]; then
  echo "### VERDICT: 🟢 GREEN — demonstrably live-exploitable preconditions present"
elif [ -n "$CLAIMABLE_VERSIONS" ] && [ "$LIVE_MATP" -gt 0 ]; then
  echo "### VERDICT: 🟡 AMBER — suitable MATP + mechanism present, but a timestamp gate is still in the future"
else
  echo "### VERDICT: 🔴 RED — mechanism present, impact conditional (no qualifying MATP and/or claimable staker not registered)"
fi
echo
echo "_Note: WITHDRAWAL_TIMESTAMP gate is per claimable-staker-impl (see §1); compare it to now alongside executeAllowedAt._"
} >> "$OUT"

echo "Wrote $OUT"
