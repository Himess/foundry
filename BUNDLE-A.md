# BUNDLE-A — ignition-contracts/src (ATP staking/vesting cluster)

- **Repo:** AztecProtocol/ignition-contracts
- **Commit:** `0e561913afaeb1fad46f14f5df1a8f4cb9abb9f5`
- **Commit date:** 2026-01-22 (default-branch HEAD)
- **solc:** no pinned solc in foundry.toml; pragmas: ^0.8.27 (dominant), also ^0.8.26 / ^0.8.30 / ^0.8.0 / >=0.8.27; evm_version=prague
- **Files in bundle:** 53

## NAVIGATION

_Reproduces `grep -n "^### " BUNDLE-A.md` (final line numbers):_

```
71:### src/ProtocolTreasury.sol
228:### src/constants.sol
244:### src/sale/GenesisSequencerSale.sol
609:### src/sale/IGenesisSequencerSale.sol
683:### src/soulbound/IIgnitionParticipantSoulbound.sol
775:### src/soulbound/IgnitionParticipantSoulbound.sol
1225:### src/soulbound/providers/AttestationProvider.sol
1361:### src/soulbound/providers/IWhitelistProvider.sol
1392:### src/soulbound/providers/PredicateProvider.sol
1501:### src/soulbound/providers/ZKPassportProvider.sol
1626:### src/soulbound/providers/ZKPassportProviderLegacy.sol
1842:### src/staking-registry/StakingRegistry.sol
2363:### src/staking-registry/libs/BN254.sol
2408:### src/staking-registry/libs/QueueLib.sol
2473:### src/staking/ATPNonWithdrawableStaker.sol
2750:### src/staking/ATPWithdrawableAndClaimableStaker.sol
2941:### src/staking/ATPWithdrawableStaker.sol
3000:### src/staking/interfaces/IATPNonWithdrawableStaker.sol
3030:### src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol
3068:### src/staking/interfaces/IATPWithdrawableStaker.sol
3090:### src/staking/interfaces/IGovernanceATP.sol
3107:### src/staking/rollup-system-interfaces/IGSE.sol
3125:### src/staking/rollup-system-interfaces/IGovernance.sol
3164:### src/staking/rollup-system-interfaces/IRegistry.sol
3183:### src/staking/rollup-system-interfaces/IStaking.sol
3220:### src/tge/ATPWithdrawableAndClaimableStakerV2.sol
3271:### src/tge/TGEPayload.sol
3411:### src/token-vaults/ATPFactory.sol
3792:### src/token-vaults/ATPFactoryNonces.sol
4047:### src/token-vaults/Nonces.sol
4082:### src/token-vaults/Registry.sol
4339:### src/token-vaults/atps/base/IATP.sol
4408:### src/token-vaults/atps/linear/ILATP.sol
4448:### src/token-vaults/atps/linear/LATP.sol
4517:### src/token-vaults/atps/linear/LATPCore.sol
4829:### src/token-vaults/atps/milestone/IMATP.sol
4852:### src/token-vaults/atps/milestone/MATP.sol
4910:### src/token-vaults/atps/milestone/MATPCore.sol
5188:### src/token-vaults/atps/noclaim/INCATP.sol
5221:### src/token-vaults/atps/noclaim/NCATP.sol
5250:### src/token-vaults/deployment-factories/LATPFactory.sol
5272:### src/token-vaults/deployment-factories/MATPFactory.sol
5294:### src/token-vaults/deployment-factories/NCATPFactory.sol
5318:### src/token-vaults/libraries/LockLib.sol
5450:### src/token-vaults/staker/BaseStaker.sol
5515:### src/token-vaults/token/Aztec.sol
5542:### src/token-vaults/token/IERC20Mintable.sol
5554:### src/uniswap-periphery/AuctionHook.sol
5687:### src/uniswap-periphery/GovernanceAcceleratedLock.sol
5775:### src/uniswap-periphery/IVirtualLBPStrategyBasic.sol
5803:### src/uniswap-periphery/IVirtualLBPStrategyFactory.sol
5820:### src/uniswap-periphery/VirtualAztecToken.sol
6232:### src/uniswap-periphery/barrel/UniswapBarrel.sol
```

## src/

### src/ProtocolTreasury.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	// Copyright 2025 Aztec Labs.
     3	pragma solidity >=0.8.27;
     4	
     5	import {ProposalState, Proposal} from "@aztec/governance/interfaces/IGovernance.sol";
     6	import {Governance} from "@aztec/governance/Governance.sol";
     7	import {Timestamp} from "@aztec/shared/libraries/TimeMath.sol";
     8	import {IRegistry} from "@atp/Registry.sol";
     9	import {Ownable} from "@oz/access/Ownable.sol";
    10	import {Address} from "@oz/utils/Address.sol";
    11	import {Errors} from "@oz/utils/Errors.sol";
    12	
    13	interface IProtocolTreasury {
    14	    error GateIsClosed(string reason);
    15	    error ProposalIsAlive();
    16	    error NoProposalToMark();
    17	
    18	    event ProposalMarked(uint256 indexed proposalId);
    19	
    20	    function markNext() external;
    21	    function relay(address target, bytes calldata data, uint256 value) external returns (bytes memory);
    22	    function getActivationTimestamp() external view returns (uint256);
    23	    function owner() external view returns (address);
    24	}
    25	
    26	/**
    27	 * @title   ProtocolTreasury
    28	 * @author  Aztec Labs
    29	 * @notice  A non-transferable date gated relayer that further restrict calls such that they can only be relayed if
    30	 *          a specified atp-registry allows execution in the related ATP's.
    31	 *
    32	 *          Example usage is for ownership of contracts that becomes property of the governance at some point
    33	 *          in the future when a group of ATP's can participate.
    34	 *
    35	 *          NOTE: because it is non-transferable it does not work well with governance upgrading itself before relays
    36	 *          are allowed.
    37	 *
    38	 *          NOTE: governance can "DOS" this relayer temporarily by extending the delays of governance. This would
    39	 *          temporarily impact the liveness, but as the delay configuration is bounded it cannot be forever.
    40	 */
    41	contract ProtocolTreasury is IProtocolTreasury {
    42	    Governance public immutable GOVERNANCE;
    43	    IRegistry public immutable ATP_REGISTRY;
    44	    uint256 public immutable GATED_UNTIL;
    45	
    46	    uint256 public markedProposalsCount;
    47	    uint256 public blockOfLastMarkNext;
    48	
    49	    constructor(address _governance, address _atpRegistry, uint256 _gatedUntil) {
    50	        GOVERNANCE = Governance(_governance);
    51	        ATP_REGISTRY = IRegistry(_atpRegistry);
    52	        GATED_UNTIL = _gatedUntil;
    53	    }
    54	
    55	    /**
    56	     * @notice  Marks the next proposal if "stable"
    57	     *          Used to progress the list of proposals forward to satisfy checks in relay
    58	     *
    59	     * @dev     Reverts if there are no "unmarked" proposals
    60	     * @dev     Reverts if the proposal is neither EXECUTED | EXPIRED | DROPPED | REJECTED
    61	     *          Essentially, if the state can still change, it is seen as alive.
    62	     */
    63	    function markNext() external override(IProtocolTreasury) {
    64	        uint256 proposalId = markedProposalsCount;
    65	        require(proposalId < GOVERNANCE.proposalCount(), NoProposalToMark());
    66	        ProposalState state = GOVERNANCE.getProposalState(proposalId);
    67	
    68	        // state should be either Executed | Expired | Droppped | Reject
    69	        // if that is not the case, it might still be an active proposal and should wait
    70	        require(
    71	            state == ProposalState.Executed || state == ProposalState.Expired || state == ProposalState.Dropped
    72	                || state == ProposalState.Rejected,
    73	            ProposalIsAlive()
    74	        );
    75	
    76	        markedProposalsCount++;
    77	        blockOfLastMarkNext = block.number;
    78	
    79	        emit ProposalMarked(proposalId);
    80	    }
    81	
    82	    /**
    83	     * @notice  Relays the call and potentially transfer ether from self
    84	     *
    85	     * @dev     Reverts if caller is not owner
    86	     * @dev     Reverts if called before GATED_UNTIL
    87	     * @dev     Reverts if called after markNext in the same block
    88	     * @dev     Reverts if the oldest unmarked proposal was created before treasury became active
    89	     *
    90	     * @param target - The address to call
    91	     * @param data - The calldata for the call
    92	     * @param value - The amount of ether (in wei) to forward
    93	     *
    94	     * @return The return value of the function call (as bytes)
    95	     */
    96	    function relay(address target, bytes calldata data, uint256 value)
    97	        external
    98	        override(IProtocolTreasury)
    99	        returns (bytes memory)
   100	    {
   101	        require(msg.sender == address(GOVERNANCE), Ownable.OwnableUnauthorizedAccount(msg.sender));
   102	        require(block.timestamp >= GATED_UNTIL, GateIsClosed("gated until not met"));
   103	
   104	        // We do NOT allow `markNext()` to happen in the same block as `isOpen` because that could allow a
   105	        // governance proposal to be marked during its execution. Which could be used to make `isOpen` pass
   106	        // even though we are in the middle of an execution that was made BEFORE insiders could act.
   107	        require(block.number > blockOfLastMarkNext, GateIsClosed("markNext called this block"));
   108	
   109	        // The only way `governance` can make a `relay` call is through a proposal. If all proposals are marked
   110	        // the all already have happened, and there is nothing to execute.
   111	        // This is implicitly covered by the creation check, as non-existing proposals have creation time 0, which will
   112	        // never be bigger than another uint.
   113	        //
   114	        // Since time always marches forward, if a proposal is made AFTER getActivationTimestamp, then so are
   115	        // all proposals following it. This means that as soon as as `markedProposalsCount` will be the index of a
   116	        // proposal that was created AFTER the getActivationTimestamp there are no need to mark any other proposals
   117	        // as it will keep being true.
   118	        require(
   119	            GOVERNANCE.getProposal(markedProposalsCount).creation > Timestamp.wrap(getActivationTimestamp()),
   120	            GateIsClosed("not activated yet")
   121	        );
   122	
   123	        // Using a mix of low-level calls and OZ lib to handle transfers to non-contracts and easily bubble up.
   124	        require(value == 0 || address(this).balance >= value, Errors.InsufficientBalance(address(this).balance, value));
   125	        (bool success, bytes memory returnData) = payable(target).call{value: value}(data);
   126	        return Address.verifyCallResult(success, returnData);
   127	    }
   128	
   129	    /**
   130	     * @notice Allows receiving ether
   131	     */
   132	    receive() external payable {}
   133	
   134	    /**
   135	     * @notice  The timestamp where the treasury becomes active
   136	     *
   137	     * @return  Timestamp where treasury can relay
   138	     */
   139	    function getActivationTimestamp() public view override(IProtocolTreasury) returns (uint256) {
   140	        return ATP_REGISTRY.getExecuteAllowedAt() + 7 days;
   141	    }
   142	
   143	    /**
   144	     * @notice  Returns the owner (governance)
   145	     *
   146	     * @dev     Exists to make the contract align better with other relayers
   147	     *
   148	     * @return  The address of the governance
   149	     */
   150	    function owner() external view override(IProtocolTreasury) returns (address) {
   151	        return address(GOVERNANCE);
   152	    }
   153	}
```

### src/constants.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	library Constants {
     5	    /// @notice The token decimals
     6	    uint256 public constant TOKEN_DECIMALS = 18;
     7	
     8	    /// @notice The number of basis points in 100%
     9	    uint256 public constant BIPS = 10_000;
    10	}
```

## src/sale/

### src/sale/GenesisSequencerSale.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IATPFactory} from "@atp/ATPFactory.sol";
     5	import {INCATP} from "@atp/atps/noclaim/INCATP.sol";
     6	import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
     7	import {LockLib} from "@atp/libraries/LockLib.sol";
     8	import {Ownable} from "@oz/access/Ownable.sol";
     9	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
    10	import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
    11	import {ReentrancyGuard} from "@oz/utils/ReentrancyGuard.sol";
    12	import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
    13	import {IPredicateProvider} from "src/soulbound/providers/PredicateProvider.sol";
    14	import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
    15	import {IGenesisSequencerSale} from "./IGenesisSequencerSale.sol";
    16	
    17	/**
    18	 * @title GenesisSequencerSale
    19	 * @notice A fixed-price token sale contract that creates NCATPs (must be staked after purchase) with vesting
    20	 * @author Aztec-Labs
    21	 * @dev Uses the ATP (Aztec Token Position - a.k.a Token Vault) system for token vesting and accepts only ETH as payment
    22	 */
    23	contract GenesisSequencerSale is IGenesisSequencerSale, Ownable, ReentrancyGuard {
    24	    using SafeERC20 for IERC20;
    25	
    26	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    27	    /*                       Constants                            */
    28	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    29	    /// @notice The number of token purchases per address - fixed in one transaction
    30	    uint256 public constant PURCHASES_PER_ADDRESS = 5;
    31	    /// @notice The number of tokens per purchase
    32	    uint256 public immutable TOKEN_LOT_SIZE;
    33	    /// @notice The amount of sale tokens to purchase per address
    34	    uint256 public immutable SALE_TOKEN_PURCHASE_AMOUNT;
    35	
    36	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    37	    /*                   Notable Addresses                        */
    38	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    39	    /// @notice The ATP factory contract address
    40	    IATPFactory public immutable ATP_FACTORY;
    41	    /// @notice The token that is being sold
    42	    IERC20 public immutable SALE_TOKEN;
    43	    /// @notice The soulbound token contract address
    44	    IIgnitionParticipantSoulbound public immutable SOULBOUND_TOKEN;
    45	
    46	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    47	    /*                      Updatable by Admin                    */
    48	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    49	    /// @notice The price per sequencer in ETH
    50	    uint256 public pricePerLot;
    51	
    52	    /// @notice The start time of the sale
    53	    uint96 public saleStartTime;
    54	    /// @notice The end time of the sale
    55	    uint96 public saleEndTime;
    56	
    57	    /// @notice Whether the sale is enabled or not
    58	    bool public saleEnabled;
    59	
    60	    /// @notice The screening provider
    61	    address public addressScreeningProvider;
    62	
    63	    /**
    64	     * @notice Has an address already taken part in the sale
    65	     */
    66	    mapping(address addr => bool hasPurchased) public hasPurchased;
    67	
    68	    /**
    69	     * @notice Constructor
    70	     * @param _owner The owner of the contract
    71	     * @param _atpFactory The ATP factory contract address
    72	     * @param _saleToken The token that is being sold
    73	     * @param _soulboundToken The soulbound whitelist token contract address (ERC1155)
    74	     * @param _rollup The rollup address to get activation threshold from
    75	     * @param _pricePerLot Initial price in ETH for TOKEN_LOT_SIZE tokens
    76	     * @param _saleStartTime Sale start timestamp
    77	     * @param _saleEndTime Sale end timestamp
    78	     * @param _addressScreeningProvider The address screening provider contract address
    79	     */
    80	    constructor(
    81	        address _owner,
    82	        IATPFactory _atpFactory,
    83	        IERC20 _saleToken,
    84	        IIgnitionParticipantSoulbound _soulboundToken,
    85	        IStaking _rollup,
    86	        uint256 _pricePerLot,
    87	        uint96 _saleStartTime,
    88	        uint96 _saleEndTime,
    89	        address _addressScreeningProvider
    90	    ) Ownable(_owner) {
    91	        require(
    92	            address(_atpFactory) != address(0) && address(_soulboundToken) != address(0)
    93	                && address(_saleToken) != address(0) && address(_rollup) != address(0),
    94	            GenesisSequencerSale__ZeroAddress()
    95	        );
    96	        require(_pricePerLot > 0, GenesisSequencerSale__InvalidPrice());
    97	        require(_saleStartTime < _saleEndTime, GenesisSequencerSale__InvalidTimeRange());
    98	        require(_saleStartTime >= block.timestamp, GenesisSequencerSale__InvalidTimeRange());
    99	        require(_addressScreeningProvider != address(0), GenesisSequencerSale__ZeroAddress());
   100	
   101	        ATP_FACTORY = _atpFactory;
   102	
   103	        TOKEN_LOT_SIZE = _rollup.getActivationThreshold();
   104	        SALE_TOKEN_PURCHASE_AMOUNT = TOKEN_LOT_SIZE * PURCHASES_PER_ADDRESS;
   105	
   106	        SOULBOUND_TOKEN = _soulboundToken;
   107	        SALE_TOKEN = _saleToken;
   108	
   109	        pricePerLot = _pricePerLot;
   110	        emit PriceUpdated(_pricePerLot);
   111	
   112	        saleStartTime = _saleStartTime;
   113	        saleEndTime = _saleEndTime;
   114	        emit SaleTimesUpdated(_saleStartTime, _saleEndTime);
   115	
   116	        addressScreeningProvider = _addressScreeningProvider;
   117	        emit ScreeningProviderSet(_addressScreeningProvider);
   118	    }
   119	
   120	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   121	    /*                      Sale Functions                        */
   122	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   123	
   124	    /**
   125	     * @notice Purchase tokens SALE_TOKEN_PURCHASE_AMOUNT tokens.
   126	     *
   127	     * @param _atpBeneficiary The address that will receive the ATP
   128	     *
   129	     * @dev Requires the caller to have a soulbound token GENESIS_SEQUENCER (token ID 0)
   130	     * @dev If you are using the same _beneficiary address for the ATP more than once, this function will fail as it will attempt to deploy to the same address.
   131	     */
   132	    function purchase(address _atpBeneficiary, bytes calldata _screeningData)
   133	        external
   134	        payable
   135	        override(IGenesisSequencerSale)
   136	        nonReentrant
   137	    {
   138	        _internalPurchase(_atpBeneficiary, _screeningData);
   139	    }
   140	
   141	    /**
   142	     * @notice Purchase tokens SALE_TOKEN_PURCHASE_AMOUNT tokens.
   143	     * @notice Forwards the data required to mint the soulbound token before calling purchase(_atpBeneficiary)
   144	     * @notice This will result in the soulbound token being minted to the msg.sender, but the ATP will be sent to the _atpBeneficiary address
   145	     *         there is a core invariant that person supplying the tokens holds the soulbound token, as their address is the one that is screened
   146	     *
   147	     * @param _atpBeneficiary The address that will receive the ATP
   148	     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
   149	     * @param _identityProvider The contract address of the identity screening contract - these are allowlisted by the admin
   150	     * @param _identityData Identity data - this is the data that the identity provider will verify
   151	     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
   152	     * @param _gridTileId The grid tile ID that the soulbound recipient is associated with
   153	     *
   154	     * @dev we defer screening checks to the soulbound token contract, rather than duplicate all of the logic here, calling mint (forwarding all data)
   155	     *      will ensure screening checks are done in the same way for everyone
   156	     */
   157	    function purchaseAndMintSoulboundToken(
   158	        address _atpBeneficiary,
   159	        bytes32[] calldata _merkleProof,
   160	        address _identityProvider,
   161	        bytes calldata _identityData,
   162	        bytes calldata _soulboundRecipientScreeningData,
   163	        bytes calldata _atpBeneficiaryScreeningData,
   164	        uint256 _gridTileId
   165	    ) external payable override(IGenesisSequencerSale) nonReentrant {
   166	        SOULBOUND_TOKEN.mintFromSale(
   167	            msg.sender,
   168	            msg.sender,
   169	            _merkleProof,
   170	            _identityProvider,
   171	            _identityData,
   172	            _soulboundRecipientScreeningData,
   173	            _gridTileId
   174	        );
   175	
   176	        // Screening has already been performed in the soulbound token check
   177	        _internalPurchase(_atpBeneficiary, _atpBeneficiaryScreeningData);
   178	    }
   179	
   180	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   181	    /*                      Admin Functions                       */
   182	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   183	
   184	    /**
   185	     * @notice Enable the token sale
   186	     *
   187	     * @dev onlyOwner
   188	     */
   189	    function startSale() external override(IGenesisSequencerSale) onlyOwner {
   190	        saleEnabled = true;
   191	        emit SaleStarted(saleStartTime, saleEndTime);
   192	    }
   193	
   194	    /**
   195	     * @notice Stop the token sale
   196	     *
   197	     * @dev onlyOwner
   198	     */
   199	    function stopSale() external override(IGenesisSequencerSale) onlyOwner {
   200	        saleEnabled = false;
   201	        emit SaleStopped();
   202	    }
   203	
   204	    /**
   205	     * @notice Update price in ETH for TOKEN_LOT_SIZE tokens
   206	     * @param _pricePerLot New price in ETH for TOKEN_LOT_SIZE amount
   207	     *
   208	     * @dev onlyOwner
   209	     */
   210	    function setPricePerLotInEth(uint256 _pricePerLot) external override(IGenesisSequencerSale) onlyOwner {
   211	        require(_pricePerLot > 0, GenesisSequencerSale__InvalidPrice());
   212	        pricePerLot = _pricePerLot;
   213	        emit PriceUpdated(_pricePerLot);
   214	    }
   215	
   216	    /**
   217	     * @notice Set the screening provider
   218	     * @param _addressScreeningProvider The screening provider address
   219	     *
   220	     * @dev onlyOwner
   221	     */
   222	    function setAddressScreeningProvider(address _addressScreeningProvider)
   223	        external
   224	        override(IGenesisSequencerSale)
   225	        onlyOwner
   226	    {
   227	        require(_addressScreeningProvider != address(0), GenesisSequencerSale__ZeroAddress());
   228	
   229	        addressScreeningProvider = _addressScreeningProvider;
   230	        emit ScreeningProviderSet(_addressScreeningProvider);
   231	    }
   232	
   233	    /**
   234	     * @notice Set the sale start and end times
   235	     * @param _saleStartTime Sale start timestamp
   236	     * @param _saleEndTime Sale end timestamp
   237	     *
   238	     * @dev onlyOwner
   239	     */
   240	    function setSaleTimes(uint96 _saleStartTime, uint96 _saleEndTime)
   241	        external
   242	        override(IGenesisSequencerSale)
   243	        onlyOwner
   244	    {
   245	        require(_saleStartTime < _saleEndTime, GenesisSequencerSale__InvalidTimeRange());
   246	        require(_saleStartTime >= block.timestamp, GenesisSequencerSale__InvalidTimeRange());
   247	
   248	        saleStartTime = _saleStartTime;
   249	        saleEndTime = _saleEndTime;
   250	
   251	        emit SaleTimesUpdated(_saleStartTime, _saleEndTime);
   252	    }
   253	
   254	    /**
   255	     * @notice Withdraw tokens from the contract
   256	     * @param _to The address to withdraw the tokens to
   257	     * @param _token Token address to withdraw
   258	     * @param _amount Amount to withdraw
   259	     *
   260	     * @dev onlyOwner
   261	     */
   262	    function withdrawTokens(address _to, address _token, uint256 _amount)
   263	        external
   264	        override(IGenesisSequencerSale)
   265	        onlyOwner
   266	        nonReentrant
   267	    {
   268	        IERC20(_token).safeTransfer(_to, _amount);
   269	        emit TokensWithdrawn(_to, _token, _amount);
   270	    }
   271	
   272	    /**
   273	     * @notice Withdraw ETH from the contract
   274	     * @param _to The address to withdraw the ETH to
   275	     * @param _amount Amount of ETH to withdraw
   276	     *
   277	     * @dev onlyOwner
   278	     */
   279	    function withdrawETH(address _to, uint256 _amount) external override(IGenesisSequencerSale) onlyOwner nonReentrant {
   280	        (bool success,) = _to.call{value: _amount}("");
   281	        require(success, GenesisSequencerSale__ETHTransferFailed());
   282	        emit ETHWithdrawn(_to, _amount);
   283	    }
   284	
   285	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   286	    /*                        View Functions                       */
   287	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   288	    /**
   289	     * @notice Check if the sale is active
   290	     * @return Whether the sale is active
   291	     */
   292	    function isSaleActive() external view override(IGenesisSequencerSale) returns (bool) {
   293	        return saleEnabled && block.timestamp >= saleStartTime && block.timestamp <= saleEndTime;
   294	    }
   295	
   296	    /**
   297	     * @notice Get the purchase cost in ETH
   298	     * @return The purchase cost in ETH
   299	     */
   300	    function getPurchaseCostInEth() public view override(IGenesisSequencerSale) returns (uint256) {
   301	        return PURCHASES_PER_ADDRESS * pricePerLot;
   302	    }
   303	
   304	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   305	    /*                    Internal Functions                      */
   306	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   307	
   308	    /**
   309	     * @notice Internal purchase function
   310	     *
   311	     * @param _beneficiary The address of the beneficiary
   312	     * @param _beneficiaryScreeningData The screening data
   313	     */
   314	    function _internalPurchase(address _beneficiary, bytes memory _beneficiaryScreeningData) internal {
   315	        // Checks
   316	        require(saleEnabled, GenesisSequencerSale__SaleNotEnabled());
   317	        require(block.timestamp >= saleStartTime, GenesisSequencerSale__SaleNotStarted());
   318	        require(block.timestamp <= saleEndTime, GenesisSequencerSale__SaleHasEnded());
   319	
   320	        // Check purchase limit
   321	        require(!hasPurchased[msg.sender], GenesisSequencerSale__AlreadyPurchased());
   322	
   323	        // Calculate required ETH amount
   324	        uint256 purchaseCostInEth = getPurchaseCostInEth();
   325	        require(msg.value == purchaseCostInEth, GenesisSequencerSale__IncorrectETH());
   326	
   327	        // Effects
   328	        hasPurchased[msg.sender] = true;
   329	
   330	        // Interactions
   331	
   332	        // Check the sender is an owner of a soulbound token GENESIS_SEQUENCER (token ID 0)
   333	        // - Ext staticcall (view) -
   334	        require(SOULBOUND_TOKEN.hasGenesisSequencerToken(msg.sender), GenesisSequencerSale__NoSoulboundToken());
   335	
   336	        // If the beneficiary is the msg.sender, screening checks were performed as part of the soulbound token check
   337	        bool performScreening = _beneficiary != msg.sender;
   338	        if (performScreening) {
   339	            // Perform screening
   340	            require(
   341	                IPredicateProvider(addressScreeningProvider).verify(_beneficiary, _beneficiaryScreeningData),
   342	                GenesisSequencerSale__AddressScreeningFailed()
   343	            );
   344	        }
   345	
   346	        // Transfer sale token from here to the ATP factory
   347	        // - Ext call -
   348	        // Revert conditions: will fail if the sale contract does not have enough tokens
   349	        SALE_TOKEN.safeTransfer(address(ATP_FACTORY), SALE_TOKEN_PURCHASE_AMOUNT);
   350	
   351	        // - Ext call -
   352	        // Create ATP for purchaser
   353	        INCATP atp = ATP_FACTORY.createNCATP(
   354	            _beneficiary, // beneficiary
   355	            SALE_TOKEN_PURCHASE_AMOUNT, // allocation
   356	            RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
   357	        );
   358	
   359	        emit SaleTokensPurchased(_beneficiary, msg.sender, address(atp), purchaseCostInEth);
   360	    }
   361	}
```

### src/sale/IGenesisSequencerSale.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	interface IGenesisSequencerSale {
     5	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
     6	    /*                        Events                              */
     7	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
     8	    event SaleTokensPurchased(
     9	        address indexed beneficiary, address indexed operator, address indexed atp, uint256 purchaseCostInEth
    10	    );
    11	    event SaleTimesUpdated(uint256 startTime, uint256 endTime);
    12	    event SaleStarted(uint256 startTime, uint256 endTime);
    13	    event SaleStopped();
    14	    event PriceUpdated(uint256 newPrice);
    15	    event TokensWithdrawn(address indexed to, address indexed token, uint256 amount);
    16	    event ETHWithdrawn(address indexed to, uint256 amount);
    17	    event ScreeningProviderSet(address screeningProvider);
    18	
    19	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    20	    /*                        Errors                              */
    21	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    22	    error GenesisSequencerSale__SaleNotEnabled();
    23	    error GenesisSequencerSale__SaleNotStarted();
    24	    error GenesisSequencerSale__SaleHasEnded();
    25	    error GenesisSequencerSale__ZeroAddress();
    26	    error GenesisSequencerSale__IncorrectETH();
    27	    error GenesisSequencerSale__ETHTransferFailed();
    28	    error GenesisSequencerSale__AlreadyPurchased();
    29	    error GenesisSequencerSale__NoSoulboundToken();
    30	    error GenesisSequencerSale__AddressScreeningFailed();
    31	
    32	    // Constructor errors
    33	    error GenesisSequencerSale__InvalidPrice();
    34	    error GenesisSequencerSale__InvalidTimeRange();
    35	
    36	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    37	    /*                        Functions                           */
    38	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    39	    function purchase(address _beneficiary, bytes calldata _screeningData) external payable;
    40	    function purchaseAndMintSoulboundToken(
    41	        address _beneficiary,
    42	        bytes32[] calldata _merkleProof,
    43	        address _identityProvider,
    44	        bytes calldata _identityData,
    45	        bytes calldata _screeningData,
    46	        bytes calldata _atpBeneficiaryScreeningData,
    47	        uint256 _gridTileId
    48	    ) external payable;
    49	
    50	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    51	    /*                      Admin Functions                       */
    52	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    53	    function startSale() external;
    54	    function stopSale() external;
    55	    function setPricePerLotInEth(uint256 _pricePerLot) external;
    56	    function setSaleTimes(uint96 _saleStartTime, uint96 _saleEndTime) external;
    57	    function setAddressScreeningProvider(address _addressScreeningProvider) external;
    58	    function withdrawTokens(address _to, address _token, uint256 _amount) external;
    59	    function withdrawETH(address _to, uint256 _amount) external;
    60	
    61	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    62	    /*                        View Functions                       */
    63	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    64	    function isSaleActive() external view returns (bool);
    65	    function getPurchaseCostInEth() external view returns (uint256);
    66	    function TOKEN_LOT_SIZE() external view returns (uint256);
    67	    function SALE_TOKEN_PURCHASE_AMOUNT() external view returns (uint256);
    68	}
```

## src/soulbound/

### src/soulbound/IIgnitionParticipantSoulbound.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IERC1155} from "@oz/token/ERC1155/IERC1155.sol";
     5	
     6	interface IIgnitionParticipantSoulbound is IERC1155 {
     7	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
     8	    /*                        Structs                             */
     9	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    10	    enum TokenId {
    11	        GENESIS_SEQUENCER,
    12	        CONTRIBUTOR,
    13	        GENERAL
    14	    }
    15	
    16	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    17	    /*                        Events                              */
    18	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    19	    event IgnitionParticipantSoulboundMinted(
    20	        address indexed _beneficiary, address indexed _operator, TokenId indexed _tokenId, uint256 _gridTileId
    21	    );
    22	    event GenesisSequencerMerkleRootUpdated(bytes32 newRoot);
    23	    event ContributorMerkleRootUpdated(bytes32 newRoot);
    24	    event IdentityProviderSet(address provider, bool active);
    25	    event AddressScreeningProviderSet(address provider);
    26	    event TokenSaleAddressSet(address tokenSaleAddress);
    27	
    28	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    29	    /*                        Errors                              */
    30	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    31	    error IgnitionParticipantSoulbound__CallerIsNotTokenSale();
    32	    error IgnitionParticipantSoulbound__TokenIsSoulbound();
    33	    error IgnitionParticipantSoulbound__AlreadyMinted();
    34	    error IgnitionParticipantSoulbound__GridTileIdCannotBeZero();
    35	    error IgnitionParticipantSoulbound__InvalidAuth(address _authProvider);
    36	    error IgnitionParticipantSoulbound__MerkleProofInvalid();
    37	    error IgnitionParticipantSoulbound__NoMerkleRootSet();
    38	    error IgnitionParticipantSoulbound__InvalidInputLength();
    39	    error IgnitionParticipantSoulbound__GridTileAlreadyAssigned();
    40	
    41	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    42	    /*                       Functions                            */
    43	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    44	    function mint(
    45	        TokenId _tokenId,
    46	        address _beneficiary,
    47	        bytes32[] calldata _merkleProof,
    48	        address _identityProvider,
    49	        bytes calldata _identityData,
    50	        bytes calldata _beneficiaryScreeningData,
    51	        uint256 _gridTileId
    52	    ) external;
    53	
    54	    function mintFromSale(
    55	        address _operator,
    56	        address _beneficiary,
    57	        bytes32[] calldata _merkleProof,
    58	        address _identityProvider,
    59	        bytes calldata _identityData,
    60	        bytes calldata _beneficiaryScreeningData,
    61	        uint256 _gridTileId
    62	    ) external;
    63	
    64	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    65	    /*                        Admin Functions                     */
    66	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    67	    function adminMint(address _to, TokenId _tokenId, uint256 _gridTileId) external;
    68	    function adminBatchMint(address[] calldata _to, TokenId[] calldata _tokenId, uint256[] calldata _gridTileId)
    69	        external;
    70	    function setGenesisSequencerMerkleRoot(bytes32 _genesisSequencerMerkleRoot) external;
    71	    function setContributorMerkleRoot(bytes32 _contributorMerkleRoot) external;
    72	    function setIdentityProvider(address _provider, bool _active) external;
    73	    function setAddressScreeningProvider(address _provider) external;
    74	    function setTokenSaleAddress(address _tokenSaleAddress) external;
    75	
    76	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    77	    /*                      View Functions                        */
    78	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    79	    function hasGenesisSequencerToken(address _addr) external view returns (bool);
    80	    function hasContributorToken(address _addr) external view returns (bool);
    81	    function hasGenesisSequencerTokenOrContributorToken(address _addr) external view returns (bool);
    82	    function hasGeneralToken(address _addr) external view returns (bool);
    83	    function hasAnyToken(address _addr) external view returns (bool);
    84	    function genesisSequencerMerkleRoot() external view returns (bytes32);
    85	    function contributorMerkleRoot() external view returns (bytes32);
    86	    function identityProviders(address _provider) external view returns (bool);
    87	    function gridTileId(address _addr) external view returns (uint256);
    88	}
