// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebaseToken} from "src/RebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";
import {Vault} from "src/Vault.sol";
import {Test,console} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork,Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";


contract CrossChainTest is Test {
    address private owner = makeAddr("Owner");
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    Vault public vault;
    RebaseToken public sepoliaToken;
    RebaseToken public arbToken;

    RebaseTokenPool public sepoliaTokenPool;
    RebaseTokenPool public arbSepoliaTokenPool;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;


    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia-eth");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.startPrank(owner);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sepoliaToken = new RebaseToken();
        vault = new Vault(address(sepoliaToken));
        arbSepoliaTokenPool = new RebaseTokenPool();
        vm.stopPrank();


        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbToken = new RebaseToken();
        arbTokenPool = new RebaseTokenPool();
        vm.stopPrank();
    }
}