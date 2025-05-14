// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "src/RebaseToken.sol";

contract DeployRebaseToken is Script {
    function run() external returns (RebaseToken) {
        vm.startBroadcast();
        RebaseToken rbt = new RebaseToken();
        vm.stopBroadcast();
        return rbt;
    }
}