```

### src/soulbound/IgnitionParticipantSoulbound.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {Ownable} from "@oz/access/Ownable.sol";
     5	import {ERC1155, IERC1155} from "@oz/token/ERC1155/ERC1155.sol";
     6	import {MerkleProof} from "@oz/utils/cryptography/MerkleProof.sol";
     7	import {ReentrancyGuard} from "@oz/utils/ReentrancyGuard.sol";
     8	import {IIgnitionParticipantSoulbound} from "./IIgnitionParticipantSoulbound.sol";
     9	import {IWhitelistProvider} from "./providers/IWhitelistProvider.sol";
    10	
    11	/**
    12	 * @title IgnitionParticipantSoulbound
    13	 * @notice A soulbound ERC1155 token used for whitelist access control
    14	 * @dev Token ID 0: For Genesis Sequencer users
    15	 *      Token ID 1: For Contributor users
    16	 *      Token ID 2: For general de-risked users
    17	 *      Tokens cannot be transferred once minted, making them "soulbound" to the recipient
    18	 */
    19	contract IgnitionParticipantSoulbound is IIgnitionParticipantSoulbound, ERC1155, Ownable, ReentrancyGuard {
    20	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    21	    /*                       State Variables                      */
    22	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    23	
    24	    /// Merkle root for privileged whitelists
    25	    /// @dev Gating for Token ID 0
    26	    bytes32 public genesisSequencerMerkleRoot;
    27	    /// @dev Gating for Token ID 1
    28	    bytes32 public contributorMerkleRoot;
    29	
    30	    /// Whitelist providers
    31	    /// @dev Whitelist providers for general whitelist
    32	    mapping(address provider => bool active) public identityProviders;
    33	
    34	    /// @dev Provider for address screening
    35	    address public addressScreeningProvider;
    36	
    37	    /// @dev Track if an address has minted (can only mint once)
    38	    mapping(address addr => bool hasMinted) public hasMinted;
    39	
    40	    /// @dev Track the grid token ID for each address
    41	    mapping(address soulboundRecipient => uint256 gridTileId) public gridTileId;
    42	    /// @dev Track if a grid tile ID has been assigned
    43	    mapping(uint256 gridTileId => bool isAssigned) public isGridTileIdAssigned;
    44	
    45	    /// @dev Address of the token sale contract
    46	    address public tokenSaleAddress;
    47	
    48	    constructor(
    49	        address _tokenSaleAddress,
    50	        address[] memory _identityProviders,
    51	        bytes32 _genesisSequencerMerkleRoot,
    52	        bytes32 _contributorMerkleRoot,
    53	        address _addressScreeningProvider,
    54	        string memory _uri
    55	    ) ERC1155(_uri) Ownable(msg.sender) {
    56	        tokenSaleAddress = _tokenSaleAddress;
    57	        // Set the initial whitelist providers
    58	        for (uint256 i = 0; i < _identityProviders.length; i++) {
    59	            identityProviders[_identityProviders[i]] = true;
    60	            emit IdentityProviderSet(_identityProviders[i], true);
    61	        }
    62	
    63	        addressScreeningProvider = _addressScreeningProvider;
    64	        emit AddressScreeningProviderSet(_addressScreeningProvider);
    65	
    66	        genesisSequencerMerkleRoot = _genesisSequencerMerkleRoot;
    67	        emit GenesisSequencerMerkleRootUpdated(_genesisSequencerMerkleRoot);
    68	
    69	        contributorMerkleRoot = _contributorMerkleRoot;
    70	        emit ContributorMerkleRootUpdated(_contributorMerkleRoot);
    71	    }
    72	
    73	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    74	    /*                       Mint Functions                        */
    75	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    76	
    77	    /**
    78	     * @notice Mint an IgnitionParticipant token to an address
    79	     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
    80	     * @param _soulboundRecipient The address of the soulbound recipient
    81	     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
    82	     * @param _identityProvider The contract address of the identity provider - these are allowlisted by the admin
    83	     * @param _identityData Identity data - this is the data that the identity provider will verify
    84	     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
    85	     * @dev Only one token per address is allowed
    86	     */
    87	    function mint(
    88	        TokenId _tokenId,
    89	        address _soulboundRecipient,
    90	        bytes32[] calldata _merkleProof,
    91	        address _identityProvider,
    92	        bytes calldata _identityData,
    93	        bytes calldata _soulboundRecipientScreeningData,
    94	        uint256 _gridTileId
    95	    ) external override(IIgnitionParticipantSoulbound) nonReentrant {
    96	        _internalMint(
    97	            msg.sender,
    98	            _tokenId,
    99	            _soulboundRecipient,
   100	            _merkleProof,
   101	            _identityProvider,
   102	            _identityData,
   103	            _soulboundRecipientScreeningData,
   104	            _gridTileId
   105	        );
   106	    }
   107	
   108	    /**
   109	     * @notice Mint an IgnitionParticipant token to an address
   110	     * @param _operator The address of the operator
   111	     * @param _soulboundRecipient The address of the soulbound recipient
   112	     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
   113	     * @param _identityProvider The contract address of the identity provider - these are allowlisted by the admin
   114	     * @param _identityData Identity data - this is the data that the identity provider will verify
   115	     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
   116	     * @param _gridTileId The grid tile ID that the soulbound recipient is associated with
   117	     * @dev Only one token per address is allowed
   118	     */
   119	    function mintFromSale(
   120	        address _operator,
   121	        address _soulboundRecipient,
   122	        bytes32[] calldata _merkleProof,
   123	        address _identityProvider,
   124	        bytes calldata _identityData,
   125	        bytes calldata _soulboundRecipientScreeningData,
   126	        uint256 _gridTileId
   127	    ) external override(IIgnitionParticipantSoulbound) nonReentrant {
   128	        // Check that the caller is the token sale contract
   129	        require(msg.sender == tokenSaleAddress, IgnitionParticipantSoulbound__CallerIsNotTokenSale());
   130	
   131	        // Call mint, allowing the token sale contract to set the operator as the msg.sender of the sale
   132	        // The sale is limited to GENESIS_SEQUENCER (token ID 0), so we can hardcode it here
   133	        _internalMint(
   134	            _operator,
   135	            IIgnitionParticipantSoulbound.TokenId.GENESIS_SEQUENCER,
   136	            _soulboundRecipient,
   137	            _merkleProof,
   138	            _identityProvider,
   139	            _identityData,
   140	            _soulboundRecipientScreeningData,
   141	            _gridTileId
   142	        );
   143	    }
   144	
   145	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   146	    /*                       Admin Functions                       */
   147	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   148	
   149	    /**
   150	     * @notice Set the address of the token sale contract
   151	     * @param _tokenSaleAddress The address of the token sale contract
   152	     *
   153	     * @dev onlyOwner
   154	     */
   155	    function setTokenSaleAddress(address _tokenSaleAddress) external override(IIgnitionParticipantSoulbound) onlyOwner {
   156	        tokenSaleAddress = _tokenSaleAddress;
   157	        emit TokenSaleAddressSet(_tokenSaleAddress);
   158	    }
   159	
   160	    /**
   161	     * @notice Mint an IgnitionParticipant token to an address
   162	     * @param _to The address to mint the token to
   163	     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
   164	     * @param _gridTileId The grid tile ID to mint
   165	     *
   166	     * @dev onlyOwner
   167	     */
   168	    function adminMint(address _to, TokenId _tokenId, uint256 _gridTileId)
   169	        external
   170	        override(IIgnitionParticipantSoulbound)
   171	        onlyOwner
   172	        nonReentrant
   173	    {
   174	        _internalAdminMint(_to, _tokenId, _gridTileId);
   175	    }
   176	
   177	    /**
   178	     * @notice Batch mint IgnitionParticipant tokens to an array of addresses
   179	     * @param _to The addresses to mint the tokens to
   180	     * @param _tokenId The token IDs to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
   181	     * @param _gridTileId The grid tile IDs to mint
   182	     *
   183	     * @dev onlyOwner
   184	     */
   185	    function adminBatchMint(address[] calldata _to, TokenId[] calldata _tokenId, uint256[] calldata _gridTileId)
   186	        external
   187	        override(IIgnitionParticipantSoulbound)
   188	        onlyOwner
   189	        nonReentrant
   190	    {
   191	        require(_to.length == _tokenId.length, IgnitionParticipantSoulbound__InvalidInputLength());
   192	        require(_to.length == _gridTileId.length, IgnitionParticipantSoulbound__InvalidInputLength());
   193	
   194	        for (uint256 i = 0; i < _to.length; i++) {
   195	            _internalAdminMint(_to[i], _tokenId[i], _gridTileId[i]);
   196	        }
   197	    }
   198	
   199	    /**
   200	     * @notice Set the genesis sequencer merkle root
   201	     * @param _genesisSequencerMerkleRoot The new merkle root
   202	     *
   203	     * @dev onlyOwner
   204	     */
   205	    function setGenesisSequencerMerkleRoot(bytes32 _genesisSequencerMerkleRoot)
   206	        external
   207	        override(IIgnitionParticipantSoulbound)
   208	        onlyOwner
   209	    {
   210	        genesisSequencerMerkleRoot = _genesisSequencerMerkleRoot;
   211	        emit GenesisSequencerMerkleRootUpdated(_genesisSequencerMerkleRoot);
   212	    }
   213	
   214	    /**
   215	     * @notice Set the contributor merkle root
   216	     * @param _contributorMerkleRoot The new merkle root
   217	     *
   218	     * @dev onlyOwner
   219	     */
   220	    function setContributorMerkleRoot(bytes32 _contributorMerkleRoot)
   221	        external
   222	        override(IIgnitionParticipantSoulbound)
   223	        onlyOwner
   224	    {
   225	        contributorMerkleRoot = _contributorMerkleRoot;
   226	        emit ContributorMerkleRootUpdated(_contributorMerkleRoot);
   227	    }
   228	
   229	    /**
   230	     * @notice Set the whitelist provider
   231	     * @param _provider The address of the whitelist provider
   232	     * @param _active Whether the provider is active
   233	     *
   234	     * @dev onlyOwner
   235	     */
   236	    function setIdentityProvider(address _provider, bool _active)
   237	        external
   238	        override(IIgnitionParticipantSoulbound)
   239	        onlyOwner
   240	    {
   241	        identityProviders[_provider] = _active;
   242	        emit IdentityProviderSet(_provider, _active);
   243	    }
   244	
   245	    /**
   246	     * @notice Set the screening provider
   247	     * @param _provider The address of the screening provider
   248	     *
   249	     * @dev onlyOwner
   250	     */
   251	    function setAddressScreeningProvider(address _provider) external override(IIgnitionParticipantSoulbound) onlyOwner {
   252	        addressScreeningProvider = _provider;
   253	        emit AddressScreeningProviderSet(_provider);
   254	    }
   255	
   256	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   257	    /*                       View Functions                      */
   258	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   259	
   260	    /**
   261	     * @notice Check if an address has the merkle whitelist token
   262	     * @param _addr Address to check
   263	     * @return bool True if the address owns token ID 0
   264	     */
   265	    function hasGenesisSequencerToken(address _addr)
   266	        external
   267	        view
   268	        override(IIgnitionParticipantSoulbound)
   269	        returns (bool)
   270	    {
   271	        return balanceOf(_addr, uint256(TokenId.GENESIS_SEQUENCER)) > 0;
   272	    }
   273	
   274	    /**
   275	     * @notice Check if an address has the contributor whitelist token
   276	     * @param _addr Address to check
   277	     * @return bool True if the address owns token ID 1
   278	     */
   279	    function hasContributorToken(address _addr) external view override(IIgnitionParticipantSoulbound) returns (bool) {
   280	        return balanceOf(_addr, uint256(TokenId.CONTRIBUTOR)) > 0;
   281	    }
   282	
   283	    /**
   284	     * @notice Check if an address has the general token
   285	     * @param _addr Address to check
   286	     * @return bool True if the address owns token ID 2
   287	     */
   288	    function hasGeneralToken(address _addr) external view override(IIgnitionParticipantSoulbound) returns (bool) {
   289	        return balanceOf(_addr, uint256(TokenId.GENERAL)) > 0;
   290	    }
   291	
   292	    /**
   293	     * Check if an address has the genesis sequencer or contributor token
   294	     * @param _addr Address to check
   295	     * @return bool True if the address owns token ID 0 or 1
   296	     */
   297	    function hasGenesisSequencerTokenOrContributorToken(address _addr)
   298	        external
   299	        view
   300	        override(IIgnitionParticipantSoulbound)
   301	        returns (bool)
   302	    {
   303	        return balanceOf(_addr, uint256(TokenId.GENESIS_SEQUENCER)) > 0
   304	            || balanceOf(_addr, uint256(TokenId.CONTRIBUTOR)) > 0;
   305	    }
   306	
   307	    /**
   308	     * @notice Check if an address has any token
   309	     * @param _addr Address to check
   310	     * @return bool True if the address owns any token ID (0,1, or 2)
   311	     */
   312	    function hasAnyToken(address _addr) external view override(IIgnitionParticipantSoulbound) returns (bool) {
   313	        return balanceOf(_addr, uint256(TokenId.GENESIS_SEQUENCER)) > 0
   314	            || balanceOf(_addr, uint256(TokenId.CONTRIBUTOR)) > 0 || balanceOf(_addr, uint256(TokenId.GENERAL)) > 0;
   315	    }
   316	
   317	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   318	    /*            ERC1155 Soulbound Override Functions            */
   319	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   320	
   321	    /**
   322	     * @dev See {ERC1155-setApprovalForAll}. Overridden to prevent approvals.
   323	     */
   324	    function setApprovalForAll(address, bool) public pure override(IERC1155, ERC1155) {
   325	        revert IgnitionParticipantSoulbound__TokenIsSoulbound();
   326	    }
   327	
   328	    /**
   329	     * @dev See {ERC1155-_update}. Overridden to prevent transfers (soulbound).
   330	     */
   331	    function _update(address _from, address _to, uint256[] memory _ids, uint256[] memory _values)
   332	        internal
   333	        override(ERC1155)
   334	    {
   335	        // Allow minting (_from == address(0))
   336	        // Prevent transfers (_from != address(0))
   337	        if (_from != address(0)) {
   338	            revert IgnitionParticipantSoulbound__TokenIsSoulbound();
   339	        }
   340	
   341	        super._update(_from, _to, _ids, _values);
   342	    }
   343	
   344	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   345	    /*                     Internal Functions                     */
   346	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   347	
   348	    /**
   349	     * @notice Internal function to mint a token to an address
   350	     * @param _identityAddress The address of the identity - checked to be in merkle tree's + identity provider checks
   351	     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
   352	     * @param _soulboundRecipient The address of the soulbound recipient
   353	     * @param _merkleProof Merkle proof for token ID 0 or 1, can be empty for minting token ID 2
   354	     * @param _identityProvider The contract address of the identity provider - these are allowlisted by the admin
   355	     * @param _identityData Identity data - this is the data that the identity provider will verify
   356	     * @param _soulboundRecipientScreeningData Screening data for the soulbound recipient - this is the data that the address screening provider will verify
   357	     * @param _gridTileId The grid token ID to mint
   358	     */
   359	    function _internalMint(
   360	        address _identityAddress,
   361	        TokenId _tokenId,
   362	        address _soulboundRecipient,
   363	        bytes32[] calldata _merkleProof,
   364	        address _identityProvider,
   365	        bytes calldata _identityData,
   366	        bytes calldata _soulboundRecipientScreeningData,
   367	        uint256 _gridTileId
   368	    ) internal {
   369	        // Assert that the user has not minted yet
   370	        require(!hasMinted[_identityAddress], IgnitionParticipantSoulbound__AlreadyMinted());
   371	        hasMinted[_identityAddress] = true;
   372	
   373	        require(_gridTileId != 0, IgnitionParticipantSoulbound__GridTileIdCannotBeZero());
   374	
   375	        // Assert that the grid token ID has not already been assigned
   376	        require(!isGridTileIdAssigned[_gridTileId], IgnitionParticipantSoulbound__GridTileAlreadyAssigned());
   377	        isGridTileIdAssigned[_gridTileId] = true;
   378	
   379	        gridTileId[_soulboundRecipient] = _gridTileId;
   380	
   381	        // Verify identity provider is whitelisted
   382	        require(identityProviders[_identityProvider], IgnitionParticipantSoulbound__InvalidAuth(_identityProvider));
   383	
   384	        if (_tokenId == TokenId.GENESIS_SEQUENCER) {
   385	            // Verify merkle proof for genesis sequencer whitelist
   386	            require(genesisSequencerMerkleRoot != bytes32(0), IgnitionParticipantSoulbound__NoMerkleRootSet());
   387	
   388	            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_identityAddress))));
   389	            require(
   390	                MerkleProof.verify(_merkleProof, genesisSequencerMerkleRoot, leaf),
   391	                IgnitionParticipantSoulbound__MerkleProofInvalid()
   392	            );
   393	        } else if (_tokenId == TokenId.CONTRIBUTOR) {
   394	            // Verify merkle proof for contributor whitelist
   395	            require(contributorMerkleRoot != bytes32(0), IgnitionParticipantSoulbound__NoMerkleRootSet());
   396	
   397	            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_identityAddress))));
   398	            require(
   399	                MerkleProof.verify(_merkleProof, contributorMerkleRoot, leaf),
   400	                IgnitionParticipantSoulbound__MerkleProofInvalid()
   401	            );
   402	        }
   403	        // Further steps required for all cases
   404	
   405	        // Ext call
   406	        // Perform sanctions check on the identity address
   407	        require(
   408	            IWhitelistProvider(_identityProvider).verify(_identityAddress, _identityData),
   409	            IgnitionParticipantSoulbound__InvalidAuth(_identityProvider)
   410	        );
   411	
   412	        // Ext call
   413	        // Perform sanctions check on the _soulboundRecipient address
   414	        require(
   415	            IWhitelistProvider(addressScreeningProvider).verify(_soulboundRecipient, _soulboundRecipientScreeningData),
   416	            IgnitionParticipantSoulbound__InvalidAuth(addressScreeningProvider)
   417	        );
   418	
   419	        // Ext call - with possible reentrancy on acceptance check - nonReentrant added to prevent
   420	        _mint(_soulboundRecipient, uint256(_tokenId), 1, "");
   421	
   422	        emit IgnitionParticipantSoulboundMinted(_soulboundRecipient, _identityAddress, _tokenId, _gridTileId);
   423	    }
   424	
   425	    /**
   426	     * @notice Internal function to mint a token to an address
   427	     * @param _to The address to mint the token to
   428	     * @param _tokenId The token ID to mint (0 for GENESIS_SEQUENCER, 1 for CONTRIBUTOR, 2 for GENERAL)
   429	     * @param _gridTileId The grid tile ID to mint
   430	     */
   431	    function _internalAdminMint(address _to, TokenId _tokenId, uint256 _gridTileId) internal {
   432	        // The user must not have minted yet
   433	        require(!hasMinted[_to], IgnitionParticipantSoulbound__AlreadyMinted());
   434	        hasMinted[_to] = true;
   435	        gridTileId[_to] = _gridTileId;
   436	
   437	        require(!isGridTileIdAssigned[_gridTileId], IgnitionParticipantSoulbound__GridTileAlreadyAssigned());
   438	        isGridTileIdAssigned[_gridTileId] = true;
   439	
   440	        _mint(_to, uint256(_tokenId), 1, "");
   441	
   442	        emit IgnitionParticipantSoulboundMinted(_to, msg.sender, _tokenId, _gridTileId);
   443	    }
   444	}
```

## src/soulbound/providers/

### src/soulbound/providers/AttestationProvider.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {Ownable} from "@oz/access/Ownable.sol";
     5	import {ECDSA} from "@oz/utils/cryptography/ECDSA.sol";
     6	import {EIP712} from "@oz/utils/cryptography/EIP712.sol";
     7	import {IWhitelistProvider} from "./IWhitelistProvider.sol";
     8	
     9	struct Attestation {
    10	    /// @notice The token id of the attestation is valid for
    11	    uint256 tokenId;
    12	    /// @notice The signature provider - from the attestation authority
    13	    bytes signature;
    14	}
    15	
    16	interface IAttestationProvider is IWhitelistProvider {
    17	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    18	    /*                        Events                              */
    19	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    20	    event AttestationAuthoritySet(address indexed attestationAuthority);
    21	
    22	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    23	    /*                        Errors                              */
    24	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    25	    error AttestationProvider__InvalidAttestation();
    26	
    27	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    28	    /*                     Admin Functions                        */
    29	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    30	    function setAttestationAuthority(address _attestationAuthority) external;
    31	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    32	    /*                      View Functions                        */
    33	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    34	    function DOMAIN_SEPARATOR() external view returns (bytes32);
    35	}
    36	
    37	/**
    38	 * @title AttestationProvider
    39	 * @author Aztec-Labs
    40	 * @notice A Provider that verifies an attestation to some action verified offchain.
    41	 */
    42	contract AttestationProvider is IWhitelistProvider, IAttestationProvider, Ownable, EIP712 {
    43	    using ECDSA for bytes32;
    44	
    45	    bytes32 private constant ATTESTATION_TYPEHASH =
    46	        keccak256("Attestation(address provider,address attestationAuthority,address user,uint256 tokenId)");
    47	
    48	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    49	    /*                   State Variables                          */
    50	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    51	    /// @notice The consumer of the provider - the soulbound contract
    52	    address public consumer;
    53	
    54	    /// @notice The attestation authority - the address that can sign attestations
    55	    address public attestationAuthority;
    56	
    57	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    58	    /*                     Constructor                            */
    59	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    60	    /**
    61	     * @notice Constructor
    62	     * @param _consumer The consumer of the provider - the soulbound contract
    63	     * @param _attestationAuthority The attestation authority - the address that can sign attestations
    64	     */
    65	    constructor(address _consumer, address _attestationAuthority)
    66	        Ownable(msg.sender)
    67	        EIP712("AttestationProvider", "1")
    68	    {
    69	        consumer = _consumer;
    70	        attestationAuthority = _attestationAuthority;
    71	    }
    72	
    73	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    74	    /*                    Admin Functions                         */
    75	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    76	    /**
    77	     * @param _attestationAuthority The attestation authority - the address that can sign attestations
    78	     * @dev onlyOwner
    79	     */
    80	    function setAttestationAuthority(address _attestationAuthority) external override(IAttestationProvider) onlyOwner {
    81	        attestationAuthority = _attestationAuthority;
    82	        emit AttestationAuthoritySet(_attestationAuthority);
    83	    }
    84	
    85	    /**
    86	     * @param _consumer The consumer of the provider - the soulbound contract
    87	     * @dev onlyOwner
    88	     */
    89	    function setConsumer(address _consumer) external override(IWhitelistProvider) onlyOwner {
    90	        consumer = _consumer;
    91	        emit ConsumerSet(_consumer);
    92	    }
    93	
    94	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    95	    /*                       Verify Logic                         */
    96	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    97	    /**
    98	     * @notice Verifies an attestation
    99	     * @param _user The user's address
   100	     * @param _auth The authentication data
   101	     * @return True if the attestation is valid
   102	     */
   103	    function verify(address _user, bytes memory _auth) external view override(IWhitelistProvider) returns (bool) {
   104	        // The call must come from the expected consumer, such that _user field cannot be spoofed
   105	        require(msg.sender == consumer, WhitelistProvider__InvalidConsumer());
   106	
   107	        // Decode the attestation from _auth
   108	        Attestation memory attestation = abi.decode(_auth, (Attestation));
   109	
   110	        // Validate signature length (should be 65 bytes: r + s + v)
   111	        require(attestation.signature.length == 65, AttestationProvider__InvalidAttestation());
   112	
   113	        // Create the structured data hash
   114	        bytes32 structHash = keccak256(
   115	            abi.encode(ATTESTATION_TYPEHASH, address(this), attestationAuthority, _user, attestation.tokenId)
   116	        );
   117	        bytes32 digest = _hashTypedDataV4(structHash);
   118	
   119	        // Recover the signer and verify it's the attestation authority
   120	        address signer = digest.recover(attestation.signature);
   121	        require(signer == attestationAuthority, AttestationProvider__InvalidAttestation());
   122	
   123	        return true;
   124	    }
   125	
   126	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   127	    /*                     View Functions                         */
   128	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   129	    function DOMAIN_SEPARATOR() external view override(IAttestationProvider) returns (bytes32) {
   130	        return _domainSeparatorV4();
   131	    }
   132	}
```

### src/soulbound/providers/IWhitelistProvider.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	interface IWhitelistProvider {
     5	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
     6	    /*                        Events                              */
     7	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
     8	    event ConsumerSet(address indexed consumer);
     9	
    10	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    11	    /*                        Errors                              */
    12	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    13	    error WhitelistProvider__InvalidConsumer();
    14	
    15	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    16	    /*                       Functions                            */
    17	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    18	    function setConsumer(address _consumer) external;
    19	
    20	    /**
    21	     * @notice Verify the authentication data
    22	     * @param _user The address of the user to verify
    23	     * @param _auth The authentication data
    24	     * @return bool True if the authentication data is valid
    25	     */
    26	    function verify(address _user, bytes memory _auth) external returns (bool);
    27	}
```

### src/soulbound/providers/PredicateProvider.sol
```solidity
     1	// SPDX-License-Identifier: MIT
     2	pragma solidity ^0.8.27;
     3	
     4	import {Ownable} from "@oz/access/Ownable.sol";
     5	import {PredicateMessage} from "@predicate/interfaces/IPredicateClient.sol";
     6	import {IPredicateClient} from "@predicate/interfaces/IPredicateClient.sol";
     7	import {PredicateClient} from "@predicate/mixins/PredicateClient.sol";
     8	import {IWhitelistProvider} from "./IWhitelistProvider.sol";
     9	
    10	interface IPredicateProvider is IWhitelistProvider, IPredicateClient {
    11	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    12	    /*                        Events                              */
    13	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    14	    event PolicySet(string indexed policyID);
    15	    event PredicateManagerSet(address indexed predicateManager);
    16	
    17	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    18	    /*                        Errors                              */
    19	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    20	    error PredicateProvider__AuthorizationFailed();
    21	}
    22	
    23	interface IPredicateAction {
    24	    function predicateAttestation(address _provider, address _user) external;
    25	}
    26	
    27	contract PredicateProvider is IWhitelistProvider, IPredicateProvider, Ownable, PredicateClient {
    28	    /// @notice The consumer of the provider - the soulbound contract
    29	    address public consumer;
    30	
    31	    /**
    32	     * @notice Constructor
    33	     * @param _owner The owner of the contract
    34	     * @param _predicateManager The predicate manager address
    35	     * @param _policyID The policy ID
    36	     *
    37	     * @dev Ownable
    38	     * @dev PredicateClient
    39	     */
    40	    constructor(address _owner, address _predicateManager, string memory _policyID) Ownable(_owner) {
    41	        _initPredicateClient(_predicateManager, _policyID);
    42	    }
    43	
    44	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    45	    /*                       Verify Logic                         */
    46	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    47	
    48	    /**
    49	     * @notice Verify the authentication data
    50	     *
    51	     * Check against the existing policy that the user has completed a sanctions check
    52	     *
    53	     * @param _user The address of the user to verify
    54	     * @param _auth The authentication data - PredicateMessage
    55	     * @return bool True if the authentication data is valid
    56	     */
    57	    function verify(address _user, bytes memory _auth) external override(IWhitelistProvider) returns (bool) {
    58	        // The call must come from the expected consumer, such that _user field cannot be spoofed
    59	        require(msg.sender == consumer, WhitelistProvider__InvalidConsumer());
    60	
    61	        PredicateMessage memory predicateMessage = abi.decode(_auth, (PredicateMessage));
    62	        bytes memory encodedSigAndArgs =
    63	            abi.encodeWithSelector(IPredicateAction.predicateAttestation.selector, address(this), _user);
    64	
    65	        require(
    66	            _authorizeTransaction(predicateMessage, encodedSigAndArgs, _user, 0),
    67	            PredicateProvider__AuthorizationFailed()
    68	        );
    69	
    70	        return true;
    71	    }
    72	
    73	    /**
    74	     * @notice Set the consumer address
    75	     * @param _consumer The consumer address
    76	     *
    77	     * @dev onlyOwner
    78	     */
    79	    function setConsumer(address _consumer) external override(IWhitelistProvider) onlyOwner {
    80	        consumer = _consumer;
    81	        emit ConsumerSet(_consumer);
    82	    }
    83	
    84	    /**
    85	     * @notice Set the policy ID
    86	     * @param _policyID The policy ID
    87	     *
    88	     * @dev onlyOwner
    89	     */
    90	    function setPolicy(string memory _policyID) external override(IPredicateClient) onlyOwner {
    91	        _setPolicy(_policyID);
    92	        emit PolicySet(_policyID);
    93	    }
    94	
    95	    /**
    96	     * @notice Set the predicate manager address
    97	     * @param _predicateManager The predicate manager address
    98	     *
    99	     * @dev onlyOwner
   100	     */
   101	    function setPredicateManager(address _predicateManager) external override(IPredicateClient) onlyOwner {
   102	        _setPredicateManager(_predicateManager);
   103	        emit PredicateManagerSet(_predicateManager);
   104	    }
   105	}
```

