
# **🌟 NFTHook - Randomized NFT Minting using Chainlink VRF 🌟**

## **📜 Overview**

**NFTHook** is a smart contract that mints NFTs to users after they donate a certain amount of tokens. The token ID for the NFT is determined using Chainlink's Verifiable Random Function (VRF), ensuring **randomness** and **fairness** in the minting process.

### Key Features:
- 🎲 **Randomized Token IDs**: NFTs are minted with random token IDs determined by Chainlink VRF.
- 💰 **Donation-Based Minting**: Users must donate a minimum amount to be eligible for minting an NFT.
- 🚀 **Supply Cap**: The contract limits the maximum number of NFTs that can be minted.
- 📈 **Dynamic Donation Threshold**: The minimum donation amount increases by 5% after each successful mint.

---

## **💻 Smart Contract Details**

### 📦 Imports
- `ERC721.sol`: Implements the ERC721 standard for non-fungible tokens.
- `Strings.sol`: Utility functions for string operations.
- `ReentrancyGuard.sol`: Protection against reentrancy attacks.
- `BaseHook.sol`: Implements hook functions related to liquidity pools.
- `VRFConsumerBaseV2Plus.sol`: Chainlink VRF base contract for handling randomness.

### 📊 State Variables
- **`minDonationAmount`**: The minimum amount required to donate for minting an NFT.
- **`mintedCount`**: The current count of NFTs minted.
- **`maxSupply`**: The maximum number of NFTs allowed to be minted.
- **`baseTokenURI`**: The base URI for NFT metadata.
- **`s_subscriptionId`**: Chainlink VRF subscription ID for randomness requests.
- **`s_keyHash`**: Chainlink VRF key hash.
- **`tokenMinted`**: A mapping that tracks if a specific token ID has been minted.
- **`s_requests`**: A mapping that tracks the status of Chainlink randomness requests.

---

## **⚙️ Functions**

### 🔧 `constructor`
Initializes the contract by setting the required parameters like token name, symbol, base URI, Chainlink VRF subscription ID, and key hash.

```solidity
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
```

### 🎁 `afterDonate`
Handles donations and checks if a user is eligible for NFT minting. If eligible, it requests a random number from Chainlink VRF and triggers the minting process.

```solidity
function afterDonate(
  address sender,
  PoolKey calldata,
  uint256 amount0,
  uint256 amount1,
  bytes calldata
) external virtual override nonReentrant returns (bytes4) {
  // Your function logic here
}
```

### 🔍 `getRequestStatus`
Allows users to check the status of their randomness request and whether an NFT has been minted for them.

```solidity
function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256 randomNumber);
```

### 🛠️ `_requestRandomWords`
Internally requests a random number from Chainlink VRF.

```solidity
function _requestRandomWords() private {
  // Your request logic here
}
```

### ⚡ `fulfillRandomWords`
Callback function to fulfill the randomness request and mint an NFT. The randomness determines the token ID of the NFT.

```solidity
function fulfillRandomWords(
  uint256 _requestId,
  uint256[] calldata _randomWords
) internal override {
  // Your fulfillment logic here
}
```

### 🌐 `tokenURI`
Returns the metadata URI for a given token ID.

```solidity
function tokenURI(uint256 _tokenId) public view override returns (string memory);
```

---

## **🔔 Events**

- **`RequestSent`**: Emitted when a randomness request is sent to Chainlink VRF.
- **`RequestFulfilled`**: Emitted when the randomness request is fulfilled and the NFT is minted.

```solidity
event RequestSent(uint256 indexed requestId);
event RequestFulfilled(uint256 indexed requestId, uint256 randomNumber);
```

---

## **🔗 Chainlink VRF Configuration**

The contract uses Chainlink VRF to request random numbers. Here are the VRF parameters:

- ⛽ **CALLBACK_GAS_LIMIT**: Set to 100,000 gas.
- 🔄 **REQUEST_CONFIRMATIONS**: The number of confirmations before VRF responds, set to 3.
- 🎲 **NUM_WORDS**: The number of random numbers requested from Chainlink, set to 1.

---

## **📝 Usage**

### 🚀 Deploying the Contract
Deploy the contract with the following parameters:

- `manager_`: The address of the PoolManager contract.
- `name_`: The name of the NFT collection.
- `symbol_`: The symbol for the NFT collection.
- `baseTokenURI_`: The base URI for the NFT metadata.
- `maxSupply_`: The maximum number of NFTs that can be minted.
- `vrfCoordinatorV2Plus_`: The address of the Chainlink VRF coordinator.
- `subscriptionId_`: The Chainlink VRF subscription ID.
- `keyHash_`: The Chainlink VRF key hash for randomness.

### 💸 Donating for an NFT
To mint an NFT, the user needs to make a donation above the minimum threshold. Upon a successful donation, the contract will request randomness from Chainlink to determine the NFT's token ID.

### 🔍 Checking Randomness Request Status
Users can check the status of their randomness request using the `getRequestStatus` function. It will indicate whether the request has been fulfilled and, if so, provide the random number used to mint the NFT.

---

## **📄 License**
This project is licensed under the MIT License. See the `LICENSE` file for details.
