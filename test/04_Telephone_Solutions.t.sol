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
        owner = makeAddr("owner");
        vm.prank(owner);
        TelephoneContract = new Telephone();

        hacker = makeAddr("hacker");
        vm.prank(hacker);
        attackerContractl = new Attacker(address(TelephoneContract));
    }

    function test_attack() public {
        vm.prank(hacker, hacker);
        attackerContractl.attack();
        assertEq(TelephoneContract.owner(), hacker, "Hack failed: You are not the owner!");
    }
}
