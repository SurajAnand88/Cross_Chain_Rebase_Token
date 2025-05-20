// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";

contract DeployRebaseToken is Script {
    function run() external returns (RebaseToken, Vault) {
        vm.startBroadcast();
        RebaseToken rbt = new RebaseToken();
        Vault vault = new Vault(address(rbt));
        vm.stopBroadcast();
        return (rbt, vault);
    }
}
