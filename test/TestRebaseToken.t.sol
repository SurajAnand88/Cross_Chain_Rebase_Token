// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRebaseToken} from "script/DeployRebaseToken.s.sol";
import {RebaseToken} from "src/RebaseToken.sol";

contract TestRebaseToken is Test {
    RebaseToken public rbt;

    function setUp() external {
        DeployRebaseToken deployer = new DeployRebaseToken();
        rbt = deployer.run();
    }

    function testNameAndSymbol() public view {
        string memory expectedName = "RebaseToken";
        string memory name = rbt.name();
        assertEq(keccak256(abi.encodePacked(name)), keccak256(abi.encodePacked(expectedName)));
    }
}