### src/soulbound/providers/ZKPassportProvider.sol
```solidity
     1	
     2	// SPDX-License-Identifier: Apache-2.0
     3	pragma solidity ^0.8.27;
     4	
     5	import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
     6	import {
     7	    ProofVerificationParams,
     8	    BoundData,
     9	    FaceMatchMode,
    10	    OS
    11	} from "@zkpassport/Types.sol";
    12	import {ZKPassportHelper} from "@zkpassport/ZKPassportHelper.sol";
    13	import {ZKPassportRootVerifier} from "@zkpassport/ZKPassportRootVerifier.sol";
    14	import {IWhitelistProvider} from "./IWhitelistProvider.sol";
    15	import {IZKPassportProviderLegacy} from "./ZKPassportProviderLegacy.sol";
    16	import {ZKPassportProviderLegacy} from "./ZKPassportProviderLegacy.sol";
    17	
    18	interface IZKPassportProvider is IZKPassportProviderLegacy {
    19	    function portNullifiers(bytes32[] memory _nullifier) external;
    20	}
    21	
    22	/**
    23	 * @title ZKPassportProvider
    24	 * @author Aztec-Labs
    25	 * @notice A Provider that verifies a zk passport proof, keeping track of nullifier hashes.
    26	 */
    27	contract ZKPassportProvider is ZKPassportProviderLegacy, IZKPassportProvider {
    28	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    29	    /*                     Constructor                            */
    30	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    31	    /**
    32	     * @notice Constructor
    33	     * @param _consumer The consumer of the provider - the soulbound contract
    34	     * @param _zkPassportVerifier The address of the zk passport verifier
    35	     * @param _domain The domain of the proof - the sale website
    36	     * @param _scope The scope of the passport - the action being verified
    37	     */
    38	    constructor(address _consumer, address _zkPassportVerifier, string memory _domain, string memory _scope)
    39	        ZKPassportProviderLegacy(_consumer, _zkPassportVerifier, _domain, _scope)
    40	    {}
    41	
    42	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    43	    /*                       Verify Logic                         */
    44	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    45	    /**
    46	     * @notice Verifies a zk passport proof
    47	     * @param _user The user's address
    48	     * @param _auth The authentication data
    49	     * @return True if the proof is valid
    50	     */
    51	    function verify(address _user, bytes memory _auth) external override(ZKPassportProviderLegacy, IWhitelistProvider) returns (bool) {
    52	        // The call must come from the expected consumer, such that _user field cannot be spoofed
    53	        require(msg.sender == consumer, WhitelistProvider__InvalidConsumer());
    54	
    55	        ProofVerificationParams memory params = abi.decode(_auth, (ProofVerificationParams));
    56	
    57	        require(params.serviceConfig.devMode == false, ZKPassportProvider__InvalidProof());
    58	        require(
    59	            keccak256(bytes(params.serviceConfig.domain)) == keccak256(bytes(domain)),
    60	            ZKPassportProvider__InvalidDomain()
    61	        );
    62	        require(
    63	            keccak256(bytes(params.serviceConfig.scope)) == keccak256(bytes(scope)), ZKPassportProvider__InvalidScope()
    64	        );
    65	        require(
    66	            params.serviceConfig.validityPeriodInSeconds == VALIDITY_PERIOD, ZKPassportProvider__InvalidValidityPeriod()
    67	        );
    68	
    69	        (bool verified, bytes32 nullifier, ZKPassportHelper helper) = zkPassportVerifier.verify(params);
    70	
    71	        require(verified, ZKPassportProvider__InvalidProof());
    72	        require(nullifierHashes[nullifier] == false, ZKPassportProvider__SybilDetected(nullifier));
    73	        nullifierHashes[nullifier] = true;
    74	
    75	        // Bind data check
    76	        BoundData memory boundData = helper.getBoundData(params.committedInputs);
    77	        require(boundData.senderAddress == _user, ZKPassportProvider__InvalidBoundAddress());
    78	        require(boundData.chainId == block.chainid, ZKPassportProvider__InvalidBoundChainId());
    79	        require(bytes(boundData.customData).length == 0, ZKPassportProvider__ExtraDiscloseDataNonZero());
    80	
    81	        // Age check
    82	        bool isAgeValid = helper.isAgeAboveOrEqual(MIN_AGE, params.committedInputs);
    83	        require(isAgeValid, ZKPassportProvider__InvalidAge());
    84	
    85	        // Country exclusion check
    86	        string[] memory excludedCountries = new string[](3);
    87	        excludedCountries[0] = CUB;
    88	        excludedCountries[1] = IRN;
    89	        excludedCountries[2] = PKR;
    90	        bool isCountryValid = helper.isNationalityOut(excludedCountries, params.committedInputs);
    91	        require(isCountryValid, ZKPassportProvider__InvalidCountry());
    92	
    93	        // reverts internally if the sanctions check fails
    94	        helper.enforceSanctionsRoot(block.timestamp, true, params.committedInputs);
    95	
    96	        // Face match check
    97	        bool isFaceMatchValid = helper.isFaceMatchVerified(
    98	            FaceMatchMode.STRICT, OS.ANY, params.committedInputs
    99	        );
   100	        require(isFaceMatchValid, ZKPassportProvider__InvalidFaceMatch());
   101	
   102	        return true;
   103	    }
   104	
   105	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   106	    /*                    Admin Functions                         */
   107	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   108	    /**
   109	      * @dev 
   110	      * @param _nullifiers Unique identifiers to prefill into the list
   111	      */
   112	    function portNullifiers(bytes32[] memory _nullifiers) external override(IZKPassportProvider) onlyOwner {
   113	      for (uint256 i; i < _nullifiers.length;) {
   114	        nullifierHashes[_nullifiers[i]] = true;
   115	
   116	        unchecked {
   117	          ++i;
   118	        }
   119	      }
   120	    }
   121	}
```

### src/soulbound/providers/ZKPassportProviderLegacy.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
     5	import {
     6	    ProofVerificationParams,
     7	    BoundData,
     8	    FaceMatchMode,
     9	    OS
    10	} from "@zkpassport/Types.sol";
    11	import {ZKPassportHelper} from "@zkpassport/ZKPassportHelper.sol";
    12	import {ZKPassportRootVerifier} from "@zkpassport/ZKPassportRootVerifier.sol";
    13	import {IWhitelistProvider} from "./IWhitelistProvider.sol";
    14	
    15	interface IZKPassportProviderLegacy is IWhitelistProvider {
    16	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    17	    /*                        Events                              */
    18	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    19	    event DomainSet(string indexed domain);
    20	    event ScopeSet(string indexed scope);
    21	    event ZKPassportVerifierSet(address indexed zkPassportVerifier);
    22	
    23	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    24	    /*                        Errors                              */
    25	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    26	    error ZKPassportProvider__InvalidProof();
    27	    error ZKPassportProvider__SybilDetected(bytes32 _nullifier);
    28	    error ZKPassportProvider__InvalidCountry();
    29	    error ZKPassportProvider__InvalidAge();
    30	    error ZKPassportProvider__InvalidBoundAddress();
    31	    error ZKPassportProvider__InvalidBoundChainId();
    32	    error ZKPassportProvider__InvalidDomain();
    33	    error ZKPassportProvider__InvalidScope();
    34	    error ZKPassportProvider__InvalidValidityPeriod();
    35	    error ZKPassportProvider__ExtraDiscloseDataNonZero();
    36	    error ZKPassportProvider__InvalidFaceMatch();
    37	
    38	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    39	    /*                   Admin Functions                          */
    40	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    41	    function setZKPassportVerifier(address _zkPassportVerifier) external;
    42	    function setDomain(string memory _domain) external;
    43	    function setScope(string memory _scope) external;
    44	}
    45	
    46	/**
    47	 * @title ZKPassportProvider
    48	 * @author Aztec-Labs
    49	 * @notice A Provider that verifies a zk passport proof, keeping track of nullifier hashes.
    50	 */
    51	contract ZKPassportProviderLegacy is IZKPassportProviderLegacy, Ownable {
    52	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    53	    /*                       Constants                            */
    54	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    55	
    56	    // Excluded countries
    57	    string internal constant PKR = "PRK";
    58	    string internal constant UKR = "UKR";
    59	    string internal constant IRN = "IRN";
    60	    string internal constant CUB = "CUB";
    61	
    62	    // Minimum age
    63	    uint8 public constant MIN_AGE = 18;
    64	
    65	    // Validity period in seconds
    66	    uint256 public constant VALIDITY_PERIOD = 7 days;
    67	
    68	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    69	    /*                   State Variables                          */
    70	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    71	    mapping(bytes32 nullifier => bool used) public nullifierHashes;
    72	
    73	    /// @notice The zk passport verifier - contains zk proof verification logic
    74	    ZKPassportRootVerifier public zkPassportVerifier;
    75	
    76	    /// @notice The domain of the proof - the sale website
    77	    string public domain;
    78	
    79	    /// @notice The scope of the passport - the action being verified
    80	    string public scope;
    81	
    82	    /// @notice The consumer of the provider - the soulbound contract
    83	    address public consumer;
    84	
    85	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    86	    /*                     Constructor                            */
    87	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    88	    /**
    89	     * @notice Constructor
    90	     * @param _consumer The consumer of the provider - the soulbound contract
    91	     * @param _zkPassportVerifier The address of the zk passport verifier
    92	     * @param _domain The domain of the proof - the sale website
    93	     * @param _scope The scope of the passport - the action being verified
    94	     */
    95	    constructor(address _consumer, address _zkPassportVerifier, string memory _domain, string memory _scope)
    96	        Ownable(msg.sender)
    97	    {
    98	        zkPassportVerifier = ZKPassportRootVerifier(_zkPassportVerifier);
    99	        consumer = _consumer;
   100	
   101	        domain = _domain;
   102	        emit DomainSet(_domain);
   103	
   104	        scope = _scope;
   105	        emit ScopeSet(_scope);
   106	    }
   107	
   108	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   109	    /*                       Verify Logic                         */
   110	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   111	    /**
   112	     * @notice Verifies a zk passport proof
   113	     * @param _user The user's address
   114	     * @param _auth The authentication data
   115	     * @return True if the proof is valid
   116	     */
   117	    function verify(address _user, bytes memory _auth) external virtual override(IWhitelistProvider) returns (bool) {
   118	        // The call must come from the expected consumer, such that _user field cannot be spoofed
   119	        require(msg.sender == consumer, WhitelistProvider__InvalidConsumer());
   120	
   121	        ProofVerificationParams memory params = abi.decode(_auth, (ProofVerificationParams));
   122	
   123	        require(params.serviceConfig.devMode == false, ZKPassportProvider__InvalidProof());
   124	        require(
   125	            keccak256(bytes(params.serviceConfig.domain)) == keccak256(bytes(domain)),
   126	            ZKPassportProvider__InvalidDomain()
   127	        );
   128	        require(
   129	            keccak256(bytes(params.serviceConfig.scope)) == keccak256(bytes(scope)), ZKPassportProvider__InvalidScope()
   130	        );
   131	        require(
   132	            params.serviceConfig.validityPeriodInSeconds == VALIDITY_PERIOD, ZKPassportProvider__InvalidValidityPeriod()
   133	        );
   134	
   135	        (bool verified, bytes32 nullifier, ZKPassportHelper helper) = zkPassportVerifier.verify(params);
   136	
   137	        require(verified, ZKPassportProvider__InvalidProof());
   138	        require(nullifierHashes[nullifier] == false, ZKPassportProvider__SybilDetected(nullifier));
   139	        nullifierHashes[nullifier] = true;
   140	
   141	        // Bind data check
   142	        BoundData memory boundData = helper.getBoundData(params.committedInputs);
   143	        require(boundData.senderAddress == _user, ZKPassportProvider__InvalidBoundAddress());
   144	        require(boundData.chainId == block.chainid, ZKPassportProvider__InvalidBoundChainId());
   145	        require(bytes(boundData.customData).length == 0, ZKPassportProvider__ExtraDiscloseDataNonZero());
   146	
   147	        // Age check
   148	        bool isAgeValid = helper.isAgeAboveOrEqual(MIN_AGE, params.committedInputs);
   149	        require(isAgeValid, ZKPassportProvider__InvalidAge());
   150	
   151	        // Country exclusion check
   152	        string[] memory excludedCountries = new string[](4);
   153	        excludedCountries[0] = CUB;
   154	        excludedCountries[1] = IRN;
   155	        excludedCountries[2] = PKR;
   156	        excludedCountries[3] = UKR;
   157	        bool isCountryValid = helper.isNationalityOut(excludedCountries, params.committedInputs);
   158	        require(isCountryValid, ZKPassportProvider__InvalidCountry());
   159	
   160	        // reverts internally if the sanctions check fails
   161	        helper.enforceSanctionsRoot(block.timestamp, true, params.committedInputs);
   162	
   163	        // Face match check
   164	        bool isFaceMatchValid = helper.isFaceMatchVerified(
   165	            FaceMatchMode.STRICT, OS.ANY, params.committedInputs
   166	        );
   167	        require(isFaceMatchValid, ZKPassportProvider__InvalidFaceMatch());
   168	
   169	        return true;
   170	    }
   171	
   172	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   173	    /*                    Admin Functions                         */
   174	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   175	    /**
   176	     * @dev Do not change this after launch as this could impact nullifiers
   177	     * @param _zkPassportVerifier The address of the zk passport verifier
   178	     */
   179	    function setZKPassportVerifier(address _zkPassportVerifier) external override(IZKPassportProviderLegacy) onlyOwner {
   180	        zkPassportVerifier = ZKPassportRootVerifier(_zkPassportVerifier);
   181	        emit ZKPassportVerifierSet(_zkPassportVerifier);
   182	    }
   183	
   184	    /**
   185	     * @dev Do not change this after launch as it will impact nullifiers
   186	     * @param _domain The domain of the passport
   187	     */
   188	    function setDomain(string memory _domain) external override(IZKPassportProviderLegacy) onlyOwner {
   189	        domain = _domain;
   190	        emit DomainSet(_domain);
   191	    }
   192	
   193	    /**
   194	     * @dev Do not change this after launch as it will impact nullifiers
   195	     * @param _scope The scope of the passport
   196	     */
   197	    function setScope(string memory _scope) external override(IZKPassportProviderLegacy) onlyOwner {
   198	        scope = _scope;
   199	        emit ScopeSet(_scope);
   200	    }
   201	
   202	    /**
   203	     * The consumer
   204	     * @param _consumer The Address of the soulbound contract
   205	     */
   206	    function setConsumer(address _consumer) external override(IWhitelistProvider) onlyOwner {
   207	        consumer = _consumer;
   208	        emit ConsumerSet(_consumer);
   209	    }
   210	}
```

## src/staking-registry/

### src/staking-registry/StakingRegistry.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     5	import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
     6	import {SplitV2Lib} from "@splits/libraries/SplitV2.sol";
     7	import {PullSplitFactory} from "@splits/splitters/pull/PullSplitFactory.sol";
     8	import {Constants} from "src/constants.sol";
     9	import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
    10	import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
    11	import {BN254Lib} from "./libs/BN254.sol";
    12	import {QueueLib, Queue} from "./libs/QueueLib.sol";
    13	
    14	interface IStakingRegistry {
    15	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    16	    /*                        Structs                             */
    17	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    18	    struct ProviderConfiguration {
    19	        /// @notice The address of the provider admin
    20	        address providerAdmin;
    21	        /// @notice The take rate for the provider
    22	        uint16 providerTakeRate;
    23	        /// @notice The address of the provider rewards recipient
    24	        address providerRewardsRecipient;
    25	    }
    26	
    27	    struct KeyStore {
    28	        /// @notice The address of the attester
    29	        address attester;
    30	        /// @notice - The BLS public key - BN254 G1
    31	        BN254Lib.G1Point publicKeyG1;
    32	        /// @notice - The BLS public key - BN254 G2
    33	        BN254Lib.G2Point publicKeyG2;
    34	        /// @notice - The BLS proofOfPossession - required to prevent rogue key attacks
    35	        BN254Lib.G1Point proofOfPossession;
    36	    }
    37	
    38	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    39	    /*                        Events                              */
    40	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    41	    event ProviderRegistered(
    42	        uint256 indexed providerIdentifier, address indexed providerAdmin, uint16 indexed providerTakeRate
    43	    );
    44	    event ProviderAdminUpdateInitiated(uint256 indexed providerIdentifier, address indexed newAdmin);
    45	    event ProviderAdminUpdated(uint256 indexed providerIdentifier, address indexed newAdmin);
    46	    event ProviderTakeRateUpdated(uint256 indexed providerIdentifier, uint16 newTakeRate);
    47	    event ProviderRewardsRecipientUpdated(uint256 indexed providerIdentifier, address indexed newRewardsRecipient);
    48	    event ProviderQueueDripped(uint256 indexed providerIdentifier, address indexed attester);
    49	
    50	    event AttestersAddedToProvider(uint256 indexed providerIdentifier, address[] attesters);
    51	
    52	    event StakedWithProvider(
    53	        uint256 indexed providerIdentifier,
    54	        address indexed rollupAddress,
    55	        address indexed attester,
    56	        address coinbaseSplitContractAddress,
    57	        address stakerImplementation
    58	    );
    59	
    60	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    61	    /*                        Errors                              */
    62	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    63	    error StakingRegistry__ZeroAddress();
    64	    error StakingRegistry__InvalidProviderIdentifier(uint256 _providerIdentifier);
    65	    error StakingRegistry__NotProviderAdmin();
    66	    error StakingRegistry__UpdatedProviderAdminToSameAddress();
    67	    error StakingRegistry__UpdatedProviderTakeRateToSameValue();
    68	    error StakingRegistry__NotPendingProviderAdmin();
    69	    error StakingRegistry__InvalidTakeRate(uint256 _takeRate);
    70	    error StakingRegistry__UnexpectedTakeRate(uint256 _expectedTakeRate, uint256 _gotTakeRate);
    71	
    72	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    73	    /*                        Functions                           */
    74	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    75	    function stake(
    76	        /// The provider identifier to stake with
    77	        uint256 _providerIdentifier,
    78	        /// The rollup version to stake to
    79	        uint256 _rollupVersion,
    80	        /// The withdrawal address for the created validator
    81	        address _withdrawalAddress,
    82	        /// The expected provider take rate
    83	        uint16 _expectedProviderTakeRate,
    84	        /// The address that will receive the rewards
    85	        address _userRewardsRecipient,
    86	        /// Whether to move the validator to the latest rollup
    87	        bool _moveWithLatestRollup
    88	    ) external;
    89	
    90	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    91	    /*                Provider Management Functions               */
    92	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    93	    function registerProvider(address _providerAdmin, uint16 _providerTakeRate, address _providerRewardsRecipient)
    94	        external
    95	        returns (uint256);
    96	    function addKeysToProvider(uint256 _providerIdentifier, KeyStore[] calldata _keyStores) external;
    97	    function updateProviderAdmin(uint256 _providerIdentifier, address _newAdmin) external;
    98	    function acceptProviderAdmin(uint256 _providerIdentifier) external;
    99	    function updateProviderRewardsRecipient(uint256 _providerIdentifier, address _newRewardsRecipient) external;
   100	    function updateProviderTakeRate(uint256 _providerIdentifier, uint16 _newTakeRate) external;
   101	    function dripProviderQueue(uint256 _providerIdentifier, uint256 _numberOfKeysToDrip) external;
   102	
   103	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   104	    /*                 Provider Queue Getters                     */
   105	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   106	    function getProviderQueueLength(uint256 _providerIdentifier) external view returns (uint256);
   107	    function getFirstIndexInQueue(uint256 _providerIdentifier) external view returns (uint128);
   108	    function getLastIndexInQueue(uint256 _providerIdentifier) external view returns (uint128);
   109	    function getValueAtIndexInQueue(uint256 _providerIdentifier, uint128 _index) external view returns (KeyStore memory);
   110	
   111	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   112	    /*                       View Functions                       */
   113	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   114	    function getActivationThreshold(uint256 _rollupVersion) external view returns (uint256);
   115	}
   116	
   117	/**
   118	 * @title Staking Registry
   119	 * @author Aztec-Labs
   120	 * @notice This contract is used to register staking providers and their associated keypairs
   121	 *
   122	 * Description:
   123	 * - The staking registry allows operators to list keypairs that they will run on behalf of other users.
   124	 * - The operators are expected to have all of the keys that they list running on a validator ready to go.
   125	 */
   126	contract StakingRegistry is IStakingRegistry {
   127	    using QueueLib for Queue;
   128	    using SafeERC20 for IERC20;
   129	
   130	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   131	    /*                        Immutables                          */
   132	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   133	    PullSplitFactory public immutable PULL_SPLIT_FACTORY;
   134	    IERC20 public immutable STAKING_ASSET;
   135	
   136	    IRegistry public immutable ROLLUP_REGISTRY;
   137	
   138	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   139	    /*                         Storage                            */
   140	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   141	    mapping(uint256 providerIdentifier => ProviderConfiguration providerConfiguration) public providerConfigurations;
   142	    mapping(uint256 providerIdentifier => Queue attesterKeys) public providerQueues;
   143	
   144	    /// @dev The next provider identifier to use - incremented upon each registration
   145	    uint256 public nextProviderIdentifier = 1;
   146	
   147	    /// @dev The provider admin waiting to accept the provider admin role
   148	    mapping(uint256 providerIdentifier => address providerAdmin) public pendingProviderAdmins;
   149	
   150	    constructor(IERC20 _stakingAsset, address _pullSplitFactory, IRegistry _rollupRegistry) {
   151	        STAKING_ASSET = _stakingAsset;
   152	        PULL_SPLIT_FACTORY = PullSplitFactory(_pullSplitFactory);
   153	        ROLLUP_REGISTRY = _rollupRegistry;
   154	    }
   155	
   156	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   157	    /*                        Functions                           */
   158	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   159	    /**
   160	     * @notice stake with a provider
   161	     *
   162	     * Steps:
   163	     * - Retrieve a keystore from the provider queue.
   164	     * - Deposit into the rollup with the user's withdrawal address.
   165	     * - Create a split contract for the user and the provider that the provider will set as the coinbase for the validator
   166	     *   in order to split the rewards between them at a known take rate.
   167	     *
   168	     * - Note: The user must trust that the provider running their node will set the correct coinbase on their behalf. If you do not trust your
   169	     *         provider to do this, do not stake with them.
   170	     *
   171	     * @param _providerIdentifier - The identifier of the provider to use
   172	     * @param _rollupVersion - The rollup version to stake to
   173	     * @param _withdrawalAddress - The address that will control withdrawing the validator
   174	     * @param _expectedProviderTakeRate - The expected provider take rate
   175	     * @param _userRewardsRecipient - The address that will receive the user's reward split
   176	     * @param _moveWithLatestRollup - Whether to move the validator to the latest rollup
   177	     */
   178	    function stake(
   179	        uint256 _providerIdentifier,
   180	        uint256 _rollupVersion,
   181	        address _withdrawalAddress,
   182	        uint16 _expectedProviderTakeRate,
   183	        address _userRewardsRecipient,
   184	        bool _moveWithLatestRollup
   185	    ) external override(IStakingRegistry) {
   186	        ProviderConfiguration memory providerConfiguration = providerConfigurations[_providerIdentifier];
   187	
   188	        // Or require providerIdentifier < nextProviderIdentifier
   189	        require(
   190	            providerConfiguration.providerAdmin != address(0),
   191	            StakingRegistry__InvalidProviderIdentifier(_providerIdentifier)
   192	        );
   193	
   194	        require(_withdrawalAddress != address(0), StakingRegistry__ZeroAddress());
   195	        require(_userRewardsRecipient != address(0), StakingRegistry__ZeroAddress());
   196	
   197	        // If the provider take rate has changed inbetween the time the transaction was submitted and the time it was executed, we revert
   198	        require(
   199	            _expectedProviderTakeRate == providerConfiguration.providerTakeRate,
   200	            StakingRegistry__UnexpectedTakeRate(_expectedProviderTakeRate, providerConfiguration.providerTakeRate)
   201	        );
   202	
   203	        address rollupAddress = ROLLUP_REGISTRY.getRollup(_rollupVersion);
   204	        require(rollupAddress != address(0), StakingRegistry__ZeroAddress()); // Sanity check - it should never be zero
   205	
   206	        // Revertable conditions
   207	        // - provider has no keys - QueueIsEmpty()
   208	        KeyStore memory keyStore = providerQueues[_providerIdentifier].dequeue();
   209	
   210	        // This can be read from the registry!
   211	        // Ext call - Revertable conditions
   212	        // msg.sender does not have enough funds
   213	        // msg.sender has not approved enough funds
   214	        uint256 activationThreshold = IStaking(rollupAddress).getActivationThreshold();
   215	        STAKING_ASSET.safeTransferFrom(msg.sender, address(this), activationThreshold);
   216	        // Ext call
   217	        STAKING_ASSET.approve(rollupAddress, activationThreshold);
   218	
   219	        // Place the validator into the entry queue
   220	        // Revertable conditions:
   221	        // - attester or withdrawal address is the zero address
   222	        // - attester is currently exiting
   223	        //
   224	        // Async revertable conditions: flushEntryQueue
   225	        // - recoverable: the deposit amount will be returned to the _withdrawalAddress if the deposit fails
   226	        IStaking(rollupAddress)
   227	            .deposit(
   228	                keyStore.attester,
   229	                _withdrawalAddress,
   230	                keyStore.publicKeyG1,
   231	                keyStore.publicKeyG2,
   232	                keyStore.proofOfPossession,
   233	                _moveWithLatestRollup
   234	            );
   235	
   236	        // Create the splitting contract
   237	        // User take rate is BIPS (10_000) - provider take rate
   238	        // Provider take is constrained to be less than BIPS
   239	        SplitV2Lib.Split memory splitInstance;
   240	        {
   241	            uint256 providerTakeRate = providerConfiguration.providerTakeRate;
   242	            uint256 totalAllocation = Constants.BIPS;
   243	            uint256 userTakeRate = totalAllocation - providerTakeRate;
   244	            address providerRewardsRecipient = providerConfiguration.providerRewardsRecipient;
   245	
   246	            // Set the address that will receive the rewards
   247	            address[] memory recipients = new address[](2);
   248	            recipients[0] = providerRewardsRecipient;
   249	            recipients[1] = _userRewardsRecipient;
   250	
   251	            uint256[] memory allocations = new uint256[](2);
   252	            allocations[0] = providerTakeRate;
   253	            allocations[1] = userTakeRate;
   254	
   255	            splitInstance = SplitV2Lib.Split({
   256	                recipients: recipients,
   257	                allocations: allocations,
   258	                totalAllocation: totalAllocation,
   259	                distributionIncentive: 0
   260	            });
   261	        }
   262	
   263	        address split = PULL_SPLIT_FACTORY.createSplit(
   264	            splitInstance,
   265	            address(0), // owner - 0 to make the split immutable
   266	            address(this) // creator - only put in a log - no special permissions
   267	        );
   268	
   269	        emit StakedWithProvider(_providerIdentifier, rollupAddress, keyStore.attester, split, msg.sender);
   270	    }
   271	
   272	    /**
   273	     * @notice Register a new staking provider
   274	     *
   275	     * @param _providerAdmin The address of the provider admin
   276	     * @param _providerTakeRate The take rate for the provider
   277	     * @param _providerRewardsRecipient The address that will receive the provider's rewards
   278	     *
   279	     * @dev Provider identifier's are auto-incremented and assigned to the provider
   280	     */
   281	    function registerProvider(address _providerAdmin, uint16 _providerTakeRate, address _providerRewardsRecipient)
   282	        external
   283	        override(IStakingRegistry)
   284	        returns (uint256)
   285	    {
   286	        require(_providerAdmin != address(0), StakingRegistry__ZeroAddress());
   287	        require(_providerRewardsRecipient != address(0), StakingRegistry__ZeroAddress());
   288	        require(_providerTakeRate <= Constants.BIPS, StakingRegistry__InvalidTakeRate(_providerTakeRate));
   289	
   290	        // Assign and increment the provider identifier
   291	        uint256 providerIdentifier = nextProviderIdentifier;
   292	        nextProviderIdentifier++;
   293	
   294	        ProviderConfiguration memory providerConfiguration = ProviderConfiguration({
   295	            providerAdmin: _providerAdmin,
   296	            providerTakeRate: _providerTakeRate,
   297	            providerRewardsRecipient: _providerRewardsRecipient
   298	        });
   299	
   300	        // Set the provider admin, queue, and take rate
   301	        providerConfigurations[providerIdentifier] = providerConfiguration;
   302	        providerQueues[providerIdentifier].init();
   303	
   304	        emit ProviderRegistered(providerIdentifier, _providerAdmin, _providerTakeRate);
   305	
   306	        return providerIdentifier;
   307	    }
   308	
   309	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   310	    /*           Provider Queue Management Functions              */
   311	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   312	    /**
   313	     * @notice Add a set of keys to a provider
   314	     *
   315	     * @param _providerIdentifier The identifier of the provider
   316	     * @param _keyStores The key stores to add
   317	     */
   318	    function addKeysToProvider(uint256 _providerIdentifier, KeyStore[] calldata _keyStores)
   319	        external
   320	        override(IStakingRegistry)
   321	    {
   322	        ProviderConfiguration memory providerConfiguration = providerConfigurations[_providerIdentifier];
   323	
   324	        require(msg.sender == providerConfiguration.providerAdmin, StakingRegistry__NotProviderAdmin());
   325	
   326	        Queue storage providerQueue = providerQueues[_providerIdentifier];
   327	        address[] memory attesters = new address[](_keyStores.length); // just for logging
   328	        for (uint256 i; i < _keyStores.length; ++i) {
   329	            providerQueue.enqueue(_keyStores[i]);
   330	            attesters[i] = _keyStores[i].attester;
   331	        }
   332	
   333	        emit AttestersAddedToProvider(_providerIdentifier, attesters);
   334	    }
   335	
   336	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   337	    /*                 Provider Admin Functions                   */
   338	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   339	    /**
   340	     * @notice Update the admin of a provider
   341	     *
   342	     * @param _providerIdentifier The identifier of the provider
   343	     * @param _newAdmin The new admin address
   344	     */
   345	    function updateProviderAdmin(uint256 _providerIdentifier, address _newAdmin) external override(IStakingRegistry) {
   346	        address currentProviderAdmin = providerConfigurations[_providerIdentifier].providerAdmin;
   347	        require(msg.sender == currentProviderAdmin, StakingRegistry__NotProviderAdmin());
   348	        require(_newAdmin != address(0), StakingRegistry__ZeroAddress());
   349	        require(_newAdmin != currentProviderAdmin, StakingRegistry__UpdatedProviderAdminToSameAddress());
   350	
   351	        pendingProviderAdmins[_providerIdentifier] = _newAdmin;
   352	        emit ProviderAdminUpdateInitiated(_providerIdentifier, _newAdmin);
   353	    }
   354	
   355	    /**
   356	     * @notice Accept the provider admin role
   357	     *
   358	     * @param _providerIdentifier The identifier of the provider
   359	     *
   360	     * @dev The provider admin transfer can be initiated in `updateProviderAdmin` and accepted here.
   361	     */
   362	    function acceptProviderAdmin(uint256 _providerIdentifier) external override(IStakingRegistry) {
   363	        require(msg.sender == pendingProviderAdmins[_providerIdentifier], StakingRegistry__NotPendingProviderAdmin());
   364	        providerConfigurations[_providerIdentifier].providerAdmin = msg.sender;
   365	        delete pendingProviderAdmins[_providerIdentifier];
   366	        emit ProviderAdminUpdated(_providerIdentifier, msg.sender);
   367	    }
   368	
   369	    /**
   370	     * @notice Update the rewards recipient of a provider
   371	     *
   372	     * @param _providerIdentifier The identifier of the provider
   373	     * @param _newRewardsRecipient The new rewards recipient address
   374	     *
   375	     * @dev The rewards recipient will be included in 0xSplits contract's deployed for the provider
   376	     */
   377	    function updateProviderRewardsRecipient(uint256 _providerIdentifier, address _newRewardsRecipient)
   378	        external
   379	        override(IStakingRegistry)
   380	    {
   381	        require(
   382	            msg.sender == providerConfigurations[_providerIdentifier].providerAdmin, StakingRegistry__NotProviderAdmin()
   383	        );
   384	
   385	        require(_newRewardsRecipient != address(0), StakingRegistry__ZeroAddress());
   386	
   387	        providerConfigurations[_providerIdentifier].providerRewardsRecipient = _newRewardsRecipient;
   388	        emit ProviderRewardsRecipientUpdated(_providerIdentifier, _newRewardsRecipient);
   389	    }
   390	
   391	    /**
   392	     * @notice Update the take rate of a provider
   393	     *
   394	     * @param _providerIdentifier The identifier of the provider
   395	     * @param _newTakeRate The new take rate
   396	     *
   397	     * @dev The take rate is a BIPS of the rewards that the provider will receive
   398	     */
   399	    function updateProviderTakeRate(uint256 _providerIdentifier, uint16 _newTakeRate)
   400	        external
   401	        override(IStakingRegistry)
   402	    {
   403	        require(
   404	            msg.sender == providerConfigurations[_providerIdentifier].providerAdmin, StakingRegistry__NotProviderAdmin()
   405	        );
   406	        require(
   407	            _newTakeRate != providerConfigurations[_providerIdentifier].providerTakeRate,
   408	            StakingRegistry__UpdatedProviderTakeRateToSameValue()
   409	        );
   410	        require(_newTakeRate <= Constants.BIPS, StakingRegistry__InvalidTakeRate(_newTakeRate));
   411	
   412	        providerConfigurations[_providerIdentifier].providerTakeRate = _newTakeRate;
   413	        emit ProviderTakeRateUpdated(_providerIdentifier, _newTakeRate);
   414	    }
   415	
   416	    /**
   417	     * @notice Drip the provider queue
   418	     * If the queue gets into a bad state - e.g a provider deposits a key that is already in the rollup, or a provider deposits bad BLS keys
   419	     * The queue can be dripped to remove the bad key.
   420	     *
   421	     * @param _providerIdentifier The identifier of the provider
   422	     * @param _numberOfKeysToDrip The number of keys to drip
   423	     */
   424	    function dripProviderQueue(uint256 _providerIdentifier, uint256 _numberOfKeysToDrip)
   425	        external
   426	        override(IStakingRegistry)
   427	    {
   428	        ProviderConfiguration memory providerConfiguration = providerConfigurations[_providerIdentifier];
   429	        require(msg.sender == providerConfiguration.providerAdmin, StakingRegistry__NotProviderAdmin());
   430	
   431	        Queue storage providerQueue = providerQueues[_providerIdentifier];
   432	        for (uint256 i; i < _numberOfKeysToDrip; ++i) {
   433	            KeyStore memory keyStore = providerQueue.dequeue();
   434	            emit ProviderQueueDripped(_providerIdentifier, keyStore.attester);
   435	        }
   436	    }
   437	
   438	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   439	    /*                 Provider Queue Getters                     */
   440	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   441	    /**
   442	     * @notice Get the length of the provider queue
   443	     *
   444	     * @param _providerIdentifier The identifier of the provider
   445	     * @return The length of the provider queue
   446	     */
   447	    function getProviderQueueLength(uint256 _providerIdentifier)
   448	        external
   449	        view
   450	        override(IStakingRegistry)
   451	        returns (uint256)
   452	    {
   453	        return providerQueues[_providerIdentifier].length();
   454	    }
   455	
   456	    /**
   457	     * @notice Get the first index in the provider queue
   458	     *
   459	     * @param _providerIdentifier The identifier of the provider
   460	     * @return The first index in the provider queue
   461	     */
   462	    function getFirstIndexInQueue(uint256 _providerIdentifier)
   463	        external
   464	        view
   465	        override(IStakingRegistry)
   466	        returns (uint128)
   467	    {
   468	        return providerQueues[_providerIdentifier].getFirstIndex();
   469	    }
   470	
   471	    /**
   472	     * @notice Get the last index in the provider queue
   473	     *
   474	     * @param _providerIdentifier The identifier of the provider
   475	     * @return The last index in the provider queue
   476	     */
   477	    function getLastIndexInQueue(uint256 _providerIdentifier)
   478	        external
   479	        view
   480	        override(IStakingRegistry)
   481	        returns (uint128)
   482	    {
   483	        return providerQueues[_providerIdentifier].getLastIndex();
   484	    }
   485	
   486	    /**
   487	     * @notice Get the key store at a given index in the provider queue
   488	     *
   489	     * @param _providerIdentifier The identifier of the provider
   490	     * @param _index The index in the provider queue
   491	     * @return The key store at the given index
   492	     */
   493	    function getValueAtIndexInQueue(uint256 _providerIdentifier, uint128 _index)
   494	        external
   495	        view
   496	        override(IStakingRegistry)
   497	        returns (KeyStore memory)
   498	    {
   499	        return providerQueues[_providerIdentifier].getValueAtIndex(_index);
   500	    }
   501	
   502	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   503	    /*                       View Functions                       */
   504	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   505	
   506	    /**
   507	     * @notice View function to retrieve the activation threshold for a given rollup version
   508	     * @param _rollupVersion The version of the rollup to get the activation threshold for
   509	     * @return The activation threshold
   510	     */
   511	    function getActivationThreshold(uint256 _rollupVersion) external view override(IStakingRegistry) returns (uint256) {
   512	        address rollupAddress = ROLLUP_REGISTRY.getRollup(_rollupVersion);
   513	        return IStaking(rollupAddress).getActivationThreshold();
   514	    }
   515	}
```

