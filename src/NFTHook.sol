// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "solmate/src/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title NFTHook
 * @notice A hook that mints NFTs based on donations and Chainlink VRF randomness.
 */
contract NFTHook is BaseHook, ERC721, ReentrancyGuard, VRFConsumerBaseV2Plus {
    error RequestAlreadyFulfilled();
    error RequestDoesNotExist();

    struct RequestStatus {
        uint256 tokenId;
        address donor;
        uint256 randomNumber;
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
    }

    // Chainlink VRF Coordinator Configuration
    uint32 constant CALLBACK_GAS_LIMIT = 100000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 1;

    uint256 public constant INCREMENT_PERCENTAGE = 5; // 5% increase after each donation

    uint256 immutable s_subscriptionId;
    bytes32 immutable s_keyHash;

    uint256 public minDonationAmount; // The donation threshold
    uint256 public mintedCount; // Count of minted NFTs
    uint256 public maxSupply; // Maximum number of NFTs that can be minted

    string public baseTokenURI; // Base URI for token metadata

    mapping(uint256 => bool) public tokenMinted;
    mapping(uint256 => RequestStatus) public s_requests;

    event RequestSent(uint256 indexed requestId);
    event RequestFulfilled(uint256 indexed requestId, uint256 randomNumber);

    /**
     * @notice Initializes the contract with the given parameters.
     * @param manager_ The PoolManager contract.
     * @param name_ The name of the NFT collection.
     * @param symbol_ The symbol of the NFT collection.
     * @param baseTokenURI_ The base URI for the token metadata.
     * @param maxSupply_ The maximum number of NFTs that can be minted.
     * @param vrfCoordinatorV2Plus_ The address of the VRF Coordinator.
     * @param subscriptionId_ The subscription ID for the Chainlink VRF.
     * @param keyHash_ The key hash for the Chainlink VRF.
     */
    constructor(
        IPoolManager manager_,
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        uint256 maxSupply_,
        address vrfCoordinatorV2Plus_,
        uint256 subscriptionId_,
        bytes32 keyHash_
    )
        BaseHook(manager_)
        ERC721(name_, symbol_)
        VRFConsumerBaseV2Plus(vrfCoordinatorV2Plus_)
    {
        baseTokenURI = baseTokenURI_;
        maxSupply = maxSupply_;
        s_subscriptionId = subscriptionId_;
        s_keyHash = keyHash_;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: true,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function afterDonate(
        address sender,
        PoolKey calldata,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external virtual override nonReentrant returns (bytes4) {
        // Combine the amounts of both tokens in the donation
        uint256 totalDonation = amount0 + amount1;

        // Check if:
        // - the donation amount is not zero
        // - the donation amount is greater than the minimum threshold
        // - the maximum NFT supply has not been reached
        if (
            sender == address(0) ||
            totalDonation == 0 ||
            mintedCount >= maxSupply ||
            totalDonation < minDonationAmount
        ) {
            return (this.afterDonate.selector);
        }

        // Request randomness from Chainlink VRF
        _requestRandomWords();

        return (this.afterDonate.selector);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256 randomNumber) {
        if (!s_requests[_requestId].exists) {
            revert RequestDoesNotExist();
        }
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomNumber);
    }

    function _requestRandomWords() private {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        s_requests[requestId] = RequestStatus({
            tokenId: 0,
            donor: msg.sender,
            randomNumber: 0,
            fulfilled: false,
            exists: true
        });

        emit RequestSent(requestId);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        if (s_requests[_requestId].fulfilled) {
            revert RequestAlreadyFulfilled();
        }
        uint256 requestNumber = _randomWords[0];
        // Determine the token ID based on the randomness and maxSupply
        uint256 tokenId = requestNumber % maxSupply;

        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomNumber = requestNumber;
        s_requests[_requestId].tokenId = tokenId;

        // Ensure the token ID is available and hasn't been minted yet
        if (tokenMinted[tokenId]) {
            return;
        }

        tokenMinted[tokenId] = true;
        // Mint the NFT with the randomly selected token ID
        _mint(s_requests[_requestId].donor, tokenId);

        // Increment the count of minted NFTs
        mintedCount++;
        // Increase the minimum donation amount by 5% after each successful donation
        minDonationAmount += (minDonationAmount * INCREMENT_PERCENTAGE) / 100;

        emit RequestFulfilled(_requestId, requestNumber);
    }

    /**
     * @notice Returns the token uri by id.
     * @param _tokenId The token id of collection.
     * @return tokenURI.
     */
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    baseTokenURI,
                    Strings.toString(_tokenId),
                    ".json"
                )
            );
    }
}
