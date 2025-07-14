// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from
    "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract DeployRebaseToken is Script {
    function run() external returns (RebaseToken, Vault) {
        vm.startBroadcast();
        RebaseToken rbt = new RebaseToken();
        Vault vault = new Vault(address(rbt));
        rbt.grantRole(address(vault));
        vm.stopBroadcast();
        return (rbt, vault);
    }
}

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken, RebaseTokenPool) {
        Register.NetworkDetails memory localNetworkDetails;
        CCIPLocalSimulatorFork ccipLocalSimulatorFork;
        localNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        RebaseToken rbt = new RebaseToken();
        RebaseTokenPool pool = new RebaseTokenPool(
            IERC20(address(rbt)),
            new address[](0),
            localNetworkDetails.rmnProxyAddress,
            localNetworkDetails.routerAddress
        );
        rbt.grantRole(address(pool));
        RegistryModuleOwnerCustom(localNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(rbt)
        );
        TokenAdminRegistry(localNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(rbt));
        TokenAdminRegistry(localNetworkDetails.tokenAdminRegistryAddress).setPool(address(rbt), address(pool));
        vm.stopBroadcast();
        return (rbt, pool);
    }
}