## src/staking-registry/libs/

### src/staking-registry/libs/BN254.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	library BN254Lib {
     5	    /**
     6	     * @title G1Point
     7	     * @notice A point on the BN254 G1 curve
     8	     */
     9	    struct G1Point {
    10	        /// @notice The x coordinate
    11	        uint256 x;
    12	        /// @notice The y coordinate
    13	        uint256 y;
    14	    }
    15	
    16	    /**
    17	     * @title G2Point
    18	     * @notice A point on the BN254 paired G2 curve
    19	     */
    20	    struct G2Point {
    21	        /// @notice The x coordinate - first part
    22	        uint256 x0;
    23	        /// @notice The x coordinate - second part
    24	        uint256 x1;
    25	        /// @notice The y coordinate - first part
    26	        uint256 y0;
    27	        /// @notice The y coordinate - second part
    28	        uint256 y1;
    29	    }
    30	
    31	    struct KeyStore {
    32	        /// @notice The address of the attester
    33	        address attester;
    34	        /// @notice - The BLS public key - BN254 G1
    35	        G1Point publicKeyG1;
    36	        /// @notice - The BLS public key - BN254 G2
    37	        G2Point publicKeyG2;
    38	        /// @notice - The BLS signature - required to prevent rogue key attacks
    39	        G1Point signature;
    40	    }
    41	}
```

### src/staking-registry/libs/QueueLib.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
     5	
     6	struct Queue {
     7	    mapping(uint256 index => IStakingRegistry.KeyStore keyStore) keyStores;
     8	    uint128 first;
     9	    uint128 last;
    10	}
    11	
    12	library QueueLib {
    13	    error QueueIsEmpty();
    14	    error QueueIndexOutOfBounds();
    15	
    16	    function init(Queue storage _self) internal {
    17	        _self.first = 1;
    18	        _self.last = 1;
    19	    }
    20	
    21	    function enqueue(Queue storage _self, IStakingRegistry.KeyStore memory _keyStore) internal returns (uint128) {
    22	        uint128 queueLocation = _self.last;
    23	
    24	        _self.keyStores[queueLocation] = _keyStore;
    25	        _self.last = queueLocation + 1;
    26	
    27	        return queueLocation;
    28	    }
    29	
    30	    function dequeue(Queue storage _self) internal returns (IStakingRegistry.KeyStore memory) {
    31	        require(_self.last > _self.first, QueueIsEmpty());
    32	
    33	        IStakingRegistry.KeyStore memory keyStore = _self.keyStores[_self.first];
    34	        _self.first += 1;
    35	
    36	        return keyStore;
    37	    }
    38	
    39	    function getValueAtIndex(Queue storage _self, uint128 _index)
    40	        internal
    41	        view
    42	        returns (IStakingRegistry.KeyStore memory)
    43	    {
    44	        require(_index >= _self.first && _index < _self.last, QueueIndexOutOfBounds());
    45	        return _self.keyStores[_index];
    46	    }
    47	
    48	    function length(Queue storage _self) internal view returns (uint128) {
    49	        return _self.last - _self.first;
    50	    }
    51	
    52	    function getFirstIndex(Queue storage _self) internal view returns (uint128) {
    53	        return _self.first;
    54	    }
    55	
    56	    function getLastIndex(Queue storage _self) internal view returns (uint128) {
    57	        return _self.last;
    58	    }
    59	}
```

## src/staking/

### src/staking/ATPNonWithdrawableStaker.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {BaseStaker} from "@atp/staker/BaseStaker.sol";
     5	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     6	import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
     7	import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
     8	import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
     9	import {IATPNonWithdrawableStaker, IGovernanceATP} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
    10	import {IGovernance, IPayload} from "src/staking/rollup-system-interfaces/IGovernance.sol";
    11	import {IGSE} from "src/staking/rollup-system-interfaces/IGSE.sol";
    12	import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
    13	import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
    14	
    15	/**
    16	 * @title ATP Staker
    17	 * @author Aztec-Labs
    18	 * @notice Stake from an ATP to earn rewards
    19	 *
    20	 * @notice NonWithdrawableStaker does not implement the withdrawal functionality, this will be enabled in an upgrade to the staker contract
    21	 *         At the time of ignition, Aligned Stakers are expected to stake until their position is withdrawable.
    22	 */
    23	
    24	contract ATPNonWithdrawableStaker is IATPNonWithdrawableStaker, BaseStaker {
    25	    using SafeERC20 for IERC20;
    26	
    27	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    28	    /*                        Events                              */
    29	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    30	    event Staked(address indexed staker, address indexed attester, address indexed rollupAddress);
    31	
    32	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    33	    /*                      Immutables                            */
    34	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    35	    IERC20 public immutable STAKING_ASSET;
    36	    IRegistry public immutable ROLLUP_REGISTRY;
    37	    IStakingRegistry public immutable STAKING_REGISTRY;
    38	
    39	    constructor(IERC20 _stakingAsset, IRegistry _rollupRegistry, IStakingRegistry _stakingRegistry) {
    40	        STAKING_ASSET = _stakingAsset;
    41	        ROLLUP_REGISTRY = _rollupRegistry;
    42	        STAKING_REGISTRY = _stakingRegistry;
    43	    }
    44	
    45	    /**
    46	     * @notice Stake the staking asset to the rollup
    47	     *
    48	     * Withdrawer is set to this contract address
    49	     *
    50	     * @param _version The version of the rollup to deposit to
    51	     * @param _attester The address of the attester on the rollup
    52	     * @param _publicKeyG1 The public key of the attester - BN254Lib.G1Point
    53	     * @param _publicKeyG2 The public key of the attester - BN254Lib.G2Point
    54	     * @param _signature The signature of the attester - BN254Lib.G1Point
    55	     * @param _moveWithLatestRollup Whether to move the funds to the latest rollup version if the rollup has been upgraded
    56	     *
    57	     * @dev If _moveWithLatestRollup is true, then the rollup version MUST be the latest version
    58	     * @dev Requires atp.approveStaker() has been called before
    59	     */
    60	    function stake(
    61	        uint256 _version,
    62	        address _attester,
    63	        BN254Lib.G1Point memory _publicKeyG1,
    64	        BN254Lib.G2Point memory _publicKeyG2,
    65	        BN254Lib.G1Point memory _signature,
    66	        bool _moveWithLatestRollup
    67	    ) external virtual override(IATPNonWithdrawableStaker) onlyOperator {
    68	        _stake(_version, _attester, _publicKeyG1, _publicKeyG2, _signature, _moveWithLatestRollup);
    69	    }
    70	
    71	    /**
    72	     * @notice Stake with a provider
    73	     *
    74	     * A provider is an external operator that has registered themselves with the staking provider registry
    75	     * When using the staking registry
    76	     * - providers register themselves with a given take rate for their services
    77	     * - the attester field, is requested from a list of keys that the provider has listed
    78	     * - the stake function on the registry performs staking, creating a fee splitting contract for rewards to go into
    79	     *
    80	     * @param _version The version of the rollup to deposit to
    81	     * @param _providerIdentifier The identifier of the provider to stake with
    82	     * @param _expectedProviderTakeRate The expected provider take rate
    83	     * @param _userRewardsRecipient The address that will receive the user's reward split
    84	     * @param _moveWithLatestRollup Whether to move the funds to the latest rollup version if the rollup has been upgraded
    85	     *
    86	     * @dev Requires atp.approveStaker() has been called before
    87	     */
    88	    function stakeWithProvider(
    89	        uint256 _version,
    90	        uint256 _providerIdentifier,
    91	        uint16 _expectedProviderTakeRate,
    92	        address _userRewardsRecipient,
    93	        bool _moveWithLatestRollup
    94	    ) external virtual override(IATPNonWithdrawableStaker) onlyOperator {
    95	        _stakeWithProvider(
    96	            _version, _providerIdentifier, _expectedProviderTakeRate, _userRewardsRecipient, _moveWithLatestRollup
    97	        );
    98	    }
    99	
   100	    /**
   101	     * @notice If and only if the atp is set as the coinbase for the active validator, then rewards will need to be claimed
   102	     * from the rollup
   103	     *
   104	     * @param _version The version of the rollup to claim rewards from
   105	     */
   106	    function claimRewards(uint256 _version) external override(IATPNonWithdrawableStaker) onlyOperator {
   107	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
   108	        address atp = getATP();
   109	
   110	        IStaking(rollup).claimSequencerRewards(atp);
   111	    }
   112	
   113	    /**
   114	     * @notice delegate voting power to a delegatee
   115	     * @notice By default voting power is delegated to the rollup itself, with validators determining
   116	     * what proposals will get voted on. This means most users will not need to delegate their vote if they
   117	     * are staking.
   118	     *
   119	     * @dev this function only requires to delegating staked tokens
   120	     *      use depositIntoGovernance to vote with unstaked tokens
   121	     *
   122	     * @param _version The version of the rollup to delegate to
   123	     * @param _attester The address of the attester the voting power is associated with on the rollup
   124	     * @param _delegatee The address of the delegatee
   125	     */
   126	    function delegate(uint256 _version, address _attester, address _delegatee)
   127	        external
   128	        virtual
   129	        override(IATPNonWithdrawableStaker)
   130	        onlyOperator
   131	    {
   132	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
   133	        address gse = IStaking(rollup).getGSE();
   134	
   135	        IGSE(gse).delegate(rollup, _attester, _delegatee);
   136	    }
   137	
   138	    /**
   139	     * @notice Deposit tokens into governance for voting
   140	     * @notice This staker contract becomes the beneficiary and holder of voting power
   141	     *         voting must take place through the voteInGovernance function
   142	     *
   143	     * @dev Governance contract is derived from the rollup registry
   144	     *
   145	     * @param _amount The amount of tokens to deposit into governance
   146	     */
   147	    function depositIntoGovernance(uint256 _amount) external override(IGovernanceATP) onlyOperator {
   148	        address governance = ROLLUP_REGISTRY.getGovernance();
   149	
   150	        STAKING_ASSET.safeTransferFrom(address(atp), address(this), _amount);
   151	        STAKING_ASSET.approve(address(governance), _amount);
   152	        IGovernance(governance).deposit(address(this), _amount);
   153	    }
   154	
   155	    /**
   156	     * @notice Vote in governance
   157	     * @notice Voting power is held by this staker contract
   158	     *         Users must first deposit into Governance via depositIntoGovernance first
   159	     *
   160	     * @dev Governance contract is derived from the rollup registry
   161	     *
   162	     * @param _proposalId The ID of the proposal to vote on
   163	     * @param _amount The amount of tokens to vote with
   164	     * @param _support The support for the proposal
   165	     */
   166	    function voteInGovernance(uint256 _proposalId, uint256 _amount, bool _support)
   167	        external
   168	        override(IGovernanceATP)
   169	        onlyOperator
   170	    {
   171	        address governance = ROLLUP_REGISTRY.getGovernance();
   172	        IGovernance(governance).vote(_proposalId, _amount, _support);
   173	    }
   174	
   175	    /**
   176	     * @notice Initiate a withdrawal from governance
   177	     * @notice This function will initiate a withdrawal from governance
   178	     *         Users must first deposit into Governance via depositIntoGovernance first
   179	     *
   180	     * @dev Governance contract is derived from the rollup registry
   181	     *
   182	     * @param _amount The amount of tokens to withdraw from governance
   183	     * @return The withdrawal ID - this must be used when calling finalizeWithdraw on the Governance contract
   184	     */
   185	    function initiateWithdrawFromGovernance(uint256 _amount)
   186	        external
   187	        override(IGovernanceATP)
   188	        onlyOperator
   189	        returns (uint256)
   190	    {
   191	        address governance = ROLLUP_REGISTRY.getGovernance();
   192	        address atp = getATP();
   193	
   194	        return IGovernance(governance).initiateWithdraw(atp, _amount);
   195	    }
   196	
   197	    /**
   198	     * @notice Propose With Lock
   199	     * @notice This function will make a proposal into Governance but funds will be locked for an
   200	     *         extended period of time - see the Gov implementation for more details
   201	     *
   202	     * @param _proposal The proposal to propose
   203	     * @return The proposal ID
   204	     */
   205	    function proposeWithLock(IPayload _proposal) external override(IGovernanceATP) onlyOperator returns (uint256) {
   206	        address governance = ROLLUP_REGISTRY.getGovernance();
   207	        address atp = getATP();
   208	
   209	        return IGovernance(governance).proposeWithLock(_proposal, atp);
   210	    }
   211	
   212	    /**
   213	     * @notice Move the funds back to the ATP
   214	     *
   215	     * Case in which this is required:
   216	     * - When calling deposit with _moveWithLatestRollup set to true, the staker will enter the deposit queue
   217	     * - If user gets to the front of the queue, but the rollup has been upgraded, _moveWithLatestRollup will be invalid
   218	     * - This will return the funds to the withdrawer (this address)
   219	     * - This leaves the user to perform the following steps:
   220	     *   - return the funds back to the atp
   221	     *   - then call stake again on the updated rollup version
   222	     *
   223	     * @dev This function is only callable by the operator
   224	     * @dev This function will move the funds back to the ATP ONLY
   225	     */
   226	    function moveFundsBackToATP() external override(IATPNonWithdrawableStaker) onlyOperator {
   227	        address atp = getATP();
   228	        uint256 balance = STAKING_ASSET.balanceOf(address(this));
   229	
   230	        STAKING_ASSET.safeTransfer(atp, balance);
   231	    }
   232	
   233	    function _stake(
   234	        uint256 _version,
   235	        address _attester,
   236	        BN254Lib.G1Point memory _publicKeyG1,
   237	        BN254Lib.G2Point memory _publicKeyG2,
   238	        BN254Lib.G1Point memory _signature,
   239	        bool _moveWithLatestRollup
   240	    ) internal virtual onlyOperator {
   241	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
   242	        uint256 activationThreshold = IStaking(rollup).getActivationThreshold();
   243	
   244	        STAKING_ASSET.safeTransferFrom(address(atp), address(this), activationThreshold);
   245	        STAKING_ASSET.approve(rollup, activationThreshold);
   246	        IStaking(rollup)
   247	            .deposit(_attester, address(this), _publicKeyG1, _publicKeyG2, _signature, _moveWithLatestRollup);
   248	
   249	        emit Staked(address(this), _attester, rollup);
   250	    }
   251	
   252	    function _stakeWithProvider(
   253	        uint256 _version,
   254	        uint256 _providerIdentifier,
   255	        uint16 _expectedProviderTakeRate,
   256	        address _userRewardsRecipient,
   257	        bool _moveWithLatestRollup
   258	    ) internal virtual onlyOperator {
   259	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
   260	        uint256 activationThreshold = IStaking(rollup).getActivationThreshold();
   261	
   262	        STAKING_ASSET.safeTransferFrom(address(atp), address(this), activationThreshold);
   263	        STAKING_ASSET.approve(address(STAKING_REGISTRY), activationThreshold);
   264	        STAKING_REGISTRY.stake(
   265	            _providerIdentifier,
   266	            _version,
   267	            address(this),
   268	            _expectedProviderTakeRate,
   269	            _userRewardsRecipient,
   270	            _moveWithLatestRollup
   271	        );
   272	    }
   273	}
```

### src/staking/ATPWithdrawableAndClaimableStaker.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IATPCore} from "@atp/atps/base/IATP.sol";
     5	import {NCATP} from "@atp/atps/noclaim/NCATP.sol";
     6	import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
     7	import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
     8	import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
     9	import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
    10	import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
    11	import {ATPWithdrawableStaker} from "src/staking/ATPWithdrawableStaker.sol";
    12	import {IATPNonWithdrawableStaker} from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
    13	import {IATPWithdrawableAndClaimableStaker} from "src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol";
    14	import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
    15	
    16	/**
    17	 * @title ATP Withdrawable And Claimable Staker
    18	 * @author Aztec-Labs
    19	 * @notice An implementation of an ATP Staker that allows for withdrawals from the rollup
    20	 *         and enables NCATP token holders to claim tokens only after staking has occured.
    21	 */
    22	contract ATPWithdrawableAndClaimableStaker is IATPWithdrawableAndClaimableStaker, ATPWithdrawableStaker {
    23	    using SafeERC20 for IERC20;
    24	
    25	    /**
    26	     * @dev Storage of the ATPWithdrawableAndClaimableStaker contract.
    27	     *
    28	     * @custom:storage-location erc7201:aztec.storage.ATPWithdrawableAndClaimableStaker
    29	     */
    30	    struct ATPWithdrawableAndClaimableStakerStorage {
    31	        /**
    32	         * @notice Flag indicating whether staking has occured
    33	         */
    34	        bool hasStaked;
    35	    }
    36	
    37	    // keccak256(abi.encode(uint256(keccak256("aztec.storage.ATPWithdrawableAndClaimableStaker")) - 1)) & ~bytes32(uint256(0xff))
    38	    bytes32 private constant _ATP_WITHDRAWABLE_AND_CLAIMABLE_STAKER_STORAGE =
    39	        0x2527cfd5830db0c841b72084c1ec066be32b8320e2ee2b8cb438bb32af8d8500;
    40	
    41	    /**
    42	     * @notice The timestamp at which withdrawals are enabled.
    43	     */
    44	    uint256 public immutable WITHDRAWAL_TIMESTAMP;
    45	
    46	    /**
    47	     * @notice Emitted when tokens are withdrawn by NCATP holders
    48	     * @param recipient The address receiving the tokens
    49	     * @param amount The amount of tokens withdrawn
    50	     */
    51	    event TokensWithdrawn(address indexed recipient, uint256 amount);
    52	
    53	    /**
    54	     * @notice Emitted when withdrawable status changes
    55	     */
    56	    event WithdrawableStatusChanged();
    57	
    58	    /**
    59	     * @notice Emitted when tokens are withdrawn to the beneficiary
    60	     * @param beneficiary The address of the ATP beneficiary
    61	     * @param amount The amount of tokens withdrawn
    62	     */
    63	    event TokensWithdrawnToBeneficiary(address indexed beneficiary, uint256 amount);
    64	
    65	    /**
    66	     * @notice Error thrown when attempting to withdraw before staking has occurred
    67	     */
    68	    error StakingNotOccurred();
    69	
    70	    /**
    71	     * @notice Error thrown when attempting to withdraw before the withdrawal delay has passed
    72	     */
    73	    error WithdrawalDelayNotPassed();
    74	
    75	    constructor(
    76	        IERC20 _stakingAsset,
    77	        IRegistry _rollupRegistry,
    78	        IStakingRegistry _stakingRegistry,
    79	        uint256 _withdrawalTimestamp
    80	    ) ATPWithdrawableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry) {
    81	        WITHDRAWAL_TIMESTAMP = _withdrawalTimestamp;
    82	    }
    83	
    84	    /**
    85	     * @notice Stake the staking asset to the rollup
    86	     * @dev Overrides the parent stake function to set withdrawable to true after successful staking
    87	     *
    88	     * @param _version The version of the rollup to deposit to
    89	     * @param _attester The address of the attester on the rollup
    90	     * @param _publicKeyG1 The public key of the attester - BN254Lib.G1Point
    91	     * @param _publicKeyG2 The public key of the attester - BN254Lib.G2Point
    92	     * @param _signature The signature of the attester - BN254Lib.G1Point
    93	     * @param _moveWithLatestRollup Whether to move the funds to the latest rollup version if the rollup has been upgraded
    94	     *
    95	     * @dev If _moveWithLatestRollup is true, then the rollup version MUST be the latest version
    96	     * @dev Requires atp.approveStaker() has been called before
    97	     */
    98	    function stake(
    99	        uint256 _version,
   100	        address _attester,
   101	        BN254Lib.G1Point memory _publicKeyG1,
   102	        BN254Lib.G2Point memory _publicKeyG2,
   103	        BN254Lib.G1Point memory _signature,
   104	        bool _moveWithLatestRollup
   105	    ) external override(ATPNonWithdrawableStaker, IATPNonWithdrawableStaker) onlyOperator {
   106	        // Call parent stake function
   107	        _stake(_version, _attester, _publicKeyG1, _publicKeyG2, _signature, _moveWithLatestRollup);
   108	
   109	        ATPWithdrawableAndClaimableStakerStorage storage $ = _getATPWithdrawableAndClaimableStakerStorage();
   110	        if (!$.hasStaked) {
   111	            $.hasStaked = true;
   112	            emit WithdrawableStatusChanged();
   113	        }
   114	    }
   115	
   116	    /**
   117	     * @notice Stake with a provider
   118	     * @dev Overrides the parent stakeWithProvider function to set withdrawable to true after successful delegation
   119	     *
   120	     * @param _version The version of the rollup to deposit to
   121	     * @param _providerIdentifier The identifier of the provider to stake wit
   122	     * @param _expectedProviderTakeRate The expected provider take rate
   123	     * @param _userRewardsRecipient The address that will receive the user's reward split
   124	     * @param _moveWithLatestRollup Whether to move the funds to the latest rollup version if the rollup has been upgraded
   125	     */
   126	    function stakeWithProvider(
   127	        uint256 _version,
   128	        uint256 _providerIdentifier,
   129	        uint16 _expectedProviderTakeRate,
   130	        address _userRewardsRecipient,
   131	        bool _moveWithLatestRollup
   132	    ) external override(ATPNonWithdrawableStaker, IATPNonWithdrawableStaker) onlyOperator {
   133	        // Call parent stakeWithProvider function
   134	        _stakeWithProvider(
   135	            _version, _providerIdentifier, _expectedProviderTakeRate, _userRewardsRecipient, _moveWithLatestRollup
   136	        );
   137	
   138	        // Set withdrawable to true after successful staking
   139	        ATPWithdrawableAndClaimableStakerStorage storage $ = _getATPWithdrawableAndClaimableStakerStorage();
   140	        if (!$.hasStaked) {
   141	            $.hasStaked = true;
   142	            emit WithdrawableStatusChanged();
   143	        }
   144	    }
   145	
   146	    /**
   147	     * @notice Withdraw all available tokens to the beneficiary
   148	     * @dev Only callable if staking has occurred (withdrawable == true)
   149	     */
   150	    function withdrawAllTokensToBeneficiary() external override(IATPWithdrawableAndClaimableStaker) onlyOperator {
   151	        address atp = getATP();
   152	
   153	        require(hasStaked(), StakingNotOccurred());
   154	        require(block.timestamp >= WITHDRAWAL_TIMESTAMP, WithdrawalDelayNotPassed());
   155	
   156	        uint256 atpBalance = STAKING_ASSET.balanceOf(atp);
   157	
   158	        address beneficiary = IATPCore(atp).getBeneficiary();
   159	
   160	        if (atpBalance > 0) {
   161	            STAKING_ASSET.safeTransferFrom(atp, beneficiary, atpBalance);
   162	            emit TokensWithdrawnToBeneficiary(beneficiary, atpBalance);
   163	        }
   164	    }
   165	
   166	    /**
   167	     * @notice Returns the hasStaked flag
   168	     * @return bool indicating whether staking has occurred
   169	     */
   170	    function hasStaked() public view override(IATPWithdrawableAndClaimableStaker) returns (bool) {
   171	        ATPWithdrawableAndClaimableStakerStorage storage $ = _getATPWithdrawableAndClaimableStakerStorage();
   172	        return $.hasStaked;
   173	    }
   174	
   175	    /**
   176	     * @dev Returns a pointer to the storage namespace.
   177	     */
   178	    function _getATPWithdrawableAndClaimableStakerStorage()
   179	        private
   180	        pure
   181	        returns (ATPWithdrawableAndClaimableStakerStorage storage $)
   182	    {
   183	        assembly {
   184	            $.slot := _ATP_WITHDRAWABLE_AND_CLAIMABLE_STAKER_STORAGE
   185	        }
   186	    }
   187	}
```

### src/staking/ATPWithdrawableStaker.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     5	import {IStakingRegistry} from "src/staking-registry/StakingRegistry.sol";
     6	import {ATPNonWithdrawableStaker} from "src/staking/ATPNonWithdrawableStaker.sol";
     7	import {IATPWithdrawableStaker} from "src/staking/interfaces/IATPWithdrawableStaker.sol";
     8	import {IRegistry} from "src/staking/rollup-system-interfaces/IRegistry.sol";
     9	import {IStaking} from "src/staking/rollup-system-interfaces/IStaking.sol";
    10	
    11	/**
    12	 * @title ATP Withdrawable Staker
    13	 * @author Aztec-Labs
    14	 * @notice An implementation of an ATP staker that allows for withdrawals from the rollup
    15	 */
    16	contract ATPWithdrawableStaker is IATPWithdrawableStaker, ATPNonWithdrawableStaker {
    17	    constructor(IERC20 _stakingAsset, IRegistry _rollupRegistry, IStakingRegistry _stakingRegistry)
    18	        ATPNonWithdrawableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry)
    19	    {}
    20	
    21	    /**
    22	     * @notice Initiate a withdrawal from the rollup
    23	     *
    24	     * @param _version - the version of the rollup the _attester is active on
    25	     * @param _attester - the address of the attester on the rollup
    26	     *
    27	     * @dev Initiating a withdrawal will return funds to the _recipient address, which is set the ATP address
    28	     */
    29	    function initiateWithdraw(uint256 _version, address _attester)
    30	        external
    31	        override(IATPWithdrawableStaker)
    32	        onlyOperator
    33	    {
    34	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
    35	        address atp = getATP();
    36	
    37	        IStaking(rollup).initiateWithdraw(_attester, atp);
    38	    }
    39	
    40	    /**
    41	     * @notice Finalize a withdrawal from the rollup
    42	     * - Note on the rollup contract, anyone can call this - it just exists for completeness
    43	     *
    44	     * @param _version The version of the rollup the _attester is active on
    45	     * @param _attester The address of the attester on the rollup
    46	     *
    47	     * @dev This function can be called by anyone on the rollup, and is not necessarily required to be called via the staker
    48	     */
    49	    function finalizeWithdraw(uint256 _version, address _attester) external virtual override(IATPWithdrawableStaker) {
    50	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
    51	        IStaking(rollup).finaliseWithdraw(_attester);
    52	    }
    53	}
```

## src/staking/interfaces/

### src/staking/interfaces/IATPNonWithdrawableStaker.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
     5	import {IGovernanceATP} from "./IGovernanceATP.sol";
     6	
     7	interface IATPNonWithdrawableStaker is IGovernanceATP {
     8	    function stake(
     9	        uint256 _version,
    10	        address _attester,
    11	        BN254Lib.G1Point memory _publicKeyG1,
    12	        BN254Lib.G2Point memory _publicKeyG2,
    13	        BN254Lib.G1Point memory _signature,
    14	        bool _moveWithLatestRollup
    15	    ) external;
    16	    function stakeWithProvider(
    17	        uint256 _version,
    18	        uint256 _providerIdentifier,
    19	        uint16 _expectedProviderTakeRate,
    20	        address _userRewardsRecipient,
    21	        bool _moveWithLatestRollup
    22	    ) external;
    23	    function moveFundsBackToATP() external;
    24	    function claimRewards(uint256 _version) external;
    25	    function delegate(uint256 _version, address _attester, address _delegatee) external;
    26	}
```

### src/staking/interfaces/IATPWithdrawableAndClaimableStaker.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IATPWithdrawableStaker} from "./IATPWithdrawableStaker.sol";
     5	
     6	/**
     7	 * @title IATPWithdrawableAndClaimableStaker Interface
     8	 * @author Aztec-Labs
     9	 * @notice Interface for an ATP staker that allows for withdrawals from the rollup
    10	 *         and enables ATP token holders to claim tokens only after staking has occurred
    11	 */
    12	interface IATPWithdrawableAndClaimableStaker is IATPWithdrawableStaker {
    13	    /**
    14	     * @notice Withdraw all available tokens to the beneficiary of the ATP
    15	     * @dev Only callable if staking has occurred (withdrawable == true)
    16	     * @dev Only callable by the operator
    17	     *
    18	     * Requirements:
    19	     * - withdrawable must be true (staking must have occurred)
    20	     * - Only operator can call this function
    21	     */
    22	    function withdrawAllTokensToBeneficiary() external;
    23	
    24	    /**
    25	     * @notice The timestamp at which withdrawals are enabled.
    26	     */
    27	    function WITHDRAWAL_TIMESTAMP() external view returns (uint256);
    28	
    29	    /**
    30	     * @notice Check if staking has occurred
    31	     * @return bool indicating whether staking has occurred
    32	     */
    33	    function hasStaked() external view returns (bool);
    34	}
