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
        for (uint256 i = 0; i < 10; i++) {
            vm.roll(block.number + 1);

            vm.prank(hacker);
            attackerContractl.attack();
        }

        assertEq(coinFlipContract.consecutiveWins(), 10, "Not reaching 10 consecutive wins!");
    }
}