```

### src/staking/interfaces/IATPWithdrawableStaker.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IATPNonWithdrawableStaker} from "./IATPNonWithdrawableStaker.sol";
     5	
     6	interface IATPWithdrawableStaker is IATPNonWithdrawableStaker {
     7	    /**
     8	     * @notice Initiate a withdrawal from the rollup
     9	     *
    10	     * @param _version - the rollup version to withdraw from
    11	     * @param _attester - the address of the attester being withdrawn
    12	     *
    13	     * @dev This will revert if the staker is not the withdrawer
    14	     */
    15	    function initiateWithdraw(uint256 _version, address _attester) external;
    16	
    17	    function finalizeWithdraw(uint256 _version, address _attester) external;
    18	}
```

### src/staking/interfaces/IGovernanceATP.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IPayload} from "src/staking/rollup-system-interfaces/IGovernance.sol";
     5	
     6	interface IGovernanceATP {
     7	    function depositIntoGovernance(uint256 _amount) external;
     8	    function voteInGovernance(uint256 _proposalId, uint256 _amount, bool _support) external;
     9	    function initiateWithdrawFromGovernance(uint256 _amount) external returns (uint256);
    10	    function proposeWithLock(IPayload _proposal) external returns (uint256);
    11	}
```

## src/staking/rollup-system-interfaces/

### src/staking/rollup-system-interfaces/IGSE.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	/**
     5	 * @title Governance Staking Escrow Minimal Interface
     6	 * @author Aztec-Labs
     7	 * @notice A minimal interface for the Governance Staking Escrow contract
     8	 *
     9	 * @dev includes only the function that are interacted with from the staker
    10	 */
    11	interface IGSE {
    12	    function delegate(address _instance, address _attester, address _delegatee) external;
    13	    function ACTIVATION_THRESHOLD() external view returns (uint256);
    14	}
```

### src/staking/rollup-system-interfaces/IGovernance.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	interface IPayload {
     5	    struct Action {
     6	        address target;
     7	        bytes data;
     8	    }
     9	
    10	    /**
    11	     * @notice  A URI that can be used to refer to where a non-coder human readable description
    12	     *          of the payload can be found.
    13	     *
    14	     * @dev     Not used in the contracts, so could be any string really
    15	     *
    16	     * @return - Ideally a useful URI for the payload description
    17	     */
    18	    function getURI() external view returns (string memory);
    19	
    20	    function getActions() external view returns (Action[] memory);
    21	}
    22	
    23	interface IGovernance {
    24	    event Deposit(address indexed depositor, address indexed onBehalfOf, uint256 amount);
    25	    event WithdrawInitiated(uint256 indexed withdrawalId, address indexed recipient, uint256 amount);
    26	    event WithdrawFinalized(uint256 indexed withdrawalId);
    27	    event Proposed(uint256 indexed proposalId, address indexed proposal);
    28	    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 amount);
    29	
    30	    function deposit(address _onBehalfOf, uint256 _amount) external;
    31	    function initiateWithdraw(address _to, uint256 _amount) external returns (uint256);
    32	    function finalizeWithdraw(uint256 _withdrawalId) external;
    33	    function proposeWithLock(IPayload _proposal, address _to) external returns (uint256);
    34	    function vote(uint256 _proposalId, uint256 _amount, bool _support) external;
    35	}
```

### src/staking/rollup-system-interfaces/IRegistry.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	/**
     5	 * @title Rollup Registry Minimal Interface
     6	 * @author Aztec-Labs
     7	 * @notice A minimal interface for the Rollup Registry contract
     8	 *
     9	 * @dev includes only the function that are interacted with from the staker
    10	 */
    11	interface IRegistry {
    12	    function getCanonicalRollup() external view returns (address);
    13	    function getRollup(uint256 _version) external view returns (address);
    14	    function getGovernance() external view returns (address);
    15	}
```

### src/staking/rollup-system-interfaces/IStaking.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {BN254Lib} from "src/staking-registry/libs/BN254.sol";
     5	
     6	/**
     7	 * @title Staking Minimal Interface
     8	 * @author Aztec-Labs
     9	 * @notice A minimal interface for the Staking contract
    10	 *
    11	 * @dev includes only the function that are interacted with from the staker
    12	 */
    13	interface IStaking {
    14	    // TODO: make this line up with the real staking contract
    15	    event Staked(address indexed attester, uint256 amount);
    16	
    17	    function deposit(
    18	        address _attester,
    19	        address _withdrawer,
    20	        BN254Lib.G1Point memory _publicKeyG1,
    21	        BN254Lib.G2Point memory _publicKeyG2,
    22	        BN254Lib.G1Point memory _signature,
    23	        bool _moveWithRollup
    24	    ) external;
    25	    function initiateWithdraw(address _attester, address _recipient) external;
    26	    function finaliseWithdraw(address _attester) external;
    27	    function claimSequencerRewards(address _sequencer) external;
    28	
    29	    function getActivationThreshold() external view returns (uint256);
    30	    function getGSE() external view returns (address);
    31	}
```

## src/tge/

### src/tge/ATPWithdrawableAndClaimableStakerV2.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.30;
     3	
     4	import { IStaking } from "@aztec/core/interfaces/IStaking.sol";
     5	import { IGSE } from "@aztec/governance/GSE.sol";
     6	import { ATPNonWithdrawableStaker } from "src/staking/ATPNonWithdrawableStaker.sol";
     7	import { ATPWithdrawableAndClaimableStaker, IERC20, IRegistry, IStakingRegistry } from "src/staking/ATPWithdrawableAndClaimableStaker.sol";
     8	import { ATPWithdrawableStaker } from "src/staking/ATPWithdrawableStaker.sol";
     9	import { IATPNonWithdrawableStaker } from "src/staking/interfaces/IATPNonWithdrawableStaker.sol";
    10	import { IATPWithdrawableStaker } from "src/staking/interfaces/IATPWithdrawableStaker.sol";
    11	
    12	contract ATPWithdrawableAndClaimableStakerV2 is ATPWithdrawableAndClaimableStaker {
    13	    constructor(
    14	        IERC20 _stakingAsset,
    15	        IRegistry _rollupRegistry,
    16	        IStakingRegistry _stakingRegistry,
    17	        uint256 _withdrawalTimestamp
    18	    ) ATPWithdrawableAndClaimableStaker(_stakingAsset, _rollupRegistry, _stakingRegistry, _withdrawalTimestamp) {}
    19	
    20	    function finalizeWithdraw(uint256 _version, address _attester)
    21	        external
    22	        override(IATPWithdrawableStaker, ATPWithdrawableStaker)
    23	    {
    24	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
    25	        IStaking(rollup).finalizeWithdraw(_attester);
    26	    }
    27	
    28	    function delegate(uint256 _version, address _attester, address _delegatee)
    29	        external
    30	        override(IATPNonWithdrawableStaker, ATPNonWithdrawableStaker)
    31	        onlyOperator
    32	    {
    33	        address rollup = ROLLUP_REGISTRY.getRollup(_version);
    34	        IGSE gse = IGSE(IStaking(rollup).getGSE());
    35	
    36	        address instance = rollup;
    37	
    38	        // If the attester is not registered on the instance, expect the bonus
    39	        // It might not be registered if it have exited, but in that case, it is delegating
    40	        // 0 power, so essentially just a no-op at that point.
    41	        if (!gse.isRegistered(instance, _attester)) {
    42	            instance = gse.getBonusInstanceAddress();
    43	        }
    44	
    45	        gse.delegate(instance, _attester, _delegatee);
    46	    }
    47	}
```

### src/tge/TGEPayload.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.30;
     3	
     4	import {IRegistry as IATPRegistry} from "@atp/Registry.sol";
     5	import {IRollupCore} from "@aztec/core/interfaces/IRollup.sol";
     6	import {IPayload} from "@aztec/governance/interfaces/IPayload.sol";
     7	import {IDateGatedRelayer} from "@aztec/periphery/interfaces/IDateGatedRelayer.sol";
     8	import {Ownable2Step} from "@oz/access/Ownable2Step.sol";
     9	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
    10	import {StakingRegistry} from "src/staking-registry/StakingRegistry.sol";
    11	import {ATPWithdrawableAndClaimableStakerV2, IRegistry} from "src/tge/ATPWithdrawableAndClaimableStakerV2.sol";
    12	import {GovernanceAcceleratedLock} from "src/uniswap-periphery/GovernanceAcceleratedLock.sol";
    13	import {IVirtualLBPStrategyBasic} from "src/uniswap-periphery/IVirtualLBPStrategyBasic.sol";
    14	
    15	contract TGEPayload is IPayload {
    16	    IATPRegistry public constant ATP_REGISTRY = IATPRegistry(0x63841bAD6B35b6419e15cA9bBBbDf446D4dC3dde);
    17	    IVirtualLBPStrategyBasic public constant VIRTUAL_LBP_STRATEGY =
    18	        IVirtualLBPStrategyBasic(0xd53006d1e3110fD319a79AEEc4c527a0d265E080);
    19	    IRegistry public constant ROLLUP_REGISTRY = IRegistry(0x35b22e09Ee0390539439E24f06Da43D83f90e298);
    20	    IERC20 public constant AZTEC_TOKEN = IERC20(0xA27EC0006e59f245217Ff08CD52A7E8b169E62D2);
    21	    StakingRegistry public constant STAKING_REGISTRY = StakingRegistry(0x042dF8f42790d6943F41C25C2132400fd727f452);
    22	    address public constant DATE_GATED_RELAYER_SHORT = 0x7d6DECF157E1329A20c4596eAf78D387E896aa4e;
    23	    address public constant ROLLUP = 0x603bb2c05D474794ea97805e8De69bCcFb3bCA12;
    24	
    25	    // Jan 1, 2026 00:00:00 CET (Dec 31, 2025 23:00:00 UTC) - a Thursday
    26	    uint256 public constant JAN_1_2026_CET = 1767222000;
    27	
    28	    // Day of week constants (Monday = 0, Sunday = 6)
    29	    uint256 internal constant MONDAY = 0;
    30	    uint256 internal constant TUESDAY = 1;
    31	    uint256 internal constant WEDNESDAY = 2;
    32	    uint256 internal constant THURSDAY = 3;
    33	    uint256 internal constant FRIDAY = 4;
    34	    uint256 internal constant SATURDAY = 5;
    35	    uint256 internal constant SUNDAY = 6;
    36	
    37	    // Configurable business hours (CET)
    38	    uint256 public constant START_OF_WORKDAY = 8 hours;
    39	    uint256 public constant END_OF_WORKDAY = 15 hours;
    40	    uint256 public constant START_DAY = TUESDAY;
    41	    uint256 public constant END_DAY = THURSDAY;
    42	
    43	    ATPWithdrawableAndClaimableStakerV2 public immutable STAKER;
    44	
    45	    error OutsideBusinessHours(uint256 secondsSinceMidnightCET, uint256 dayOfWeek);
    46	
    47	    modifier inBusinessHours() {
    48	        // Constraint: Since it opens up for trading, and will be aligned with centralized exchanges,
    49	        // execution should only happen during configured business hours and days (in CET)
    50	
    51	        uint256 timeSinceReference = block.timestamp - JAN_1_2026_CET;
    52	        uint256 secondsSinceMidnight = timeSinceReference % 1 days;
    53	
    54	        // Calculate day of week with Monday=0, Sunday=6
    55	        // Jan 1, 2026 was a Thursday (day 3 in Monday=0), so we add 3
    56	        uint256 daysSinceReference = timeSinceReference / 1 days;
    57	        uint256 dayOfWeek = (daysSinceReference + 3) % 7;
    58	
    59	        require(
    60	            secondsSinceMidnight >= START_OF_WORKDAY && secondsSinceMidnight < END_OF_WORKDAY && dayOfWeek >= START_DAY
    61	                && dayOfWeek <= END_DAY,
    62	            OutsideBusinessHours(secondsSinceMidnight, dayOfWeek)
    63	        );
    64	
    65	        _;
    66	    }
    67	
    68	    constructor() {
    69	        STAKER =
    70	            new ATPWithdrawableAndClaimableStakerV2(AZTEC_TOKEN, ROLLUP_REGISTRY, STAKING_REGISTRY, block.timestamp);
    71	    }
    72	
    73	    function getActions() external view override(IPayload) inBusinessHours returns (IPayload.Action[] memory) {
    74	        // [ ] 0. Accelerate the lock
    75	        // [ ] 1. Accept the ownership
    76	        // [ ] 2. Set the unlock start time
    77	        // [ ] 3. Register the staker
    78	        // [ ] 4. Approve the migration (allow trading)
    79	        // [ ] 5. Make rewards claimable
    80	
    81	        IPayload.Action[] memory actions = new IPayload.Action[](6);
    82	
    83	        actions[0] = IPayload.Action({
    84	            target: DATE_GATED_RELAYER_SHORT,
    85	            data: abi.encodeWithSelector(GovernanceAcceleratedLock.accelerateLock.selector)
    86	        });
    87	
    88	        actions[1] = IPayload.Action({
    89	            target: DATE_GATED_RELAYER_SHORT,
    90	            data: abi.encodeWithSelector(
    91	                IDateGatedRelayer.relay.selector,
    92	                address(ATP_REGISTRY),
    93	                abi.encodeWithSelector(Ownable2Step.acceptOwnership.selector)
    94	            )
    95	        });
    96	
    97	        actions[2] = IPayload.Action({
    98	            target: DATE_GATED_RELAYER_SHORT,
    99	            data: abi.encodeWithSelector(
   100	                IDateGatedRelayer.relay.selector,
   101	                address(ATP_REGISTRY),
   102	                abi.encodeWithSelector(IATPRegistry.setUnlockStartTime.selector, block.timestamp - 365 days)
   103	            )
   104	        });
   105	
   106	        actions[3] = IPayload.Action({
   107	            target: DATE_GATED_RELAYER_SHORT,
   108	            data: abi.encodeWithSelector(
   109	                IDateGatedRelayer.relay.selector,
   110	                address(ATP_REGISTRY),
   111	                abi.encodeWithSelector(IATPRegistry.registerStakerImplementation.selector, address(STAKER))
   112	            )
   113	        });
   114	
   115	        actions[4] = IPayload.Action({
   116	            target: DATE_GATED_RELAYER_SHORT,
   117	            data: abi.encodeWithSelector(
   118	                IDateGatedRelayer.relay.selector,
   119	                address(VIRTUAL_LBP_STRATEGY),
   120	                abi.encodeWithSelector(IVirtualLBPStrategyBasic.approveMigration.selector)
   121	            )
   122	        });
   123	
   124	        actions[5] = IPayload.Action({
   125	            target: ROLLUP, data: abi.encodeWithSelector(IRollupCore.setRewardsClaimable.selector, true)
   126	        });
   127	
   128	        return actions;
   129	    }
   130	
   131	    function getURI() external pure override(IPayload) returns (string memory) {
   132	        return "https://github.com/AztecProtocol/ignition-contracts/";
   133	    }
   134	}
```

## src/token-vaults/

### src/token-vaults/ATPFactory.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {Ownable2Step, Ownable} from "@oz/access/Ownable2Step.sol";
     5	import {Clones} from "@oz/proxy/Clones.sol";
     6	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     7	import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
     8	import {ILATP, RevokableParams} from "./atps/linear/ILATP.sol";
     9	import {IMATP, MilestoneId} from "./atps/milestone/IMATP.sol";
    10	import {LATP} from "./atps/linear/LATP.sol";
    11	import {MATP} from "./atps/milestone/MATP.sol";
    12	import {INCATP} from "./atps/noclaim/INCATP.sol";
    13	import {NCATP} from "./atps/noclaim/NCATP.sol";
    14	import {Registry, IRegistry} from "./Registry.sol";
    15	
    16	import {LATPFactory} from "./deployment-factories/LATPFactory.sol";
    17	import {NCATPFactory} from "./deployment-factories/NCATPFactory.sol";
    18	import {MATPFactory} from "./deployment-factories/MATPFactory.sol";
    19	
    20	interface IATPFactory {
    21	    event ATPCreated(address indexed beneficiary, address indexed atp, uint256 allocation);
    22	    event MinterSet(address indexed minter, bool isMinter);
    23	
    24	    error InvalidInputLength();
    25	    error NotMinter();
    26	
    27	    function createLATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
    28	        external
    29	        returns (ILATP);
    30	
    31	    function createNCATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
    32	        external
    33	        returns (INCATP);
    34	
    35	    function createMATP(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId) external returns (IMATP);
    36	
    37	    function createLATPs(
    38	        address[] memory _beneficiaries,
    39	        uint256[] memory _allocations,
    40	        RevokableParams[] memory _revokableParams
    41	    ) external returns (ILATP[] memory);
    42	
    43	    function createNCATPs(
    44	        address[] memory _beneficiaries,
    45	        uint256[] memory _allocations,
    46	        RevokableParams[] memory _revokableParams
    47	    ) external returns (INCATP[] memory);
    48	
    49	    function createMATPs(
    50	        address[] memory _beneficiaries,
    51	        uint256[] memory _allocations,
    52	        MilestoneId[] memory _milestoneIds
    53	    ) external returns (IMATP[] memory);
    54	
    55	    function recoverTokens(address _token, address _to, uint256 _amount) external;
    56	
    57	    function setMinter(address _minter, bool _isMinter) external;
    58	
    59	    function getRegistry() external view returns (IRegistry);
    60	
    61	    function getToken() external view returns (IERC20);
    62	
    63	    function predictLATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
    64	        external
    65	        view
    66	        returns (address);
    67	
    68	    function predictNCATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
    69	        external
    70	        view
    71	        returns (address);
    72	
    73	    function predictMATPAddress(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
    74	        external
    75	        view
    76	        returns (address);
    77	}
    78	
    79	contract ATPFactory is Ownable2Step, IATPFactory {
    80	    using SafeERC20 for IERC20;
    81	
    82	    Registry internal immutable REGISTRY;
    83	    IERC20 internal immutable TOKEN;
    84	
    85	    LATP internal immutable LATP_IMPLEMENTATION;
    86	    NCATP internal immutable NCATP_IMPLEMENTATION;
    87	    MATP internal immutable MATP_IMPLEMENTATION;
    88	
    89	    mapping(address => bool) public minter;
    90	
    91	    modifier onlyMinter() {
    92	        require(minter[msg.sender], NotMinter());
    93	        _;
    94	    }
    95	
    96	    constructor(address __owner, IERC20 _token, uint256 _unlockCliffDuration, uint256 _unlockLockDuration)
    97	        Ownable(__owner)
    98	    {
    99	        REGISTRY = new Registry(__owner, _unlockCliffDuration, _unlockLockDuration);
   100	        TOKEN = _token;
   101	        LATP_IMPLEMENTATION = LATPFactory.deployImplementation(IRegistry(address(REGISTRY)), TOKEN);
   102	        NCATP_IMPLEMENTATION = NCATPFactory.deployImplementation(IRegistry(address(REGISTRY)), TOKEN);
   103	        MATP_IMPLEMENTATION = MATPFactory.deployImplementation(IRegistry(address(REGISTRY)), TOKEN);
   104	
   105	        minter[__owner] = true;
   106	        emit MinterSet(__owner, true);
   107	    }
   108	
   109	    /**
   110	     * @notice  Recover any token from the contract
   111	     *
   112	     * @dev     The caller must be the `owner`
   113	     *
   114	     * @dev     Does not support Ether as it is not an ERC20,
   115	     *
   116	     * @param _token   The token to rescue
   117	     * @param _to   The address to rescue the tokens to
   118	     * @param _amount   The amount of tokens to rescue
   119	     */
   120	    function recoverTokens(address _token, address _to, uint256 _amount) external override(IATPFactory) onlyOwner {
   121	        IERC20(_token).safeTransfer(_to, _amount);
   122	    }
   123	
   124	    /**
   125	     * @notice  Set the minter status of an address
   126	     *
   127	     * @dev     The caller must be the `owner`
   128	     *
   129	     * @param _minter The address to set the minter status of
   130	     * @param _isMinter The minter status to set
   131	     */
   132	    function setMinter(address _minter, bool _isMinter) external override(IATPFactory) onlyOwner {
   133	        minter[_minter] = _isMinter;
   134	        emit MinterSet(_minter, _isMinter);
   135	    }
   136	
   137	    /**
   138	     * @notice  Create and fund multiple LATPs
   139	     *          Creates the LATPs using the `clones` library, initializes it and funds it.
   140	     *
   141	     * @dev     The caller must be a minter
   142	     *
   143	     * @param _beneficiaries The addresses of the beneficiaries
   144	     * @param _allocations The amounts of tokens to allocate to the LATPs
   145	     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary,
   146	     *                         provide empty `LockParams` and `address(0)` as `revokeBeneficiary`
   147	     *                         if the LATP are not revokable
   148	     *
   149	     * @return The LATPs
   150	     */
   151	    function createLATPs(
   152	        address[] memory _beneficiaries,
   153	        uint256[] memory _allocations,
   154	        RevokableParams[] memory _revokableParams
   155	    ) external virtual override(IATPFactory) onlyMinter returns (ILATP[] memory) {
   156	        require(
   157	            _beneficiaries.length == _allocations.length && _beneficiaries.length == _revokableParams.length,
   158	            InvalidInputLength()
   159	        );
   160	        ILATP[] memory atps = new ILATP[](_beneficiaries.length);
   161	        for (uint256 i = 0; i < _beneficiaries.length; i++) {
   162	            atps[i] = createLATP(_beneficiaries[i], _allocations[i], _revokableParams[i]);
   163	        }
   164	        return atps;
   165	    }
   166	
   167	    /**
   168	     * @notice  Create and fund multiple NCATPs
   169	     *          Creates the NCATPs using the `clones` library, initializes it and funds it.
   170	     *
   171	     * @dev     The caller must be a `minter`
   172	     *
   173	     * @param _beneficiaries The addresses of the beneficiaries
   174	     * @param _allocations The amounts of tokens to allocate to the NCATPs
   175	     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary,
   176	     *                         provide empty `LockParams` and `address(0)` as `revokeBeneficiary`
   177	     *                         if the NCATP are not revokable
   178	     *
   179	     * @return The NCATPs
   180	     */
   181	    function createNCATPs(
   182	        address[] memory _beneficiaries,
   183	        uint256[] memory _allocations,
   184	        RevokableParams[] memory _revokableParams
   185	    ) external virtual override(IATPFactory) onlyMinter returns (INCATP[] memory) {
   186	        require(
   187	            _beneficiaries.length == _allocations.length && _beneficiaries.length == _revokableParams.length,
   188	            InvalidInputLength()
   189	        );
   190	        INCATP[] memory atps = new INCATP[](_beneficiaries.length);
   191	        for (uint256 i = 0; i < _beneficiaries.length; i++) {
   192	            atps[i] = createNCATP(_beneficiaries[i], _allocations[i], _revokableParams[i]);
   193	        }
   194	        return atps;
   195	    }
   196	
   197	    /**
   198	     * @notice  Create and fund multiple MATPs
   199	     *          Creates the MATPs using the `clones` library, initializes it and funds it.
   200	     *
   201	     * @dev     The caller must be a `minter`
   202	     *
   203	     * @param _beneficiaries The addresses of the beneficiaries
   204	     * @param _allocations The amounts of tokens to allocate to the MATPs
   205	     * @param _milestoneIds The milestone IDs for the MATPs
   206	     *
   207	     * @return The MATPs
   208	     */
   209	    function createMATPs(
   210	        address[] memory _beneficiaries,
   211	        uint256[] memory _allocations,
   212	        MilestoneId[] memory _milestoneIds
   213	    ) external virtual override(IATPFactory) onlyMinter returns (IMATP[] memory) {
   214	        require(
   215	            _beneficiaries.length == _allocations.length && _beneficiaries.length == _milestoneIds.length,
   216	            InvalidInputLength()
   217	        );
   218	        IMATP[] memory atps = new IMATP[](_beneficiaries.length);
   219	        for (uint256 i = 0; i < _beneficiaries.length; i++) {
   220	            atps[i] = createMATP(_beneficiaries[i], _allocations[i], _milestoneIds[i]);
   221	        }
   222	        return atps;
   223	    }
   224	
   225	    /**
   226	     * @notice  Get the registry
   227	     *
   228	     * @return  The registry
   229	     */
   230	    function getRegistry() external view override(IATPFactory) returns (IRegistry) {
   231	        return IRegistry(address(REGISTRY));
   232	    }
   233	
   234	    /**
   235	     * @notice  Get the token
   236	     *
   237	     * @return  The token
   238	     */
   239	    function getToken() external view override(IATPFactory) returns (IERC20) {
   240	        return TOKEN;
   241	    }
   242	
   243	    /**
   244	     * @notice  Predict the address of an LATP
   245	     *
   246	     * @param _beneficiary   The address of the beneficiary
   247	     * @param _allocation    The amount of tokens to allocate to the LATP
   248	     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary, if the LATPs are revokable
   249	     *
   250	     * @return  The address of the LATP
   251	     */
   252	    function predictLATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
   253	        external
   254	        view
   255	        virtual
   256	        override(IATPFactory)
   257	        returns (address)
   258	    {
   259	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
   260	        return Clones.predictDeterministicAddress(address(LATP_IMPLEMENTATION), salt, address(this));
   261	    }
   262	
   263	    function predictNCATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
   264	        external
   265	        view
   266	        virtual
   267	        override(IATPFactory)
   268	        returns (address)
   269	    {
   270	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
   271	        return Clones.predictDeterministicAddress(address(NCATP_IMPLEMENTATION), salt, address(this));
   272	    }
   273	
   274	    function predictMATPAddress(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
   275	        external
   276	        view
   277	        virtual
   278	        override(IATPFactory)
   279	        returns (address)
   280	    {
   281	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
   282	        return Clones.predictDeterministicAddress(address(MATP_IMPLEMENTATION), salt, address(this));
   283	    }
   284	
   285	    /**
   286	     * @notice  Create and funds a new LATP
   287	     *          The LATP is created using the `Clones` library and then initialized.
   288	     *          We deploy deterministically using the initialization params as the salt.
   289	     *          When created, the LATP is funded with the `_allocation` amount of tokens.
   290	     *
   291	     *          This setup is done to keep gas costs low.
   292	     *
   293	     * @dev     The caller must be a `minter`
   294	     *
   295	     * @param _beneficiary   The address of the beneficiary
   296	     * @param _allocation    The amount of tokens to allocate to the LATP
   297	     * @param _revokableParams   The parameters for the accumulation lock, if the LATP is revokable
   298	     *
   299	     * @return  The LATP
   300	     */
   301	    function createLATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
   302	        public
   303	        virtual
   304	        override(IATPFactory)
   305	        onlyMinter
   306	        returns (ILATP)
   307	    {
   308	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
   309	        LATP atp = LATP(Clones.cloneDeterministic(address(LATP_IMPLEMENTATION), salt));
   310	        atp.initialize(_beneficiary, _allocation, _revokableParams);
   311	        TOKEN.safeTransfer(address(atp), _allocation);
   312	        emit ATPCreated(_beneficiary, address(atp), _allocation);
   313	        return ILATP(address(atp));
   314	    }
   315	
   316	    /**
   317	     * @notice  Create and funds a new NCATP (Non-Claimable ATP)
   318	     *          The NCATP is created using the `Clones` library and then initialized.
   319	     *          We deploy deterministically using the initialization params as the salt.
   320	     *          When created, the NCATP is funded with the `_allocation` amount of tokens.
   321	     *
   322	     *          This setup is done to keep gas costs low.
   323	     *
   324	     * @dev     The caller must be a `minter`
   325	     *
   326	     * @param _beneficiary   The address of the beneficiary
   327	     * @param _allocation    The amount of tokens to allocate to the NCATP
   328	     * @param _revokableParams   The parameters for the accumulation lock, if the NCATP is revokable
   329	     *
   330	     * @return  The NCATP
   331	     */
   332	    function createNCATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
   333	        public
   334	        virtual
   335	        override(IATPFactory)
   336	        onlyMinter
   337	        returns (INCATP)
   338	    {
   339	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
   340	        NCATP atp = NCATP(Clones.cloneDeterministic(address(NCATP_IMPLEMENTATION), salt));
   341	        atp.initialize(_beneficiary, _allocation, _revokableParams);
   342	        TOKEN.safeTransfer(address(atp), _allocation);
   343	        emit ATPCreated(_beneficiary, address(atp), _allocation);
   344	        return INCATP(address(atp));
   345	    }
   346	
   347	    /**
   348	     * @notice  Create and funds a new MATP
   349	     *          The MATP is created using the `Clones` library and then initialized.
   350	     *          We deploy deterministically using the initialization params as the salt.
   351	     *          When created, the MATP is funded with the `_allocation` amount of tokens.
   352	     *
   353	     *          This setup is done to keep gas costs low.
   354	     *
   355	     * @dev     The caller must be a `minter`
   356	     *
   357	     * @param _beneficiary   The address of the beneficiary
   358	     * @param _allocation    The amount of tokens to allocate to the MATP
   359	     * @param _milestoneId   The milestone ID for the MATP
   360	     *
   361	     * @return  The MATP
   362	     */
   363	    function createMATP(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
   364	        public
   365	        virtual
   366	        override(IATPFactory)
   367	        onlyMinter
   368	        returns (IMATP)
   369	    {
   370	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
   371	        MATP atp = MATP(Clones.cloneDeterministic(address(MATP_IMPLEMENTATION), salt));
   372	        atp.initialize(_beneficiary, _allocation, _milestoneId);
   373	        TOKEN.safeTransfer(address(atp), _allocation);
   374	        emit ATPCreated(_beneficiary, address(atp), _allocation);
   375	        return IMATP(address(atp));
   376	    }
   377	}
```

### src/token-vaults/ATPFactoryNonces.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {Clones} from "@oz/proxy/Clones.sol";
     5	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     6	import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
     7	import {IATPFactory, ATPFactory} from "./ATPFactory.sol";
     8	import {ILATP, RevokableParams} from "./atps/linear/ILATP.sol";
     9	import {LATP} from "./atps/linear/LATP.sol";
    10	import {IMATP, MilestoneId} from "./atps/milestone/IMATP.sol";
    11	import {MATP} from "./atps/milestone/MATP.sol";
    12	import {INCATP} from "./atps/noclaim/INCATP.sol";
    13	import {NCATP} from "./atps/noclaim/NCATP.sol";
    14	import {Nonces} from "./Nonces.sol";
    15	
    16	interface IATPFactoryNonces is IATPFactory {
    17	    function predictLATPAddressWithNonce(
    18	        address _beneficiary,
    19	        uint256 _allocation,
    20	        RevokableParams memory _revokableParams,
    21	        uint256 _nonce
    22	    ) external view returns (address);
    23	
    24	    function predictNCATPAddressWithNonce(
    25	        address _beneficiary,
    26	        uint256 _allocation,
    27	        RevokableParams memory _revokableParams,
    28	        uint256 _nonce
    29	    ) external view returns (address);
    30	
    31	    function predictMATPAddressWithNonce(
    32	        address _beneficiary,
    33	        uint256 _allocation,
    34	        MilestoneId _milestoneId,
    35	        uint256 _nonce
    36	    ) external view returns (address);
    37	}
    38	
    39	contract ATPFactoryNonces is IATPFactoryNonces, ATPFactory, Nonces {
    40	    using SafeERC20 for IERC20;
    41	
    42	    constructor(address __owner, IERC20 _token, uint256 _unlockCliffDuration, uint256 _unlockLockDuration)
    43	        ATPFactory(__owner, _token, _unlockCliffDuration, _unlockLockDuration)
    44	    {}
    45	
    46	    /**
    47	     * @notice  Predict the address of an LATP
    48	     *
    49	     * @param _beneficiary   The address of the beneficiary
    50	     * @param _allocation    The amount of tokens to allocate to the LATP
    51	     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary, if the LATPs are revokable
    52	     *
    53	     * @return  The address of the LATP
    54	     */
    55	    function predictLATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
    56	        external
    57	        view
    58	        override(IATPFactory, ATPFactory)
    59	        returns (address)
    60	    {
    61	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
    62	
    63	        uint256 nonce = nonces(salt);
    64	        salt = keccak256(abi.encode(salt, nonce));
    65	        return Clones.predictDeterministicAddress(address(LATP_IMPLEMENTATION), salt, address(this));
    66	    }
    67	
    68	    /**
    69	     * @notice  Predict the address of an LATP with a given nonce
    70	     *
    71	     * @param _beneficiary   The address of the beneficiary
    72	     * @param _allocation    The amount of tokens to allocate to the LATP
    73	     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary, if the LATPs are revokable
    74	     * @param _nonce   The nonce to use for the prediction
    75	     *
    76	     * @return  The address of the LATP
    77	     */
    78	    function predictLATPAddressWithNonce(
    79	        address _beneficiary,
    80	        uint256 _allocation,
    81	        RevokableParams memory _revokableParams,
    82	        uint256 _nonce
    83	    ) external view override(IATPFactoryNonces) returns (address) {
    84	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
    85	        salt = keccak256(abi.encode(salt, _nonce));
    86	        return Clones.predictDeterministicAddress(address(LATP_IMPLEMENTATION), salt, address(this));
    87	    }
    88	
    89	    /// @inheritdoc IATPFactory
    90	    function predictNCATPAddress(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
    91	        external
    92	        view
    93	        override(IATPFactory, ATPFactory)
    94	        returns (address)
    95	    {
    96	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
    97	
    98	        uint256 nonce = nonces(salt);
    99	        salt = keccak256(abi.encode(salt, nonce));
   100	        return Clones.predictDeterministicAddress(address(NCATP_IMPLEMENTATION), salt, address(this));
   101	    }
   102	
   103	    /**
   104	     * @notice  Predict the address of an NCATP with a given nonce
   105	     *
   106	     * @param _beneficiary   The address of the beneficiary
   107	     * @param _allocation    The amount of tokens to allocate to the NCATP
   108	     * @param _revokableParams The parameters for the accumulation lock and revoke beneficiary, if the NCATP is revokable
   109	     * @param _nonce   The nonce to use for the prediction
   110	     *
   111	     * @return  The address of the NCATP
   112	     */
   113	    function predictNCATPAddressWithNonce(
   114	        address _beneficiary,
   115	        uint256 _allocation,
   116	        RevokableParams memory _revokableParams,
   117	        uint256 _nonce
   118	    ) external view override(IATPFactoryNonces) returns (address) {
   119	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
   120	        salt = keccak256(abi.encode(salt, _nonce));
   121	        return Clones.predictDeterministicAddress(address(NCATP_IMPLEMENTATION), salt, address(this));
   122	    }
   123	
   124	    /// @inheritdoc IATPFactory
   125	    function predictMATPAddress(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
   126	        external
   127	        view
   128	        virtual
   129	        override(IATPFactory, ATPFactory)
   130	        returns (address)
   131	    {
   132	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
   133	
   134	        uint256 nonce = nonces(salt);
   135	        salt = keccak256(abi.encode(salt, nonce));
   136	        return Clones.predictDeterministicAddress(address(MATP_IMPLEMENTATION), salt, address(this));
   137	    }
   138	
   139	    function predictMATPAddressWithNonce(
   140	        address _beneficiary,
   141	        uint256 _allocation,
   142	        MilestoneId _milestoneId,
   143	        uint256 _nonce
   144	    ) external view override(IATPFactoryNonces) returns (address) {
   145	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
   146	        salt = keccak256(abi.encode(salt, _nonce));
   147	        return Clones.predictDeterministicAddress(address(MATP_IMPLEMENTATION), salt, address(this));
   148	    }
   149	
   150	    /**
   151	     * @notice  Create and funds a new LATP
   152	     *          The LATP is created using the `Clones` library and then initialized.
   153	     *          We deploy deterministically using the initialization params as the salt.
   154	     *          When created, the LATP is funded with the `_allocation` amount of tokens.
   155	     *
   156	     *          This setup is done to keep gas costs low.
   157	     *
   158	     * @dev     The caller must be a `minter`
   159	     *
   160	     * @param _beneficiary   The address of the beneficiary
   161	     * @param _allocation    The amount of tokens to allocate to the LATP
   162	     * @param _revokableParams   The parameters for the accumulation lock, if the LATP is revokable
   163	     *
   164	     * @return  The LATP
   165	     */
   166	    function createLATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
   167	        public
   168	        override(IATPFactory, ATPFactory)
   169	        onlyMinter
   170	        returns (ILATP)
   171	    {
   172	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
   173	
   174	        uint256 nonce = useNonce(salt);
   175	        salt = keccak256(abi.encode(salt, nonce));
   176	
   177	        LATP atp = LATP(Clones.cloneDeterministic(address(LATP_IMPLEMENTATION), salt));
   178	        atp.initialize(_beneficiary, _allocation, _revokableParams);
   179	        TOKEN.safeTransfer(address(atp), _allocation);
   180	        emit ATPCreated(_beneficiary, address(atp), _allocation);
   181	        return ILATP(address(atp));
   182	    }
   183	
   184	    /**
   185	     * @notice  Create and funds a new NCATP (Non-Claimable ATP)
   186	     *          The NCATP is created using the `Clones` library and then initialized.
   187	     *          We deploy deterministically using the initialization params as the salt.
   188	     *          When created, the NCATP is funded with the `_allocation` amount of tokens.
   189	     *
   190	     *          This setup is done to keep gas costs low.
   191	     *
   192	     * @dev     The caller must be a `minter`
   193	     *
   194	     * @param _beneficiary   The address of the beneficiary
   195	     * @param _allocation    The amount of tokens to allocate to the NCATP
   196	     * @param _revokableParams   The parameters for the accumulation lock, if the NCATP is revokable
   197	     *
   198	     * @return  The NCATP
   199	     */
   200	    function createNCATP(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
   201	        public
   202	        override(IATPFactory, ATPFactory)
   203	        onlyMinter
   204	        returns (INCATP)
   205	    {
   206	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _revokableParams));
   207	
   208	        uint256 nonce = useNonce(salt);
   209	        salt = keccak256(abi.encode(salt, nonce));
   210	
   211	        NCATP atp = NCATP(Clones.cloneDeterministic(address(NCATP_IMPLEMENTATION), salt));
   212	        atp.initialize(_beneficiary, _allocation, _revokableParams);
   213	        TOKEN.safeTransfer(address(atp), _allocation);
   214	        emit ATPCreated(_beneficiary, address(atp), _allocation);
   215	        return INCATP(address(atp));
   216	    }
   217	
   218	    /**
   219	     * @notice  Create and funds a new MATP
   220	     *          The MATP is created using the `Clones` library and then initialized.
   221	     *          We deploy deterministically using the initialization params as the salt.
   222	     *          When created, the MATP is funded with the `_allocation` amount of tokens.
   223	     *
   224	     *          This setup is done to keep gas costs low.
   225	     *
   226	     * @dev     The caller must be a `minter`
   227	     *
   228	     * @param _beneficiary   The address of the beneficiary
   229	     * @param _allocation    The amount of tokens to allocate to the MATP
   230	     * @param _milestoneId   The milestone ID for the MATP
   231	     *
   232	     * @return  The MATP
   233	     */
   234	    function createMATP(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
   235	        public
   236	        override(IATPFactory, ATPFactory)
   237	        onlyMinter
   238	        returns (IMATP)
   239	    {
   240	        bytes32 salt = keccak256(abi.encode(_beneficiary, _allocation, _milestoneId));
   241	
   242	        uint256 nonce = useNonce(salt);
   243	        salt = keccak256(abi.encode(salt, nonce));
   244	
   245	        MATP atp = MATP(Clones.cloneDeterministic(address(MATP_IMPLEMENTATION), salt));
   246	        atp.initialize(_beneficiary, _allocation, _milestoneId);
   247	        TOKEN.safeTransfer(address(atp), _allocation);
   248	        emit ATPCreated(_beneficiary, address(atp), _allocation);
   249	        return IMATP(address(atp));
   250	    }
   251	}
```

### src/token-vaults/Nonces.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	/**
     5	 * @title Track hash Nonces
     6	 * @dev See OpenZeppelin's Nonces.sol
     7	 */
     8	abstract contract Nonces {
     9	    mapping(bytes32 hash => uint256) private _nonces;
    10	
    11	    /**
    12	     * @dev Returns the next unused nonce for a hash.
    13	     */
    14	    function nonces(bytes32 _hash) public view virtual returns (uint256) {
    15	        return _nonces[_hash];
    16	    }
    17	
    18	    /**
    19	     * @dev Consumes a nonce.
    20	     *
    21	     * Returns the current value and increments nonce.
    22	     */
    23	    function useNonce(bytes32 _hash) internal virtual returns (uint256) {
    24	        // For each hash, the nonce has an initial value of 0, can only be incremented by one, and cannot be
    25	        // decremented or reset. This guarantees that the nonce never overflows.
    26	        unchecked {
    27	            // It is important to do x++ and not ++x here.
    28	            return _nonces[_hash]++;
    29	        }
    30	    }
    31	}
```

### src/token-vaults/Registry.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {Ownable2Step, Ownable} from "@oz/access/Ownable2Step.sol";
     5	import {UUPSUpgradeable, ERC1967Utils} from "@oz/proxy/utils/UUPSUpgradeable.sol";
     6	import {LockParams} from "./libraries/LockLib.sol";
     7	import {BaseStaker} from "./staker/BaseStaker.sol";
     8	
     9	type MilestoneId is uint96;
    10	
    11	type StakerVersion is uint256;
    12	
    13	enum MilestoneStatus {
    14	    Pending,
    15	    Failed,
    16	    Succeeded
    17	}
    18	
    19	interface IRegistry {
    20	    event UpdatedRevoker(address revoker);
    21	    event UpdatedRevokerOperator(address revokerOperator);
    22	    event UpdatedExecuteAllowedAt(uint256 executeAllowedAt);
    23	    event UpdatedUnlockStartTime(uint256 unlockStartTime);
    24	    event StakerRegistered(StakerVersion version, address implementation);
    25	    event MilestoneAdded(MilestoneId milestoneId);
    26	    event MilestoneStatusUpdated(MilestoneId milestoneId, MilestoneStatus status);
    27	
    28	    error InvalidExecuteAllowedAt(uint256 newExecuteAllowedAt, uint256 currentExecuteAllowedAt);
    29	    error InvalidUnlockStartTime(uint256 newUnlockStartTime, uint256 currentUnlockStartTime);
    30	    error InvalidUnlockDuration();
    31	    error InvalidUnlockCliffDuration();
    32	    error InvalidStakerImplementation(address implementation);
    33	
    34	    error UnRegisteredStaker(StakerVersion version);
    35	    error InvalidMilestoneId(MilestoneId milestoneId);
    36	    error InvalidMilestoneStatus(MilestoneId milestoneId);
    37	
    38	    function setRevoker(address _revoker) external;
    39	    function setRevokerOperator(address _revokerOperator) external;
    40	    function setExecuteAllowedAt(uint256 _executeAllowedAt) external;
    41	    function setUnlockStartTime(uint256 _unlockStartTime) external;
    42	    function registerStakerImplementation(address _implementation) external;
    43	    function addMilestone() external returns (MilestoneId);
    44	    function setMilestoneStatus(MilestoneId _milestoneId, MilestoneStatus _status) external;
    45	
    46	    function getRevoker() external view returns (address);
    47	    function getRevokerOperator() external view returns (address);
    48	    function getExecuteAllowedAt() external view returns (uint256);
    49	    function getUnlockStartTime() external view returns (uint256);
    50	    function getGlobalLockParams() external view returns (LockParams memory);
    51	    function getStakerImplementation(StakerVersion _version) external view returns (address);
    52	    function getNextStakerVersion() external view returns (StakerVersion);
    53	    function getMilestoneStatus(MilestoneId _milestoneId) external view returns (MilestoneStatus);
    54	    function getNextMilestoneId() external view returns (MilestoneId);
    55	}
    56	
    57	contract Registry is Ownable2Step, IRegistry {
    58	    uint256 internal immutable UNLOCK_CLIFF_DURATION;
    59	    uint256 internal immutable UNLOCK_LOCK_DURATION;
    60	
    61	    // @note An initial value set to be the unix timestamp of 1st of January 2027
    62	    uint256 internal unlockStartTime = 1798761600;
    63	    uint256 internal executeAllowedAt = 1798761600;
    64	    address internal revoker;
    65	    address internal revokerOperator;
    66	
    67	    StakerVersion internal nextStakerVersion;
    68	    mapping(StakerVersion version => address implementation) internal stakerImplementations;
    69	
    70	    MilestoneId internal nextMilestoneId;
    71	    mapping(MilestoneId milestoneId => MilestoneStatus status) internal milestones;
    72	
    73	    constructor(address __owner, uint256 _unlockCliffDuration, uint256 _unlockLockDuration) Ownable(__owner) {
    74	        require(_unlockLockDuration > 0, InvalidUnlockDuration());
    75	        require(_unlockLockDuration >= _unlockCliffDuration, InvalidUnlockCliffDuration());
    76	
    77	        UNLOCK_CLIFF_DURATION = _unlockCliffDuration;
    78	        UNLOCK_LOCK_DURATION = _unlockLockDuration;
    79	
    80	        // @note Register the base staker implementation
    81	        stakerImplementations[StakerVersion.wrap(0)] = address(new BaseStaker());
    82	        nextStakerVersion = StakerVersion.wrap(1);
    83	    }
    84	
    85	    /**
    86	     * @notice  Add a new milestone
    87	     *
    88	     * @dev Only callable by the owner
    89	     *
    90	     * @return  The milestone id
    91	     */
    92	    function addMilestone() external override(IRegistry) onlyOwner returns (MilestoneId) {
    93	        MilestoneId milestoneId = nextMilestoneId;
    94	        nextMilestoneId = MilestoneId.wrap(MilestoneId.unwrap(nextMilestoneId) + 1);
    95	        milestones[milestoneId] = MilestoneStatus.Pending; // To be explicit
    96	
    97	        emit MilestoneAdded(milestoneId);
    98	        return milestoneId;
    99	    }
   100	
   101	    function setMilestoneStatus(MilestoneId _milestoneId, MilestoneStatus _status)
   102	        external
   103	        override(IRegistry)
   104	        onlyOwner
   105	    {
   106	        require(getMilestoneStatus(_milestoneId) == MilestoneStatus.Pending, InvalidMilestoneStatus(_milestoneId));
   107	        require(_status != MilestoneStatus.Pending, InvalidMilestoneStatus(_milestoneId));
   108	        milestones[_milestoneId] = _status;
   109	
   110	        emit MilestoneStatusUpdated(_milestoneId, _status);
   111	    }
   112	
   113	    /**
   114	     * @notice  Register a new staker implementation
   115	     *
   116	     * @dev Only callable by the owner
   117	     *
   118	     * @param _implementation   The address of the staker implementation
   119	     */
   120	    function registerStakerImplementation(address _implementation) external override(IRegistry) onlyOwner {
   121	        require(
   122	            UUPSUpgradeable(_implementation).proxiableUUID() == ERC1967Utils.IMPLEMENTATION_SLOT,
   123	            InvalidStakerImplementation(_implementation)
   124	        );
   125	
   126	        StakerVersion version = nextStakerVersion;
   127	        nextStakerVersion = StakerVersion.wrap(StakerVersion.unwrap(nextStakerVersion) + 1);
   128	        stakerImplementations[version] = _implementation;
   129	
   130	        emit StakerRegistered(version, _implementation);
   131	    }
   132	
   133	    /**
   134	     * @notice  Set the revoker address
   135	     *
   136	     * @dev Only callable by the owner
   137	     *
   138	     * @param _revoker   The address of the revoker
   139	     */
   140	    function setRevoker(address _revoker) external override(IRegistry) onlyOwner {
   141	        revoker = _revoker;
   142	        emit UpdatedRevoker(_revoker);
   143	    }
   144	
   145	    function setRevokerOperator(address _revokerOperator) external override(IRegistry) onlyOwner {
   146	        revokerOperator = _revokerOperator;
   147	        emit UpdatedRevokerOperator(_revokerOperator);
   148	    }
   149	
   150	    /**
   151	     * @notice  Set the execute allowed at timestamp
   152	     *          Can only be decreased to avoid unintentional updates and give some guarantees to LATP beneficiaries
   153	     *
   154	     * @dev Only callable by the owner
   155	     *
   156	     * @param _executeAllowedAt   The timestamp of when the execute is allowed
   157	     */
   158	    function setExecuteAllowedAt(uint256 _executeAllowedAt) external override(IRegistry) onlyOwner {
   159	        require(_executeAllowedAt < executeAllowedAt, InvalidExecuteAllowedAt(_executeAllowedAt, executeAllowedAt));
   160	        executeAllowedAt = _executeAllowedAt;
   161	        emit UpdatedExecuteAllowedAt(_executeAllowedAt);
   162	    }
   163	
   164	    /**
   165	     * @notice  Set the unlock start time
   166	     *          Can only be decreased to avoid unintentional updates and give some guarantees to LATP beneficiaries
   167	     *
   168	     * @dev Only callable by the owner
   169	     *
   170	     * @param _unlockStartTime   The timestamp of when the unlock starts
   171	     */
   172	    function setUnlockStartTime(uint256 _unlockStartTime) external override(IRegistry) onlyOwner {
   173	        require(_unlockStartTime < unlockStartTime, InvalidUnlockStartTime(_unlockStartTime, unlockStartTime));
   174	        unlockStartTime = _unlockStartTime;
   175	        emit UpdatedUnlockStartTime(_unlockStartTime);
   176	    }
   177	
   178	    /**
   179	     * @notice  Get the revoker address
   180	     *
   181	     * @return  The address of the revoker
   182	     */
   183	    function getRevoker() external view override(IRegistry) returns (address) {
   184	        return revoker;
   185	    }
   186	
   187	    function getRevokerOperator() external view override(IRegistry) returns (address) {
   188	        return revokerOperator;
   189	    }
   190	
   191	    /**
   192	     * @notice  Get the execute allowed at timestamp
   193	     *
   194	     * @return  The timestamp of when the execute is allowed
   195	     */
   196	    function getExecuteAllowedAt() external view override(IRegistry) returns (uint256) {
   197	        return executeAllowedAt;
   198	    }
   199	
   200	    /**
   201	     * @notice  Get the unlock start time
   202	     *
   203	     * @return  The timestamp of when the unlock starts
   204	     */
   205	    function getUnlockStartTime() external view override(IRegistry) returns (uint256) {
   206	        return unlockStartTime;
   207	    }
   208	
   209	    /**
   210	     * @notice  Get the lock params for the global unlocking schedule
   211	     *
   212	     * @return  The global lock params
   213	     */
   214	    function getGlobalLockParams() external view override(IRegistry) returns (LockParams memory) {
   215	        return LockParams({
   216	            startTime: unlockStartTime, cliffDuration: UNLOCK_CLIFF_DURATION, lockDuration: UNLOCK_LOCK_DURATION
   217	        });
   218	    }
   219	
   220	    /**
   221	     * @notice  Get the implementation for a given staker version
   222	     *
   223	     * @param   _version   The version of the staker
   224	     *
   225	     * @return  The implementation for the given staker version
   226	     */
   227	    function getStakerImplementation(StakerVersion _version) external view override(IRegistry) returns (address) {
   228	        require(StakerVersion.unwrap(_version) < StakerVersion.unwrap(nextStakerVersion), UnRegisteredStaker(_version));
   229	        return stakerImplementations[_version];
   230	    }
   231	
   232	    /**
   233	     * @notice  Get the next staker version
   234	     *
   235	     * @return  The next staker version
   236	     */
   237	    function getNextStakerVersion() external view override(IRegistry) returns (StakerVersion) {
   238	        return nextStakerVersion;
   239	    }
   240	
   241	    function getNextMilestoneId() external view override(IRegistry) returns (MilestoneId) {
   242	        return nextMilestoneId;
   243	    }
   244	
   245	    function getMilestoneStatus(MilestoneId _milestoneId) public view override(IRegistry) returns (MilestoneStatus) {
   246	        require(
   247	            MilestoneId.unwrap(_milestoneId) < MilestoneId.unwrap(nextMilestoneId), InvalidMilestoneId(_milestoneId)
   248	        );
   249	        return milestones[_milestoneId];
   250	    }
   251	}
```

## src/token-vaults/atps/base/

### src/token-vaults/atps/base/IATP.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     5	import {Lock} from "../../libraries/LockLib.sol";
     6	import {IRegistry, StakerVersion} from "../../Registry.sol";
     7	import {IBaseStaker} from "./../../staker/BaseStaker.sol";
     8	
     9	enum ATPType {
    10	    Linear,
    11	    Milestone,
    12	    NonClaim
    13	}
    14	
    15	interface IATPCore {
    16	    event StakerInitialized(IBaseStaker staker);
    17	    event StakerUpgraded(StakerVersion version);
    18	    event StakerOperatorUpdated(address operator);
    19	    event Claimed(uint256 amount);
    20	    event ApprovedStaker(uint256 allowance);
    21	    event Rescued(address asset, address to, uint256 amount);
    22	    event Revoked(uint256 amount);
    23	
    24	    error AlreadyInitialized();
    25	    error InvalidBeneficiary(address beneficiary);
    26	    error NotBeneficiary(address caller, address beneficiary);
    27	    error LockHasEnded();
    28	    error InvalidTokenAddress(address token);
    29	    error InvalidRegistry(address registry);
    30	    error AllocationMustBeGreaterThanZero();
    31	    error InvalidAsset(address asset);
    32	    error ExecutionNotAllowedYet(uint256 timestamp, uint256 executeAllowedAt);
    33	    error NotRevokable();
    34	    error NotRevoker(address caller, address revoker);
    35	    error NoClaimable();
    36	    error LockDurationMustBeGTZero(string variant);
    37	    error InvalidUpgrade();
    38	
    39	    function upgradeStaker(StakerVersion _version) external;
    40	    function approveStaker(uint256 _allowance) external;
    41	    function updateStakerOperator(address _operator) external;
    42	    function claim() external returns (uint256);
    43	    function rescueFunds(address _asset, address _to) external;
    44	    function revoke() external returns (uint256);
    45	    function getClaimable() external view returns (uint256);
    46	    function getGlobalLock() external view returns (Lock memory);
    47	    function getBeneficiary() external view returns (address);
    48	    function getOperator() external view returns (address);
    49	}
    50	
    51	interface IATPPeriphery {
    52	    function getToken() external view returns (IERC20);
    53	    function getRegistry() external view returns (IRegistry);
    54	    function getExecuteAllowedAt() external view returns (uint256);
    55	
    56	    function getClaimed() external view returns (uint256);
    57	    function getRevoker() external view returns (address);
    58	    function getIsRevokable() external view returns (bool);
    59	    function getAllocation() external view returns (uint256);
    60	
    61	    function getType() external view returns (ATPType);
    62	    function getStaker() external view returns (IBaseStaker);
    63	}
```

## src/token-vaults/atps/linear/

### src/token-vaults/atps/linear/ILATP.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {Lock, LockParams} from "./../../libraries/LockLib.sol";
     5	import {IATPCore, IATPPeriphery} from "./../base/IATP.sol";
     6	
     7	struct LATPStorage {
     8	    uint32 accumulationStartTime;
     9	    uint32 accumulationCliffDuration;
    10	    uint32 accumulationLockDuration;
    11	    bool isRevokable;
    12	    address revokeBeneficiary;
    13	}
    14	
    15	struct RevokableParams {
    16	    address revokeBeneficiary;
    17	    LockParams lockParams;
    18	}
    19	
    20	interface ILATPCore is IATPCore {
    21	    error InsufficientStakeable(uint256 stakeable, uint256 allowance);
    22	    error LockParamsMustBeEmpty();
    23	
    24	    function initialize(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams) external;
    25	
    26	    function getAccumulationLock() external view returns (Lock memory);
    27	    function getRevokableAmount() external view returns (uint256);
    28	    function getStakeableAmount() external view returns (uint256);
    29	}
    30	
    31	interface ILATPPeriphery is IATPPeriphery {
    32	    function getStore() external view returns (LATPStorage memory);
    33	    function getRevokeBeneficiary() external view returns (address);
    34	}
    35	
    36	interface ILATP is ILATPCore, ILATPPeriphery {}
```

### src/token-vaults/atps/linear/LATP.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {ATPType} from "./../base/IATP.sol";
     5	import {ILATP, ILATPPeriphery, IATPPeriphery, LATPStorage} from "./ILATP.sol";
     6	import {LATPCore, IERC20, IRegistry, IBaseStaker} from "./LATPCore.sol";
     7	
     8	/**
     9	 * @title   Linear Aztec Token Position
    10	 * @notice  Linear Aztec Token Position with additional helper view functions
    11	 *          This is a helper contract to make it easier to use the LATP contract
    12	 *          Will not include any state mutating extensions, just easier access to the data
    13	 *          I might be kinda strange doing this, but I just find it simpler when looking at the state mutating
    14	 *          functions, as I don't need to skip functions etc.
    15	 *
    16	 *          It is also a neat way to make sure that all of the getters follow a similar pattern, as we like using
    17	 *          different naming conventions for different types of data, e.g., constant vs mutable.
    18	 */
    19	contract LATP is ILATP, LATPCore {
    20	    constructor(IRegistry _registry, IERC20 _token) LATPCore(_registry, _token) {}
    21	
    22	    function getToken() external view override(IATPPeriphery) returns (IERC20) {
    23	        return TOKEN;
    24	    }
    25	
    26	    function getRegistry() external view override(IATPPeriphery) returns (IRegistry) {
    27	        return REGISTRY;
    28	    }
    29	
    30	    function getStaker() external view override(IATPPeriphery) returns (IBaseStaker) {
    31	        return staker;
    32	    }
    33	
    34	    function getExecuteAllowedAt() external view override(IATPPeriphery) returns (uint256) {
    35	        return REGISTRY.getExecuteAllowedAt();
    36	    }
    37	
    38	    function getClaimed() external view override(IATPPeriphery) returns (uint256) {
    39	        return claimed;
    40	    }
    41	
    42	    function getRevoker() external view override(IATPPeriphery) returns (address) {
    43	        return REGISTRY.getRevoker();
    44	    }
    45	
    46	    function getIsRevokable() external view override(IATPPeriphery) returns (bool) {
    47	        return store.isRevokable;
    48	    }
    49	
    50	    function getAllocation() external view override(IATPPeriphery) returns (uint256) {
    51	        return allocation;
    52	    }
    53	
    54	    function getStore() external view override(ILATPPeriphery) returns (LATPStorage memory) {
    55	        return store;
    56	    }
    57	
    58	    function getRevokeBeneficiary() external view override(ILATPPeriphery) returns (address) {
    59	        return store.revokeBeneficiary;
    60	    }
    61	
    62	    function getType() external pure virtual override(IATPPeriphery) returns (ATPType) {
    63	        return ATPType.Linear;
    64	    }
    65	}
```

### src/token-vaults/atps/linear/LATPCore.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";
     5	import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";
     6	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     7	import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
     8	import {Math} from "@oz/utils/math/Math.sol";
     9	import {SafeCast} from "@oz/utils/math/SafeCast.sol";
    10	import {LockParams, Lock, LockLib} from "./../../libraries/LockLib.sol";
    11	import {IRegistry, StakerVersion} from "./../../Registry.sol";
    12	import {IBaseStaker} from "./../../staker/BaseStaker.sol";
    13	import {ILATPCore, IATPCore, LATPStorage, RevokableParams} from "./ILATP.sol";
    14	
    15	/**
    16	 * @title   Linear Aztec Token Position Core
    17	 * @notice  The core logic of the Linear Aztec Token Position
    18	 * @dev     This contract is abstract and cannot be deployed on its own.
    19	 *          It is meant to be inherited by the `LATP` contract.
    20	 *          MUST be deployed using the `ATPFactory` contract.
    21	 */
    22	abstract contract LATPCore is ILATPCore {
    23	    using SafeCast for uint256;
    24	    using SafeERC20 for IERC20;
    25	    using LockLib for Lock;
    26	
    27	    IERC20 internal immutable TOKEN;
    28	    IRegistry internal immutable REGISTRY;
    29	
    30	    uint256 internal allocation;
    31	    address internal beneficiary;
    32	    IBaseStaker internal staker;
    33	    address internal operator;
    34	
    35	    uint256 internal claimed = 0;
    36	
    37	    LATPStorage internal store;
    38	
    39	    /**
    40	     * @dev     The caller must be the beneficiary
    41	     */
    42	    modifier onlyBeneficiary() {
    43	        require(msg.sender == beneficiary, NotBeneficiary(msg.sender, beneficiary));
    44	        _;
    45	    }
    46	
    47	    /**
    48	     * @dev     Since we are using the `Clones` library to create the LATP's to use
    49	     *          we can't use the constructor to initialize the individual ones, but
    50	     *          we can use it to initialize values that will be shared across all the clones.
    51	     *
    52	     * @param _registry   The registry
    53	     * @param _token             The token
    54	     */
    55	    constructor(IRegistry _registry, IERC20 _token) {
    56	        require(address(_registry) != address(0), InvalidRegistry(address(_registry)));
    57	        require(address(_token) != address(0), InvalidTokenAddress(address(_token)));
    58	
    59	        TOKEN = _token;
    60	        REGISTRY = _registry;
    61	
    62	        staker = IBaseStaker(address(0xdead));
    63	    }
    64	
    65	    /**
    66	     * @notice  Initialize the Aztec Token Position
    67	     *          Creates a `Staker`, sets the `beneficiary` and `allocation`
    68	     *          If the LATP is revokable, it will set the `accumulation` lock as well
    69	     *
    70	     * @dev     If run twice, the `staker` will already be set and this will revert
    71	     *          with the `AlreadyInitialized` error
    72	     *
    73	     * @dev     When done by the `ATPFactory` this will happen in the same transaction as LATP creation
    74	     *
    75	     * @param _beneficiary              The address of the beneficiary
    76	     * @param _allocation               The amount of tokens to allocate to the LATP
    77	     * @param _revokableParams          The parameters for the accumulation lock and revoke beneficiary, if the LATP is revokable
    78	     */
    79	    function initialize(address _beneficiary, uint256 _allocation, RevokableParams memory _revokableParams)
    80	        external
    81	        override(ILATPCore)
    82	    {
    83	        require(address(staker) == address(0), AlreadyInitialized());
    84	        require(_beneficiary != address(0), InvalidBeneficiary(address(0)));
    85	        require(_allocation > 0, AllocationMustBeGreaterThanZero());
    86	
    87	        beneficiary = _beneficiary;
    88	        allocation = _allocation;
    89	
    90	        staker = createStaker();
    91	
    92	        if (_revokableParams.revokeBeneficiary != address(0)) {
    93	            LockLib.assertValid(_revokableParams.lockParams);
    94	
    95	            store = LATPStorage({
    96	                isRevokable: true,
    97	                accumulationStartTime: _revokableParams.lockParams.startTime.toUint32(),
    98	                accumulationCliffDuration: _revokableParams.lockParams.cliffDuration.toUint32(),
    99	                accumulationLockDuration: _revokableParams.lockParams.lockDuration.toUint32(),
   100	                revokeBeneficiary: _revokableParams.revokeBeneficiary
   101	            });
   102	        } else {
   103	            // If the LATP is non-revokable, the store will be all 0, so we do not need to set storage
   104	            // We will however check that the lock params are empty, to reduce potential for confusion
   105	            require(LockLib.isEmpty(_revokableParams.lockParams), LockParamsMustBeEmpty());
   106	        }
   107	    }
   108	
   109	    /**
   110	     * @notice  Upgrade the staker contract to a new version
   111	     *
   112	     * @param _version The version of the staker to upgrade to
   113	     */
   114	    function upgradeStaker(StakerVersion _version) external override(IATPCore) onlyBeneficiary {
   115	        address impl = REGISTRY.getStakerImplementation(_version);
   116	        UUPSUpgradeable(address(staker)).upgradeToAndCall(impl, "");
   117	
   118	        require(staker.getATP() == address(this), InvalidUpgrade());
   119	
   120	        emit StakerUpgraded(_version);
   121	    }
   122	
   123	    /**
   124	     * @notice  Update the operator of the staker contract
   125	     *
   126	     * @param _operator The address of the new operator
   127	     */
   128	    function updateStakerOperator(address _operator) external override(IATPCore) onlyBeneficiary {
   129	        operator = _operator;
   130	        emit StakerOperatorUpdated(_operator);
   131	    }
   132	
   133	    /**
   134	     * @notice  Cancel the accumulation of assets
   135	     *
   136	     * @return  The amount of tokens revoked
   137	     */
   138	    function revoke() external override(IATPCore) returns (uint256) {
   139	        require(store.isRevokable, NotRevokable());
   140	
   141	        address revoker = REGISTRY.getRevoker();
   142	        require(msg.sender == revoker, NotRevoker(msg.sender, revoker));
   143	
   144	        Lock memory accumulationLock = getAccumulationLock();
   145	        require(!accumulationLock.hasEnded(block.timestamp), LockHasEnded());
   146	
   147	        uint256 debt = getRevokableAmount();
   148	
   149	        store.isRevokable = false;
   150	
   151	        TOKEN.safeTransfer(store.revokeBeneficiary, debt);
   152	
   153	        emit Revoked(debt);
   154	        return debt;
   155	    }
   156	
   157	    /**
   158	     * @notice  Rescue funds that have been sent to the contract by mistake
   159	     *          Allows the beneficiary to transfer funds that are not unlock token from the contract.
   160	     *
   161	     * @param _asset  The asset to rescue
   162	     * @param _to     The address to send the assets to
   163	     */
   164	    function rescueFunds(address _asset, address _to) external override(IATPCore) onlyBeneficiary {
   165	        require(_asset != address(TOKEN), InvalidAsset(_asset));
   166	        IERC20 asset = IERC20(_asset);
   167	        uint256 amount = asset.balanceOf(address(this));
   168	        asset.safeTransfer(_to, amount);
   169	
   170	        emit Rescued(_asset, _to, amount);
   171	    }
   172	
   173	    /**
   174	     * @notice  Authorizes the staker contract for the specified amount.
   175	     *
   176	     * @param _allowance The amount of tokens to authorize the staker contract for
   177	     */
   178	    function approveStaker(uint256 _allowance) external override(IATPCore) onlyBeneficiary {
   179	        // slither-disable-start block-timestamp
   180	        // As we are not relying on block.timestamp for randomness but merely for when we will toggle
   181	        // the EXECUTE_ALLOWED_AT flag, and time will only ever increase, we can safely ignore the warning.
   182	        uint256 executeAllowedAt = REGISTRY.getExecuteAllowedAt();
   183	        require(block.timestamp >= executeAllowedAt, ExecutionNotAllowedYet(block.timestamp, executeAllowedAt));
   184	        // slither-disable-end block-timestamp
   185	
   186	        uint256 stakeable = getStakeableAmount();
   187	        require(stakeable >= _allowance, InsufficientStakeable(stakeable, _allowance));
   188	
   189	        TOKEN.approve(address(staker), _allowance);
   190	
   191	        emit ApprovedStaker(_allowance);
   192	    }
   193	
   194	    /**
   195	     * @notice  Claim the amount of tokens that are available for the owner to claim.
   196	     *
   197	     * @dev     The `caller` must be the `beneficiary`
   198	     *
   199	     * @return  The amount of tokens claimed
   200	     */
   201	    function claim() external virtual override(IATPCore) onlyBeneficiary returns (uint256) {
   202	        uint256 amount = getClaimable();
   203	        require(amount > 0, NoClaimable());
   204	
   205	        claimed += amount;
   206	
   207	        TOKEN.safeTransfer(msg.sender, amount);
   208	
   209	        // @note After the transfer, we need to ensure that the allowance is not too high.
   210	        // Namely, if the allowance is larger than the stakeable amount it should be reduced.
   211	        uint256 stakeable = getStakeableAmount();
   212	        uint256 allowance = TOKEN.allowance(address(this), address(staker));
   213	        if (stakeable < allowance) {
   214	            TOKEN.approve(address(staker), stakeable);
   215	        }
   216	
   217	        emit Claimed(amount);
   218	        return amount;
   219	    }
   220	
   221	    function getOperator() public view override(IATPCore) returns (address) {
   222	        return operator;
   223	    }
   224	
   225	    function getBeneficiary() public view override(IATPCore) returns (address) {
   226	        return beneficiary;
   227	    }
   228	
   229	    /**
   230	     * @notice Compute the amount of tokens that can be claimed.
   231	     *
   232	     * @return  The amount of tokens that can be claimed
   233	     */
   234	    function getClaimable() public view override(IATPCore) returns (uint256) {
   235	        Lock memory globalLock = getGlobalLock();
   236	        uint256 unlocked = globalLock.hasEnded(block.timestamp)
   237	            ? type(uint256).max
   238	            : (globalLock.unlockedAt(block.timestamp) - claimed);
   239	
   240	        return Math.min(TOKEN.balanceOf(address(this)) - getRevokableAmount(), unlocked);
   241	    }
   242	
   243	    /**
   244	     * @notice  Get the global unlock schedule lock
   245	     *
   246	     * @return  The global lock
   247	     */
   248	    function getGlobalLock() public view override(IATPCore) returns (Lock memory) {
   249	        return LockLib.createLock(REGISTRY.getGlobalLockParams(), allocation);
   250	    }
   251	
   252	    /**
   253	     * @notice  Get the accumulation lock
   254	     *
   255	     * @return  The accumulation lock or empty if not revokable
   256	     */
   257	    function getAccumulationLock() public view override(ILATPCore) returns (Lock memory) {
   258	        require(store.isRevokable, NotRevokable());
   259	        return LockLib.createLock(
   260	            LockParams({
   261	                startTime: store.accumulationStartTime,
   262	                cliffDuration: store.accumulationCliffDuration,
   263	                lockDuration: store.accumulationLockDuration
   264	            }),
   265	            allocation
   266	        );
   267	    }
   268	
   269	    /**
   270	     * @notice  Get the amount of tokens that can be revoked
   271	     *
   272	     * @return  The amount of tokens that can be revoked
   273	     */
   274	    function getRevokableAmount() public view override(ILATPCore) returns (uint256) {
   275	        if (!store.isRevokable) {
   276	            return 0;
   277	        }
   278	        return allocation - getAccumulationLock().unlockedAt(block.timestamp);
   279	    }
   280	
   281	    /**
   282	     * @notice  Get the amount of tokens that can be staked
   283	     *
   284	     * @return  The amount of tokens that can be staked
   285	     */
   286	    function getStakeableAmount() public view override(ILATPCore) returns (uint256) {
   287	        if (!store.isRevokable) {
   288	            return type(uint256).max;
   289	        }
   290	        return TOKEN.balanceOf(address(this)) - getRevokableAmount();
   291	    }
   292	
   293	    /**
   294	     * @notice  Create a new staker contract with the `ERC1967Proxy`
   295	     *          the initial implementation used will the be `BaseStaker`
   296	     *
   297	     * @return  The new staker contract
   298	     */
   299	    function createStaker() private returns (IBaseStaker) {
   300	        address impl = REGISTRY.getStakerImplementation(StakerVersion.wrap(0));
   301	        ERC1967Proxy proxy = new ERC1967Proxy(impl, abi.encodeCall(IBaseStaker.initialize, address(this)));
   302	        IBaseStaker _staker = IBaseStaker(address(proxy));
   303	        emit StakerInitialized(_staker);
   304	        return _staker;
   305	    }
   306	}
```

## src/token-vaults/atps/milestone/

### src/token-vaults/atps/milestone/IMATP.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {MilestoneId} from "./../../Registry.sol";
     5	
     6	import {IATPCore, IATPPeriphery} from "./../base/IATP.sol";
     7	
     8	interface IMATPCore is IATPCore {
     9	    error RevokedOrFailed();
    10	
    11	    function initialize(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId) external;
    12	}
    13	
    14	interface IMATPPeriphery is IATPPeriphery {
    15	    function getMilestoneId() external view returns (MilestoneId);
    16	    function getIsRevoked() external view returns (bool);
    17	}
    18	
    19	interface IMATP is IMATPCore, IMATPPeriphery {}
```

### src/token-vaults/atps/milestone/MATP.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {ATPType} from "./../base/IATP.sol";
     5	import {IMATP, IMATPPeriphery, IATPPeriphery} from "./IMATP.sol";
     6	import {MATPCore, MilestoneId, IRegistry, IERC20, IBaseStaker} from "./MATPCore.sol";
     7	
     8	contract MATP is IMATP, MATPCore {
     9	    constructor(IRegistry _registry, IERC20 _token) MATPCore(_registry, _token) {}
    10	
    11	    function getToken() external view override(IATPPeriphery) returns (IERC20) {
    12	        return TOKEN;
    13	    }
    14	
    15	    function getRegistry() external view override(IATPPeriphery) returns (IRegistry) {
    16	        return REGISTRY;
    17	    }
    18	
    19	    function getStaker() external view override(IATPPeriphery) returns (IBaseStaker) {
    20	        return staker;
    21	    }
    22	
    23	    function getExecuteAllowedAt() external view override(IATPPeriphery) returns (uint256) {
    24	        return REGISTRY.getExecuteAllowedAt();
    25	    }
    26	
    27	    function getClaimed() external view override(IATPPeriphery) returns (uint256) {
    28	        return claimed;
    29	    }
    30	
    31	    function getRevoker() external view override(IATPPeriphery) returns (address) {
    32	        return REGISTRY.getRevoker();
    33	    }
    34	
    35	    function getIsRevokable() external view override(IATPPeriphery) returns (bool) {
    36	        return !isRevoked;
    37	    }
    38	
    39	    function getAllocation() external view override(IATPPeriphery) returns (uint256) {
    40	        return allocation;
    41	    }
    42	
    43	    function getMilestoneId() external view override(IMATPPeriphery) returns (MilestoneId) {
    44	        return milestoneId;
    45	    }
    46	
    47	    function getIsRevoked() external view override(IMATPPeriphery) returns (bool) {
    48	        return isRevoked;
    49	    }
    50	
    51	    function getType() external pure override(IATPPeriphery) returns (ATPType) {
    52	        return ATPType.Milestone;
    53	    }
    54	}
```

### src/token-vaults/atps/milestone/MATPCore.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";
     5	import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";
     6	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     7	import {SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";
     8	import {Math} from "@oz/utils/math/Math.sol";
     9	import {SafeCast} from "@oz/utils/math/SafeCast.sol";
    10	import {Lock, LockLib} from "./../../libraries/LockLib.sol";
    11	import {IRegistry, StakerVersion, MilestoneId, MilestoneStatus} from "./../../Registry.sol";
    12	import {IBaseStaker} from "./../../staker/BaseStaker.sol";
    13	import {IMATPCore, IATPCore} from "./IMATP.sol";
    14	
    15	/**
    16	 * @title   Milestone Aztec Token Position Core
    17	 * @notice  The core logic of the Milestone Aztec Token Position
    18	 * @dev     This contract is abstract and cannot be deployed on its own.
    19	 *          It is meant to be inherited by the `MATP` contract.
    20	 *          MUST be deployed using the `ATPFactory` contract.
    21	 */
    22	abstract contract MATPCore is IMATPCore {
    23	    using SafeCast for uint256;
    24	    using SafeERC20 for IERC20;
    25	    using LockLib for Lock;
    26	
    27	    IERC20 internal immutable TOKEN;
    28	    IRegistry internal immutable REGISTRY;
    29	
    30	    uint256 internal allocation;
    31	
    32	    // 160 + 96 = 256
    33	    address internal beneficiary;
    34	    MilestoneId internal milestoneId;
    35	
    36	    IBaseStaker internal staker;
    37	    address internal operator;
    38	
    39	    uint256 internal claimed = 0;
    40	    bool internal isRevoked = false;
    41	
    42	    /**
    43	     * @dev     The caller must be the beneficiary, or if the milestone have failed it must be the revoker
    44	     */
    45	    modifier onlyBeneficiary() {
    46	        address _beneficiary = getBeneficiary();
    47	        require(msg.sender == _beneficiary, NotBeneficiary(msg.sender, _beneficiary));
    48	        _;
    49	    }
    50	
    51	    /**
    52	     * @dev     Since we are using the `Clones` library to create the ATP's to use
    53	     *          we can't use the constructor to initialize the individual ones, but
    54	     *          we can use it to initialize values that will be shared across all the clones.
    55	     *
    56	     * @param _registry   The registry
    57	     * @param _token      The token
    58	     */
    59	    constructor(IRegistry _registry, IERC20 _token) {
    60	        require(address(_registry) != address(0), InvalidRegistry(address(_registry)));
    61	        require(address(_token) != address(0), InvalidTokenAddress(address(_token)));
    62	
    63	        TOKEN = _token;
    64	        REGISTRY = _registry;
    65	
    66	        staker = IBaseStaker(address(0xdead));
    67	    }
    68	
    69	    /**
    70	     * @notice  Initialize the Aztec Token Position
    71	     *          Creates a `Staker`, sets the `beneficiary` and `allocation`
    72	     *          If the ATP is revokable, it will set the `accumulation` lock as well
    73	     *
    74	     * @dev     If run twice, the `staker` will already be set and this will revert
    75	     *          with the `AlreadyInitialized` error
    76	     *
    77	     * @dev     When done by the `ATPFactory` this will happen in the same transaction as ATP creation
    78	     *
    79	     * @param _beneficiary              The address of the beneficiary
    80	     * @param _allocation               The amount of tokens to allocate to the ATP
    81	     * @param _milestoneId              The milestone id
    82	     */
    83	    function initialize(address _beneficiary, uint256 _allocation, MilestoneId _milestoneId)
    84	        external
    85	        override(IMATPCore)
    86	    {
    87	        require(address(staker) == address(0), AlreadyInitialized());
    88	        require(_beneficiary != address(0), InvalidBeneficiary(address(0)));
    89	        require(_allocation > 0, AllocationMustBeGreaterThanZero());
    90	
    91	        require(
    92	            REGISTRY.getMilestoneStatus(_milestoneId) == MilestoneStatus.Pending,
    93	            IRegistry.InvalidMilestoneStatus(_milestoneId)
    94	        );
    95	
    96	        beneficiary = _beneficiary;
    97	        milestoneId = _milestoneId;
    98	        allocation = _allocation;
    99	        staker = createStaker();
   100	    }
   101	
   102	    /**
   103	     * @notice  Upgrade the staker contract to a new version
   104	     *
   105	     * @param _version The version of the staker to upgrade to
   106	     */
   107	    function upgradeStaker(StakerVersion _version) external override(IATPCore) onlyBeneficiary {
   108	        address impl = REGISTRY.getStakerImplementation(_version);
   109	        UUPSUpgradeable(address(staker)).upgradeToAndCall(impl, "");
   110	
   111	        require(staker.getATP() == address(this), InvalidUpgrade());
   112	
   113	        emit StakerUpgraded(_version);
   114	    }
   115	
   116	    /**
   117	     * @notice  Cancel the accumulation of assets
   118	     *
   119	     * @return  The amount of tokens revoked
   120	     */
   121	    function revoke() external override(IATPCore) returns (uint256) {
   122	        require(!isRevoked, NotRevokable());
   123	        require(REGISTRY.getMilestoneStatus(milestoneId) == MilestoneStatus.Pending, NotRevokable());
   124	        address revoker = REGISTRY.getRevoker();
   125	        require(msg.sender == revoker, NotRevoker(msg.sender, revoker));
   126	
   127	        isRevoked = true;
   128	
   129	        emit Revoked(allocation);
   130	
   131	        return allocation;
   132	    }
   133	
   134	    /**
   135	     * @notice  Rescue funds that have been sent to the contract by mistake
   136	     *          Allows the beneficiary to transfer funds that are not unlock token from the contract.
   137	     *
   138	     * @param _asset  The asset to rescue
   139	     * @param _to     The address to send the assets to
   140	     */
   141	    function rescueFunds(address _asset, address _to) external override(IATPCore) {
   142	        require(_asset != address(TOKEN), InvalidAsset(_asset));
   143	        require(msg.sender == beneficiary, NotBeneficiary(msg.sender, beneficiary));
   144	        IERC20 asset = IERC20(_asset);
   145	        uint256 amount = asset.balanceOf(address(this));
   146	        asset.safeTransfer(_to, amount);
   147	
   148	        emit Rescued(_asset, _to, amount);
   149	    }
   150	
   151	    /**
   152	     * @notice  Authorizes the staker contract for the specified amount.
   153	     *
   154	     * @param _allowance The amount of tokens to authorize the staker contract for
   155	     */
   156	    function approveStaker(uint256 _allowance) external override(IATPCore) onlyBeneficiary {
   157	        // slither-disable-start block-timestamp
   158	        // As we are not relying on block.timestamp for randomness but merely for when we will toggle
   159	        // the EXECUTE_ALLOWED_AT flag, and time will only ever increase, we can safely ignore the warning.
   160	        uint256 executeAllowedAt = REGISTRY.getExecuteAllowedAt();
   161	        require(block.timestamp >= executeAllowedAt, ExecutionNotAllowedYet(block.timestamp, executeAllowedAt));
   162	        // slither-disable-end block-timestamp
   163	
   164	        TOKEN.approve(address(staker), _allowance);
   165	
   166	        emit ApprovedStaker(_allowance);
   167	    }
   168	
   169	    /**
   170	     * @notice  Claim the amount of tokens that are available for the owner to claim.
   171	     *
   172	     * @dev     The `caller` must be the `beneficiary`
   173	     *
   174	     * @return  The amount of tokens claimed
   175	     */
   176	    function claim() external override(IATPCore) onlyBeneficiary returns (uint256) {
   177	        uint256 amount = getClaimable();
   178	        require(amount > 0, NoClaimable());
   179	
   180	        claimed += amount;
   181	
   182	        TOKEN.safeTransfer(msg.sender, amount);
   183	
   184	        emit Claimed(amount);
   185	        return amount;
   186	    }
   187	
   188	    /**
   189	     * @notice  Update the operator of the staker contract
   190	     *
   191	     * @param _operator The address of the new operator
   192	     */
   193	    function updateStakerOperator(address _operator) public override(IATPCore) onlyBeneficiary {
   194	        require(!isRevoked && REGISTRY.getMilestoneStatus(milestoneId) != MilestoneStatus.Failed, RevokedOrFailed());
   195	
   196	        operator = _operator;
   197	        emit StakerOperatorUpdated(_operator);
   198	    }
   199	
   200	    /**
   201	     * @notice Compute the amount of tokens that can be claimed.
   202	     *
   203	     * @return  The amount of tokens that can be claimed
   204	     */
   205	    function getClaimable() public view override(IATPCore) returns (uint256) {
   206	        MilestoneStatus status = REGISTRY.getMilestoneStatus(milestoneId);
   207	        if (isRevoked || status == MilestoneStatus.Failed) {
   208	            // When revoked or milestone failed, the lock is ignored as it is the revoker
   209	            // claiming, and it should be able to bypass these
   210	            return TOKEN.balanceOf(address(this));
   211	        }
   212	        if (status != MilestoneStatus.Succeeded) {
   213	            return 0;
   214	        }
   215	
   216	        Lock memory globalLock = getGlobalLock();
   217	        uint256 unlocked = globalLock.hasEnded(block.timestamp)
   218	            ? type(uint256).max
   219	            : (globalLock.unlockedAt(block.timestamp) - claimed);
   220	
   221	        return Math.min(TOKEN.balanceOf(address(this)), unlocked);
   222	    }
   223	
   224	    /**
   225	     * @notice  Get the global unlock schedule lock
   226	     *
   227	     * @return  The global lock
   228	     */
   229	    function getGlobalLock() public view override(IATPCore) returns (Lock memory) {
   230	        return LockLib.createLock(REGISTRY.getGlobalLockParams(), allocation);
   231	    }
   232	
   233	    /**
   234	     * @notice  Get the beneficiary of the ATP
   235	     *          If the milestone has failed or ATP was revoked, the beneficiary is the revoker
   236	     *
   237	     * @return  The beneficiary
   238	     */
   239	    function getBeneficiary() public view override(IATPCore) returns (address) {
   240	        if (isRevoked || REGISTRY.getMilestoneStatus(milestoneId) == MilestoneStatus.Failed) {
   241	            return REGISTRY.getRevoker();
   242	        }
   243	        return beneficiary;
   244	    }
   245	
   246	    /**
   247	     * @notice  Get the operator of the staker contract
   248	     *          If the milestone has failed or ATP was revoked, the operator is the revoker operator
   249	     *
   250	     * @return  The operator
   251	     */
   252	    function getOperator() public view override(IATPCore) returns (address) {
   253	        if (isRevoked || REGISTRY.getMilestoneStatus(milestoneId) == MilestoneStatus.Failed) {
   254	            return REGISTRY.getRevokerOperator();
   255	        }
   256	        return operator;
   257	    }
   258	
   259	    /**
   260	     * @notice  Create a new staker contract with the `ERC1967Proxy`
   261	     *          the initial implementation used will the be `BaseStaker`
   262	     *
   263	     * @return  The new staker contract
   264	     */
   265	    function createStaker() private returns (IBaseStaker) {
   266	        address impl = REGISTRY.getStakerImplementation(StakerVersion.wrap(0));
   267	        ERC1967Proxy proxy = new ERC1967Proxy(impl, abi.encodeCall(IBaseStaker.initialize, address(this)));
   268	        IBaseStaker _staker = IBaseStaker(address(proxy));
   269	        emit StakerInitialized(_staker);
   270	        return _staker;
   271	    }
   272	}
```

## src/token-vaults/atps/noclaim/

### src/token-vaults/atps/noclaim/INCATP.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {LockParams} from "./../../libraries/LockLib.sol";
     5	import {IATPPeriphery} from "./../base/IATP.sol";
     6	
     7	import {ILATPCore} from "./../linear/ILATP.sol";
     8	
     9	struct NCATPStorage {
    10	    uint32 accumulationStartTime;
    11	    uint32 accumulationCliffDuration;
    12	    uint32 accumulationLockDuration;
    13	    bool isRevokable;
    14	    address revokeBeneficiary;
    15	}
    16	
    17	struct RevokableParams {
    18	    address revokeBeneficiary;
    19	    LockParams lockParams;
    20	}
    21	
    22	interface INCATPCore is ILATPCore {}
    23	
    24	interface INCATPPeriphery is IATPPeriphery {
    25	    function getStore() external view returns (NCATPStorage memory);
    26	    function getRevokeBeneficiary() external view returns (address);
    27	}
    28	
    29	interface INCATP is INCATPCore, INCATPPeriphery {}
```

### src/token-vaults/atps/noclaim/NCATP.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {ATPType, IATPCore} from "./../base/IATP.sol";
     5	import {LATP} from "./../linear/LATP.sol";
     6	import {LATPCore, IERC20, IRegistry} from "./../linear/LATPCore.sol";
     7	
     8	/**
     9	 * @title   Non Claimable Linear Aztec Position
    10	 * @notice  An override of the LATP contract to make it non-claimable.
    11	 */
    12	contract NCATP is LATP {
    13	
    14	    constructor(IRegistry _registry, IERC20 _token) LATP(_registry, _token) {}
    15	
    16	    function claim() external override(IATPCore, LATPCore) onlyBeneficiary returns (uint256) {
    17	        revert NoClaimable();
    18	    }
    19	
    20	    function getType() external pure override(LATP) returns (ATPType) {
    21	        return ATPType.NonClaim;
    22	    }
    23	}
```

## src/token-vaults/deployment-factories/

### src/token-vaults/deployment-factories/LATPFactory.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {IRegistry} from "../Registry.sol";
     5	import {LATP} from "../atps/linear/LATP.sol";
     6	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     7	
     8	library LATPFactory {
     9	    /**
    10	     * @notice Deploy the LATP implementation
    11	     * @param _registry The registry
    12	     * @param _token The token
    13	     * @return The LATP implementation
    14	     */
    15	    function deployImplementation(IRegistry _registry, IERC20 _token) external returns (LATP) {
    16	        return new LATP(_registry, _token);
    17	    }
    18	}
```

### src/token-vaults/deployment-factories/MATPFactory.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {IRegistry} from "../Registry.sol";
     5	import {MATP} from "../atps/milestone/MATP.sol";
     6	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     7	
     8	library MATPFactory {
     9	    /**
    10	     * @notice Deploy the MATP implementation
    11	     * @param _registry The registry
    12	     * @param _token The token
    13	     * @return The MATP implementation
    14	     */
    15	    function deployImplementation(IRegistry _registry, IERC20 _token) external returns (MATP) {
    16	        return new MATP(_registry, _token);
    17	    }
    18	}
```

### src/token-vaults/deployment-factories/NCATPFactory.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {IRegistry} from "../Registry.sol";
     5	import {NCATP} from "../atps/noclaim/NCATP.sol";
     6	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
     7	
     8	library NCATPFactory {
     9	    /**
    10	     * @notice Deploy the NCATP implementation
    11	     * @param _registry The registry
    12	     * @param _token The token
    13	     * @return The NCATP implementation
    14	     */
    15	    function deployImplementation(IRegistry _registry, IERC20 _token) external returns (NCATP) {
    16	        return new NCATP(_registry, _token);
    17	    }
    18	}
```

## src/token-vaults/libraries/

### src/token-vaults/libraries/LockLib.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	/**
     5	 * @notice  The parameters for a lock
     6	 *          The parameters used to derive the actual lock.
     7	 *
     8	 * @param   startTime The timestamp that the lock starts at (0 before this value)
     9	 * @param   cliffDuration Time until the cliff is reached
    10	 * @param   lockDuration Time until the lock is fully unlocked
    11	 */
    12	struct LockParams {
    13	    uint256 startTime;
    14	    uint256 cliffDuration;
    15	    uint256 lockDuration;
    16	}
    17	
    18	/**
    19	 * @notice  The lock struct
    20	 * @param   startTime The timestamp that the lock starts at (0 before this value)
    21	 * @param   cliff The timestamp of the cliff of the lock (0 before this value, >= startTime)
    22	 * @param   endTime The timestamp that the lock ends at, >= cliff
    23	 * @param   allocation The amount of tokens that are locked
    24	 */
    25	struct Lock {
    26	    uint256 startTime;
    27	    uint256 cliff;
    28	    uint256 endTime;
    29	    uint256 allocation;
    30	}
    31	
    32	/**
    33	 * @title   LockLib
    34	 * @notice  Library for handling "locks" on assets
    35	 *          A lock is in this case, a curve defining the amount available at any given timestamp.
    36	 *          The particular lock is a linear curve with a cliff.
    37	 */
    38	library LockLib {
    39	    error LockDurationMustBeGTZero();
    40	    error LockDurationMustBeGECliffDuration(uint256 lockDuration, uint256 cliffDuration);
    41	
    42	    /**
    43	     * @notice  Check if the lock has ended
    44	     *
    45	     * @param _lock   The lock
    46	     * @param _timestamp   The timestamp to check
    47	     *
    48	     * @return  True if the lock has ended
    49	     */
    50	    function hasEnded(Lock memory _lock, uint256 _timestamp) internal pure returns (bool) {
    51	        return _timestamp >= _lock.endTime;
    52	    }
    53	
    54	    /**
    55	     * @notice  Get the unlocked value of the lock at a given timestamp
    56	     *
    57	     * @param _lock   The lock
    58	     * @param _timestamp   The timestamp to get the value at
    59	     *
    60	     * @return  The unlocked value at the given timestamp
    61	     */
    62	    function unlockedAt(Lock memory _lock, uint256 _timestamp) internal pure returns (uint256) {
    63	        if (_timestamp < _lock.cliff) {
    64	            return 0;
    65	        }
    66	
    67	        if (_timestamp >= _lock.endTime) {
    68	            return _lock.allocation;
    69	        }
    70	
    71	        return (_lock.allocation * (_timestamp - _lock.startTime)) / (_lock.endTime - _lock.startTime);
    72	    }
    73	
    74	    /**
    75	     * @notice  Create a lock
    76	     *
    77	     * @dev     The caller should make sure that `_allocation` is not zero
    78	     *
    79	     * @param _params   The lock params
    80	     * @param _allocation   The allocation of the lock
    81	     *
    82	     * @return  The lock
    83	     */
    84	    function createLock(LockParams memory _params, uint256 _allocation) internal pure returns (Lock memory) {
    85	        LockLib.assertValid(_params);
    86	        return Lock({
    87	            startTime: _params.startTime,
    88	            cliff: _params.startTime + _params.cliffDuration,
    89	            endTime: _params.startTime + _params.lockDuration,
    90	            allocation: _allocation
    91	        });
    92	    }
    93	
    94	    /**
    95	     * @notice  Assert that the lock params are valid
    96	     *
    97	     * @param _params   The lock params
    98	     */
    99	    function assertValid(LockParams memory _params) internal pure {
   100	        require(_params.lockDuration > 0, LockDurationMustBeGTZero());
   101	        require(
   102	            _params.lockDuration >= _params.cliffDuration,
   103	            LockDurationMustBeGECliffDuration(_params.lockDuration, _params.cliffDuration)
   104	        );
   105	    }
   106	
   107	    /**
   108	     * @notice  Check if the lock params are empty
   109	     *
   110	     * @param _params   The lock params
   111	     *
   112	     * @return  True if the lock params are empty
   113	     */
   114	    function isEmpty(LockParams memory _params) internal pure returns (bool) {
   115	        return _params.startTime == 0 && _params.cliffDuration == 0 && _params.lockDuration == 0;
   116	    }
   117	
   118	    /**
   119	     * @notice  Get an empty lock params
   120	     *
   121	     * @return  An empty lock params
   122	     */
   123	    function empty() internal pure returns (LockParams memory) {
   124	        return LockParams({startTime: 0, cliffDuration: 0, lockDuration: 0});
   125	    }
   126	}
```

## src/token-vaults/staker/

### src/token-vaults/staker/BaseStaker.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {ERC1967Utils} from "@oz/proxy/ERC1967/ERC1967Utils.sol";
     5	import {UUPSUpgradeable} from "@oz/proxy/utils/UUPSUpgradeable.sol";
     6	import {IATPCore} from "../atps/base/IATP.sol";
     7	
     8	interface IBaseStaker {
     9	    function initialize(address _atp) external;
    10	
    11	    function getATP() external view returns (address);
    12	    function getOperator() external view returns (address);
    13	    function getImplementation() external view returns (address);
    14	}
    15	
    16	contract BaseStaker is IBaseStaker, UUPSUpgradeable {
    17	    address internal atp;
    18	
    19	    error AlreadyInitialized();
    20	    error ZeroATP();
    21	    error NotATP(address caller, address atp);
    22	    error NotOperator(address caller, address operator);
    23	
    24	    modifier onlyOperator() {
    25	        address operator = getOperator();
    26	        require(msg.sender == operator, NotOperator(msg.sender, operator));
    27	        _;
    28	    }
    29	
    30	    modifier onlyATP() {
    31	        require(msg.sender == address(atp), NotATP(msg.sender, address(atp)));
    32	        _;
    33	    }
    34	
    35	    constructor() {
    36	        atp = address(0xdead);
    37	    }
    38	
    39	    function initialize(address _atp) external virtual override(IBaseStaker) {
    40	        require(address(_atp) != address(0), ZeroATP());
    41	        require(address(atp) == address(0), AlreadyInitialized());
    42	
    43	        atp = _atp;
    44	    }
    45	
    46	    function getImplementation() external view virtual override(IBaseStaker) returns (address) {
    47	        return ERC1967Utils.getImplementation();
    48	    }
    49	
    50	    function getATP() public view virtual override(IBaseStaker) returns (address) {
    51	        return atp;
    52	    }
    53	
    54	    function getOperator() public view virtual override(IBaseStaker) returns (address) {
    55	        return IATPCore(atp).getOperator();
    56	    }
    57	
    58	    function _authorizeUpgrade(address _newImplementation) internal virtual override(UUPSUpgradeable) onlyATP {}
    59	}
```

## src/token-vaults/token/

### src/token-vaults/token/Aztec.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	import {Ownable2Step, Ownable} from "@oz/access/Ownable2Step.sol";
     5	import {ERC20} from "@oz/token/ERC20/ERC20.sol";
     6	import {ERC20Permit} from "@oz/token/ERC20/extensions/ERC20Permit.sol";
     7	import {IERC20Mintable} from "./IERC20Mintable.sol";
     8	
     9	contract Aztec is IERC20Mintable, ERC20, Ownable2Step, ERC20Permit {
    10	    constructor(address _initialOwner) ERC20("AZTEC", "AZTEC") Ownable(_initialOwner) ERC20Permit("AZTEC") {}
    11	
    12	    /**
    13	     * @notice  Mint tokens
    14	     *
    15	     * @dev Only callable by the owner
    16	     *
    17	     * @param _to   The address to mint the tokens to
    18	     * @param _amount   The amount of tokens to mint
    19	     */
    20	    function mint(address _to, uint256 _amount) external override(IERC20Mintable) onlyOwner {
    21	        _mint(_to, _amount);
    22	    }
    23	}
```

### src/token-vaults/token/IERC20Mintable.sol
```solidity
     1	// SPDX-License-Identifier: UNLICENSED
     2	pragma solidity ^0.8.27;
     3	
     4	interface IERC20Mintable {
     5	    function mint(address _to, uint256 _amount) external;
     6	}
```

## src/uniswap-periphery/

### src/uniswap-periphery/AuctionHook.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	/* solhint-disable compiler-version */
     3	pragma solidity ^0.8.26;
     4	
     5	import {Ownable} from "@oz/access/Ownable.sol";
     6	import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
     7	import {IValidationHook} from "@twap-auction/interfaces/IValidationHook.sol";
     8	import {IIgnitionParticipantSoulbound} from "src/soulbound/IIgnitionParticipantSoulbound.sol";
     9	
    10	interface IAztecAuctionHook is IValidationHook {
    11	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    12	    /*                        Events                              */
    13	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    14	    event AuctionSet(address indexed auction);
    15	
    16	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    17	    /*                        Errors                              */
    18	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    19	    error AztecAuctionHook__ZeroAddress();
    20	    error AztecAuctionHook__ContributorPeriodEndBlockInPast();
    21	    error AztecAuctionHook__NotAuction();
    22	    error AztecAuctionHook__OwnerMustBeSender();
    23	    error AztecAuctionHook__MaxPurchaseLimitExceeded();
    24	
    25	    error AztecAuctionHook__NotContributor();
    26	    error AztecAuctionHook__NotSoulbound();
    27	
    28	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    29	    /*                    Admin Functions                         */
    30	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    31	    function setAuction(IContinuousClearingAuction _auction) external;
    32	
    33	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    34	    /*                     View Functions                         */
    35	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    36	    function totalPurchased(address _sender) external view returns (uint256);
    37	    function MAX_PURCHASE_LIMIT() external view returns (uint256);
    38	    function CONTRIBUTOR_PERIOD_END_BLOCK() external view returns (uint256);
    39	    function auction() external view returns (IContinuousClearingAuction);
    40	    function SOULBOUND() external view returns (IIgnitionParticipantSoulbound);
    41	}
    42	
    43	contract AztecAuctionHook is IAztecAuctionHook, Ownable {
    44	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    45	    /*                       Constants                            */
    46	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    47	    /// @notice The maximum amount of tokens one user can purchase in the auction
    48	    uint256 public constant MAX_PURCHASE_LIMIT = 250 ether;
    49	
    50	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    51	    /*                      Immutables                            */
    52	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    53	    /// @notice The block at which the contributor period ends; and to which any soulbound holder may bid
    54	    uint256 public immutable CONTRIBUTOR_PERIOD_END_BLOCK;
    55	
    56	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    57	    /*                          State                             */
    58	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    59	    /// @notice The soulbound contract - containing a registry of sanction checks
    60	    IIgnitionParticipantSoulbound public immutable SOULBOUND;
    61	
    62	    /// @notice The auction contract address
    63	    IContinuousClearingAuction public auction;
    64	
    65	    mapping(address sender => uint256 totalPurchased) public totalPurchased;
    66	
    67	    /**
    68	     * @notice Constructor
    69	     * @dev Reverts if the soulbound or auction is the zero address or if the contributor period block end is in the past
    70	     * @dev Sets the soulbound, contributor period block end, and auction
    71	     * @dev Emits an AuctionSet event
    72	     */
    73	    constructor(IIgnitionParticipantSoulbound _soulbound, uint256 _contributorPeriodBlockEnd) Ownable(msg.sender) {
    74	        require(address(_soulbound) != address(0), AztecAuctionHook__ZeroAddress());
    75	        require(_contributorPeriodBlockEnd > block.number, AztecAuctionHook__ContributorPeriodEndBlockInPast());
    76	
    77	        SOULBOUND = _soulbound;
    78	        CONTRIBUTOR_PERIOD_END_BLOCK = _contributorPeriodBlockEnd;
    79	    }
    80	
    81	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    82	    /*                        Functions                           */
    83	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    84	    /**
    85	     * @notice Validate a bid
    86	     * @dev MUST revert if the bid is invalid
    87	     * param maxPrice The maximum price the bidder is willing to pay
    88	     * @param _amount The amount of the bid (in ether)
    89	     * @param _owner The owner of the bid
    90	     * @param _sender The sender of the bid
    91	     * param _hookData Additional data to pass to the hook required for validation
    92	     */
    93	    function validate(uint256, uint128 _amount, address _owner, address _sender, bytes calldata)
    94	        external
    95	        override(IValidationHook)
    96	    {
    97	        require(address(auction) != address(0), AztecAuctionHook__ZeroAddress()); // ContinuousClearingAuction has not been set yet
    98	        require(msg.sender == address(auction), AztecAuctionHook__NotAuction());
    99	
   100	        require(_owner == _sender, AztecAuctionHook__OwnerMustBeSender());
   101	
   102	        // When we are below the contributor period block, the bidder must be a genesis sequencer or contributor
   103	        if (block.number < CONTRIBUTOR_PERIOD_END_BLOCK) {
   104	            require(SOULBOUND.hasGenesisSequencerTokenOrContributorToken(_sender), AztecAuctionHook__NotContributor());
   105	        } else {
   106	            // When we are above the contributor period block, the bidder must have any soulbound token
   107	            require(SOULBOUND.hasAnyToken(_sender), AztecAuctionHook__NotSoulbound());
   108	        }
   109	
   110	        uint256 newPurchasedAmount = totalPurchased[_sender] + _amount;
   111	        totalPurchased[_sender] = newPurchasedAmount;
   112	        require(newPurchasedAmount <= MAX_PURCHASE_LIMIT, AztecAuctionHook__MaxPurchaseLimitExceeded());
   113	    }
   114	
   115	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   116	    /*                    Admin Functions                         */
   117	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   118	
   119	    /**
   120	     * @notice Set the auction
   121	     * @param _auction The new auction address
   122	     * @dev Reverts if the caller is not the owner
   123	     * @dev Emits an AuctionSet event
   124	     */
   125	    function setAuction(IContinuousClearingAuction _auction) external override(IAztecAuctionHook) onlyOwner {
   126	        auction = _auction;
   127	        emit AuctionSet(address(auction));
   128	    }
   129	}
```

### src/uniswap-periphery/GovernanceAcceleratedLock.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {Address} from "@oz/utils/Address.sol";
     5	import {Ownable} from "@oz/access/Ownable.sol";
     6	
     7	interface IGovernanceAcceleratedLock {
     8	    error GovernanceAcceleratedLock__LockTimeNotMet();
     9	    error GovernanceAcceleratedLock__GovernanceAddressCannotBeZero();
    10	
    11	    event LockAccelerated();
    12	    event LockExtended();
    13	
    14	    function lockAccelerated() external view returns (bool);
    15	    function accelerateLock() external;
    16	    function extendLock() external;
    17	    function relay(address _target, bytes calldata _data) external returns (bytes memory);
    18	}
    19	
    20	contract GovernanceAcceleratedLock is Ownable, IGovernanceAcceleratedLock {
    21	    /// @notice The start time of the lock
    22	    uint256 public immutable START_TIME;
    23	
    24	    /// @notice The extended lock time
    25	    uint256 public constant EXTENDED_LOCK_TIME = 365 days;
    26	    /// @notice The shorter lock time
    27	    uint256 public constant SHORTER_LOCK_TIME = 90 days;
    28	
    29	    /// @notice Whether the lock is currently accelerated
    30	    bool public lockAccelerated = false;
    31	
    32	    /**
    33	     * @param _governance The address of the governance contract (Owner)
    34	     * @param _startTime The start time of the lock
    35	     */
    36	    constructor(address _governance, uint256 _startTime) Ownable(_governance) {
    37	        require(_governance != address(0), GovernanceAcceleratedLock__GovernanceAddressCannotBeZero());
    38	        START_TIME = _startTime;
    39	    }
    40	
    41	    /**
    42	     * @notice Accelerate the lock
    43	     * @notice The lock can be decelerated by calling extendLock
    44	     *
    45	     * @dev Only the owner can accelerate the lock
    46	     */
    47	    function accelerateLock() external override(IGovernanceAcceleratedLock) onlyOwner {
    48	        lockAccelerated = true;
    49	        emit LockAccelerated();
    50	    }
    51	
    52	    /**
    53	     * @notice Extend the lock
    54	     * @notice The lock can be accelerated by calling accelerateLock
    55	     *
    56	     * @dev Only the owner can extend the lock
    57	     */
    58	    function extendLock() external override(IGovernanceAcceleratedLock) onlyOwner {
    59	        lockAccelerated = false;
    60	        emit LockExtended();
    61	    }
    62	
    63	    /**
    64	     * @notice Relay a call to a target contract
    65	     * @notice The call will be relayed if the lock is accelerated
    66	     *
    67	     * @dev The relay function CANNOT send native tokens (ETH)
    68	     * @dev Only the owner can relay the call
    69	     * 
    70	     * @param _target The target contract to relay the call to
    71	     * @param _data The data to relay to the target contract
    72	     * @return The result of the call
    73	     */
    74	    function relay(address _target, bytes calldata _data)
    75	        external
    76	        override(IGovernanceAcceleratedLock)
    77	        onlyOwner
    78	        returns (bytes memory)
    79	    {
    80	        uint256 lockTime = lockAccelerated ? SHORTER_LOCK_TIME : EXTENDED_LOCK_TIME;
    81	        require(block.timestamp >= START_TIME + lockTime, GovernanceAcceleratedLock__LockTimeNotMet());
    82	        return Address.functionCall(_target, _data);
    83	    }
    84	}
```

### src/uniswap-periphery/IVirtualLBPStrategyBasic.sol
```solidity
     1	pragma solidity ^0.8.0;
     2	
     3	import {ILBPStrategyBasic} from "@launcher/interfaces/ILBPStrategyBasic.sol";
     4	import {IPositionManager} from "@v4p/interfaces/IPositionManager.sol";
     5	import {IPoolManager} from "@v4c/interfaces/IPoolManager.sol";
     6	
     7	interface IVirtualLBPStrategyBasic is ILBPStrategyBasic {
     8	    function approveMigration() external;
     9	
    10	    function auction() external view returns (address);
    11	    function positionManager() external view returns (IPositionManager);
    12	    function positionRecipient() external view returns (address);
    13	    function migrationBlock() external view returns (uint256);
    14	    function sweepBlock() external view returns (uint256);
    15	    function token() external view returns (address);
    16	    function currency() external view returns (address);
    17	    function poolLPFee() external view returns (uint24);
    18	    function poolTickSpacing() external view returns (int24);
    19	    function operator() external view returns (address);
    20	    function poolManager() external view returns (IPoolManager);
    21	
    22	    function UNDERLYING_TOKEN() external view returns (address);
    23	    function GOVERNANCE() external view returns (address);
    24	}
```

### src/uniswap-periphery/IVirtualLBPStrategyFactory.sol
```solidity
     1	pragma solidity ^0.8.0;
     2	
     3	import {IDistributionStrategy} from "@launcher/interfaces/IDistributionStrategy.sol";
     4	
     5	interface IVirtualLBPStrategyFactory is IDistributionStrategy {
     6	    function getVirtualLBPAddress(
     7	        address token,
     8	        uint256 totalSupply,
     9	        bytes calldata configData,
    10	        bytes32 salt,
    11	        address sender
    12	    ) external view returns (address);
    13	}
```

### src/uniswap-periphery/VirtualAztecToken.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.27;
     3	
     4	import {IATPFactoryNonces} from "@atp/ATPFactoryNonces.sol";
     5	import {RevokableParams} from "@atp/atps/linear/ILATP.sol";
     6	import {LockLib} from "@atp/libraries/LockLib.sol";
     7	import {Ownable} from "@oz/access/Ownable.sol";
     8	import {ERC20} from "@oz/token/ERC20/ERC20.sol";
     9	import {IERC20} from "@oz/token/ERC20/IERC20.sol";
    10	import {ECDSA} from "@oz/utils/cryptography/ECDSA.sol";
    11	import {EIP712} from "@oz/utils/cryptography/EIP712.sol";
    12	import {Nonces} from "@oz/utils/Nonces.sol";
    13	import {IContinuousClearingAuction} from "@twap-auction/interfaces/IContinuousClearingAuction.sol";
    14	import {IWhitelistProvider} from "../soulbound/providers/IWhitelistProvider.sol";
    15	
    16	interface IVirtualToken is IERC20 {
    17	    function UNDERLYING_TOKEN_ADDRESS() external view returns (IERC20);
    18	}
    19	
    20	interface IVirtualAztecToken is IVirtualToken {
    21	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    22	    /*                        Structs                             */
    23	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    24	    struct Signature {
    25	        bytes32 r;
    26	        bytes32 s;
    27	        uint8 v;
    28	    }
    29	
    30	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    31	    /*                        Events                              */
    32	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    33	    event AuctionAddressSet(IContinuousClearingAuction auctionAddress);
    34	    event StrategyAddressSet(address strategyAddress);
    35	    event UnderlyingTokensRecovered(address to, uint256 amount);
    36	    event AtpBeneficiarySet(address indexed _owner, address indexed _beneficiary);
    37	    event ScreeningProviderSet(address indexed _screeningProvider);
    38	
    39	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    40	    /*                        Errors                              */
    41	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    42	    error VirtualAztecToken__ZeroAddress();
    43	    error VirtualAztecToken__Recover__InvalidAddress();
    44	    error VirtualAztecToken__UnderlyingTokensNotBacked();
    45	    error VirtualAztecToken__NotImplemented();
    46	    error VirtualAztecToken__AuctionNotSet();
    47	    error VirtualAztecToken__StrategyNotSet();
    48	    error VirtualAztecToken__InvalidEIP712SetBeneficiarySiganture();
    49	    error VirtualAztecToken__ScreeningFailed();
    50	    error VirtualAztecToken__SignatureDeadlineExpired();
    51	
    52	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    53	    /*                     User Functions                         */
    54	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    55	    function setAtpBeneficiary(address _beneficiary, bytes calldata _screeningData) external;
    56	    function setAtpBeneficiaryWithSignature(
    57	        address _owner,
    58	        address _beneficiary,
    59	        uint256 _deadline,
    60	        Signature memory _signature,
    61	        bytes calldata _screeningData
    62	    ) external;
    63	    function sweepIntoAtp() external;
    64	
    65	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    66	    /*                    Admin Functions                         */
    67	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    68	    function mint(address _to, uint256 _amount) external;
    69	    function setAuctionAddress(IContinuousClearingAuction _auctionAddress) external;
    70	    function setStrategyAddress(address _strategyAddress) external;
    71	    function pendingAtpBalance(address _beneficiary) external view returns (uint256);
    72	    function setScreeningProvider(address _screeningProvider) external;
    73	
    74	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    75	    /*                     View Functions                         */
    76	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    77	    function auctionAddress() external view returns (IContinuousClearingAuction);
    78	    function strategyAddress() external view returns (address);
    79	    function ATP_FACTORY() external view returns (IATPFactoryNonces);
    80	    function atpBeneficiaries(address _owner) external view returns (address);
    81	    function getSetAtpBeneficiaryWithSignatureDigest(address _owner, address _beneficiary, uint256 _deadline, uint256 _nonce)
    82	        external
    83	        view
    84	        returns (bytes32);
    85	}
    86	
    87	/**
    88	 * @title Virtual Aztec Token
    89	 * @author Aztec-Labs
    90	 * @notice The virtual aztec token is a token used to represent the aztec token within the auction system.
    91	 *         It is expected to hold its entire supply
    92	 */
    93	contract VirtualAztecToken is ERC20, EIP712, Ownable, Nonces, IVirtualAztecToken {
    94	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    95	    /*                       Constants                            */
    96	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    97	    /// @notice If purchasing over the stake amount - they go into a must stake ATP
    98	    uint256 public constant MIN_STAKE_AMOUNT = 200_000 ether;
    99	
   100	    /// @notice EIP-712 typehash for set atp beneficiary with signature
   101	    bytes32 public constant SET_ATP_BENEFICIARY_WITH_SIGNATURE_TYPEHASH =
   102	        keccak256("setAtpBeneficiaryWithSignature(address _owner,address _beneficiary,uint256 _deadline,uint256 _nonce)");
   103	
   104	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   105	    /*                      Immutables                            */
   106	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   107	    /// @notice The address of the underlying token - the aztec token
   108	    IERC20 public immutable UNDERLYING_TOKEN_ADDRESS;
   109	
   110	    /// @notice The address of the ATP factory contract for when not purchasing over the stake amount
   111	    IATPFactoryNonces public immutable ATP_FACTORY;
   112	
   113	    /// @notice The address of the foundation
   114	    address public immutable FOUNDATION_ADDRESS;
   115	
   116	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   117	    /*                          State                             */
   118	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   119	    /// @notice The address of the TWAP auction contract
   120	    IContinuousClearingAuction internal $auctionAddress;
   121	    /// @notice The address of the launcher strategy contract
   122	    address internal $strategyAddress;
   123	    /// @notice Screening Provider
   124	    address internal $screeningProvider;
   125	
   126	    ///@notice Allow ATPs to be minted to different beneficiaries
   127	    mapping(address owner => address beneficiary) internal $atpBeneficiaries;
   128	
   129	    /// @notice The balances of the ATPs that have been created for each beneficiary
   130	    mapping(address atpBeneficiary => uint256 pendingAtpBalance) internal $pendingAtpBalances;
   131	
   132	    constructor(
   133	        string memory _name,
   134	        string memory _symbol,
   135	        IERC20 _underlyingTokenAddress,
   136	        IATPFactoryNonces _atpFactory,
   137	        address _foundationAddress
   138	    ) ERC20(_name, _symbol) Ownable(msg.sender) EIP712("VirtualAztecToken", "1") {
   139	        require(address(_underlyingTokenAddress) != address(0), VirtualAztecToken__ZeroAddress());
   140	        require(address(_atpFactory) != address(0), VirtualAztecToken__ZeroAddress());
   141	        require(address(_foundationAddress) != address(0), VirtualAztecToken__ZeroAddress());
   142	
   143	        UNDERLYING_TOKEN_ADDRESS = _underlyingTokenAddress;
   144	        ATP_FACTORY = _atpFactory;
   145	        FOUNDATION_ADDRESS = _foundationAddress;
   146	    }
   147	
   148	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   149	    /*                      Admin Functions                       */
   150	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   151	    /**
   152	     * @notice Mint the tokens to the recipient
   153	     * @param _to The address of the recipient
   154	     * @param _amount The amount of tokens to mint
   155	     * @dev Only callable by the owner
   156	     * @dev the minter must have approved the virtual tokens contract to spend the underlying token
   157	     * @dev the minting must be backed 1 to 1 by the underlying tokens
   158	     */
   159	    function mint(address _to, uint256 _amount) external override(IVirtualAztecToken) onlyOwner {
   160	        IERC20(UNDERLYING_TOKEN_ADDRESS).transferFrom(msg.sender, address(this), _amount);
   161	
   162	        // Check that the underlying tokens are backed 1 to 1 by the virtual tokens
   163	        // The total supply of this token + the amount to mint should be less than or equal to the balance of the underlying held
   164	        uint256 totalSupply = totalSupply();
   165	        uint256 underlyingBalance = IERC20(UNDERLYING_TOKEN_ADDRESS).balanceOf(address(this));
   166	        require(totalSupply + _amount <= underlyingBalance, VirtualAztecToken__UnderlyingTokensNotBacked());
   167	
   168	        // Mint the tokens
   169	        _mint(_to, _amount);
   170	    }
   171	
   172	    /**
   173	     * @notice Set the auction address
   174	     * @param _auctionAddress The address of the auction contract
   175	     * @dev Only callable by the owner
   176	     * @dev The auction contract is used to mint the tokens into the auction system
   177	     */
   178	    function setAuctionAddress(IContinuousClearingAuction _auctionAddress) external override(IVirtualAztecToken) onlyOwner {
   179	        require(address(_auctionAddress) != address(0), VirtualAztecToken__ZeroAddress());
   180	
   181	        $auctionAddress = _auctionAddress;
   182	        emit AuctionAddressSet(_auctionAddress);
   183	    }
   184	
   185	    /**
   186	     * @notice Set the strategy address
   187	     * @param _strategyAddress The address of the strategy contract
   188	     * @dev Only callable by the owner
   189	     * @dev The strategy contract is used to migrate the tokens into the auction system
   190	     */
   191	    function setStrategyAddress(address _strategyAddress) external override(IVirtualAztecToken) onlyOwner {
   192	        require(_strategyAddress != address(0), VirtualAztecToken__ZeroAddress());
   193	
   194	        $strategyAddress = _strategyAddress;
   195	        emit StrategyAddressSet(_strategyAddress);
   196	    }
   197	
   198	    /**
   199	     * @notice Set the screening provider
   200	     * @param _screeningProvider The address of the screening provider
   201	     * @dev Only callable by the owner
   202	     * @dev The screening provider is used to screen the beneficiary
   203	     */
   204	    function setScreeningProvider(address _screeningProvider) external override(IVirtualAztecToken) onlyOwner {
   205	        require(_screeningProvider != address(0), VirtualAztecToken__ZeroAddress());
   206	        $screeningProvider = _screeningProvider;
   207	        emit ScreeningProviderSet(_screeningProvider);
   208	    }
   209	
   210	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   211	    /*                      User Functions                       */
   212	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   213	    /**
   214	     * @notice Sweep the tokens into an ATP
   215	     * @dev The tokens are swept into an ATP for the sender
   216	     * @dev The ATP is created for the sender's beneficiary
   217	     */
   218	    function sweepIntoAtp() external override(IVirtualAztecToken) {
   219	        uint256 atpBalance = $pendingAtpBalances[msg.sender];
   220	        $pendingAtpBalances[msg.sender] = 0;
   221	
   222	        // Create the ATP for each beneficiary
   223	        _mintAtp(msg.sender, atpBalance);
   224	    }
   225	
   226	    /**
   227	     * @notice Set the atp beneficiary
   228	     * @param _beneficiary The address of the beneficiary
   229	     * @dev Only callable by the owner
   230	     * @dev The beneficiary is the address that will receive the ATPs
   231	     */
   232	    function setAtpBeneficiary(address _beneficiary, bytes calldata _screeningData)
   233	        external
   234	        override(IVirtualAztecToken)
   235	    {
   236	        require(_beneficiary != address(0), VirtualAztecToken__ZeroAddress());
   237	        require(
   238	            IWhitelistProvider($screeningProvider).verify(_beneficiary, _screeningData),
   239	            VirtualAztecToken__ScreeningFailed()
   240	        );
   241	
   242	        $atpBeneficiaries[msg.sender] = _beneficiary;
   243	        emit AtpBeneficiarySet(msg.sender, _beneficiary);
   244	    }
   245	
   246	    ///@notice Allow setting of the atp beneficiary via a signature in order to support multicall flows
   247	    function setAtpBeneficiaryWithSignature(
   248	        address _owner,
   249	        address _beneficiary,
   250	        uint256 _deadline,
   251	        IVirtualAztecToken.Signature memory _signature,
   252	        bytes calldata _screeningData
   253	    ) external override(IVirtualAztecToken) {
   254	        require(block.timestamp <= _deadline, VirtualAztecToken__SignatureDeadlineExpired());
   255	        require(_owner != address(0), VirtualAztecToken__ZeroAddress());
   256	        require(_beneficiary != address(0), VirtualAztecToken__ZeroAddress());
   257	
   258	        uint256 nonce = _useNonce(_owner);
   259	        bytes32 digest = getSetAtpBeneficiaryWithSignatureDigest(_owner, _beneficiary, _deadline, nonce);
   260	
   261	        address recoveredOwner = ECDSA.recover(digest, _signature.v, _signature.r, _signature.s);
   262	        require(recoveredOwner == _owner, VirtualAztecToken__InvalidEIP712SetBeneficiarySiganture());
   263	
   264	        require(
   265	            IWhitelistProvider($screeningProvider).verify(_beneficiary, _screeningData),
   266	            VirtualAztecToken__ScreeningFailed()
   267	        );
   268	
   269	        $atpBeneficiaries[_owner] = _beneficiary;
   270	        emit AtpBeneficiarySet(_owner, _beneficiary);
   271	    }
   272	
   273	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   274	    /*                     View Functions                         */
   275	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   276	    function auctionAddress() external view override(IVirtualAztecToken) returns (IContinuousClearingAuction) {
   277	        return $auctionAddress;
   278	    }
   279	
   280	    function strategyAddress() external view override(IVirtualAztecToken) returns (address) {
   281	        return $strategyAddress;
   282	    }
   283	
   284	    function pendingAtpBalance(address _beneficiary) external view override(IVirtualAztecToken) returns (uint256) {
   285	        return $pendingAtpBalances[_beneficiary];
   286	    }
   287	
   288	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   289	    /*                     ERC20 overrides                        */
   290	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   291	    /**
   292	     * @notice Transfer the token to the recipient
   293	     * @param _to The address of the recipient
   294	     * @param _amount The amount of tokens to transfer
   295	     * @return bool Whether the transfer was successful
   296	     *
   297	     * @dev Only implements token transfers if the sender is the auction contract or the pool migrator contract
   298	     */
   299	    // NOTE: there must be no circumstances where this can burn more tokens than are expected
   300	    function transfer(address _to, uint256 _amount) public override(ERC20, IERC20) returns (bool) {
   301	        require(address($auctionAddress) != address(0), VirtualAztecToken__AuctionNotSet());
   302	        require(address($strategyAddress) != address(0), VirtualAztecToken__StrategyNotSet());
   303	
   304	        if (msg.sender == address($auctionAddress) && _to == FOUNDATION_ADDRESS) {
   305	            // Burn the virtual tokens
   306	            _burn(msg.sender, _amount);
   307	
   308	            // Transfer the underlying tokens back to the foundation
   309	            return IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(_to, _amount);
   310	        }
   311	        // If the transfer is being made from the auction contract, it will mint an ATP for the recipient
   312	        else if (msg.sender == address($auctionAddress)) {
   313	            // Burn the virtual tokens
   314	            _burn(msg.sender, _amount);
   315	
   316	            // Account for a balance being added to the _to address for creating atp
   317	            $pendingAtpBalances[_to] += _amount;
   318	            return true;
   319	        }
   320	        // If the transfer is being made from the pool migrator contract, it will transfer the underlying tokens
   321	        // The migrator will move the virtual tokens into the auction system at the beginning of the auction
   322	        // So we need to check that the auction has ended in order to transfer the underlying tokens - for migration
   323	        // be done by asserting the address it is sending to is NOT the auction address
   324	        else if (msg.sender == $strategyAddress && _to != address($auctionAddress)) {
   325	            // Burn the virtual tokens
   326	            _burn(msg.sender, _amount);
   327	
   328	            // Transfer the underlying tokens to the pool migrator
   329	            return IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(_to, _amount);
   330	        }
   331	
   332	        // Otherwise, transfer the tokens normally
   333	        return super.transfer(_to, _amount);
   334	    }
   335	
   336	    /**
   337	     * @notice Transfer the tokens from the sender to the recipient
   338	     * @param _from The address of the sender
   339	     * @param _to The address of the recipient
   340	     * @param _amount The amount of tokens to transfer
   341	     * @return bool Whether the transfer was successful
   342	     * @dev Reverts as transfer from is not implemented
   343	     */
   344	    function transferFrom(address _from, address _to, uint256 _amount) public override(ERC20, IERC20) returns (bool) {
   345	        if (_to == $strategyAddress) {
   346	            return super.transferFrom(_from, _to, _amount);
   347	        }
   348	        revert VirtualAztecToken__NotImplemented();
   349	    }
   350	
   351	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   352	    /*                     View Functions                     */
   353	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   354	    function getSetAtpBeneficiaryWithSignatureDigest(address _owner, address _beneficiary, uint256 _deadline, uint256 _nonce)
   355	        public
   356	        view
   357	        override(IVirtualAztecToken)
   358	        returns (bytes32)
   359	    {
   360	        return
   361	            _hashTypedDataV4(keccak256(abi.encode(SET_ATP_BENEFICIARY_WITH_SIGNATURE_TYPEHASH, _owner, _beneficiary, _deadline, _nonce)));
   362	    }
   363	
   364	    ///@notice external view function for atp beneficiaries state mapping
   365	    function atpBeneficiaries(address _owner) external view override(IVirtualAztecToken) returns (address) {
   366	        return $atpBeneficiaries[_owner];
   367	    }
   368	
   369	    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
   370	    /*                     Internal Functions                     */
   371	    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
   372	
   373	    /// @notice Get the atp beneficiary for the given address
   374	    /// @dev if nothing is set, return _to, otherwise return the stored value
   375	    function getATPBeneficiary(address _to) internal view returns (address) {
   376	        address _storedBeneficiary = $atpBeneficiaries[_to];
   377	        if (_storedBeneficiary != address(0)) {
   378	            return _storedBeneficiary;
   379	        }
   380	        return _to;
   381	    }
   382	
   383	    /**
   384	     * @notice Mint the ATP
   385	     * @param _beneficiary The address of the beneficiary
   386	     * @param _amount The amount of tokens to mint into the ATP
   387	     * @dev Creates a NCATP if the amount is greater than or equal to the min stake amount, otherwise creates a LATP
   388	     */
   389	    function _mintAtp(address _beneficiary, uint256 _amount) internal {
   390	        address atpBeneficiary = getATPBeneficiary(_beneficiary);
   391	
   392	        if (_amount >= MIN_STAKE_AMOUNT) {
   393	            // Transfer the underlying tokens to the ATP factory
   394	            IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(address(ATP_FACTORY), _amount);
   395	            ATP_FACTORY.createNCATP(
   396	                atpBeneficiary, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
   397	            );
   398	        } else {
   399	            // Transfer the underlying tokens to the ATP factory
   400	            IERC20(UNDERLYING_TOKEN_ADDRESS).transfer(address(ATP_FACTORY), _amount);
   401	            ATP_FACTORY.createLATP(
   402	                atpBeneficiary, _amount, RevokableParams({revokeBeneficiary: address(0), lockParams: LockLib.empty()})
   403	            );
   404	        }
   405	    }
   406	}
```

## src/uniswap-periphery/barrel/

### src/uniswap-periphery/barrel/UniswapBarrel.sol
```solidity
     1	// SPDX-License-Identifier: Apache-2.0
     2	pragma solidity ^0.8.26;
     3	
     4	import {ContinuousClearingAuction, AuctionParameters} from "@twap-auction/ContinuousClearingAuction.sol";
     5	import {VirtualLBPStrategyBasic} from "@launcher/distributionContracts/VirtualLBPStrategyBasic.sol";
     6	import {MigratorParameters} from "@launcher/types/MigratorParameters.sol";
     7	import {IPositionManager} from "@v4p/interfaces/IPositionManager.sol";
     8	import {IPoolManager} from "@v4c/interfaces/IPoolManager.sol";
     9	
    10	// Useless barrel contract to ensure their builds end up in the out folder
    11	contract UniswapBarrel {
    12	    ContinuousClearingAuction public auction;
    13	    VirtualLBPStrategyBasic public strategy;
    14	
    15	    constructor() {
    16	        auction = new ContinuousClearingAuction(address(0), 0, AuctionParameters({
    17	            currency: address(0),
    18	            tokensRecipient: address(0),
    19	            fundsRecipient: address(0),
    20	            startBlock: 0,
    21	            endBlock: 0,
    22	            claimBlock: 0,
    23	            floorPrice: 0,
    24	            tickSpacing: 0,
    25	            validationHook: address(0),
    26	            requiredCurrencyRaised: 0,
    27	            auctionStepsData: bytes("")
    28	        }));
    29	        strategy = new VirtualLBPStrategyBasic(address(0), 0, MigratorParameters({
    30	            migrationBlock: 0,
    31	            currency: address(0),
    32	            poolLPFee: 0,
    33	            poolTickSpacing: 0,
    34	            tokenSplitToAuction: 0,
    35	            auctionFactory: address(0),
    36	            positionRecipient: address(0),
    37	            sweepBlock: 0,
    38	            operator: address(0),
    39	            createOneSidedTokenPosition: false,
    40	            createOneSidedCurrencyPosition: false
    41	        }), bytes(""), IPositionManager(address(0)), IPoolManager(address(0)), address(0));
    42	    }
    43	}
```

