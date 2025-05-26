// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRebaseToken} from "script/DeployRebaseToken.s.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";

contract TestRebaseToken is Test {
    RebaseToken public rbt;
    Vault public vault;
    address public OWNER = makeAddr("OWNER");
    address public USER = makeAddr("USER");
    address public USER2 = makeAddr("USER2");
    uint256 public constant INTEREST_RATE = 5e10;
    uint256 public constant INITIAL_MINT_AMOUNT = 200e18;
    uint256 public constant INITIAL_BURN_TOKEN = 100e18;
    uint256 public constant PRECISION_FACTOR = 1e18;
    uint256 public constant INTEREST_CALCULATION_TIME = 1 hours;

    event InterestRateSet(uint256 indexed intereseRate);

    function setUp() external {
        DeployRebaseToken deployer = new DeployRebaseToken();
        (rbt, vault) = deployer.run();
        vm.prank(msg.sender);
        rbt.transferOwnership(OWNER);
        vm.deal(USER, 100 ether);
    }

    function testCheckBalance() public mintToken {
        uint256 u1B = rbt.balanceOf(USER);
        uint256 u2B = rbt.balanceOf(USER2);
        console.log(u1B);
        console.log(u2B);
    }

    function testNameAndSymbol() public view {
        string memory expectedName = "RebaseToken";
        string memory name = rbt.name();
        assertEq(keccak256(abi.encodePacked(name)), keccak256(abi.encodePacked(expectedName)));
    }

    function testSetInterestRate() public onlyOwner {
        //Arrange
        vm.expectEmit(true, false, false, false);
        emit InterestRateSet(INTEREST_RATE);

        //Act
        rbt.setInterestRate(INTEREST_RATE);
        uint256 actualInterestRate = rbt.getInterestRate();

        //Assert
        assertEq(actualInterestRate, INTEREST_RATE);
        vm.stopPrank();
    }

    function testCheckRevertIfInterestRateIsZero() public onlyOwner {
        vm.expectRevert(RebaseToken.RebaseToken__InterestRateShouldNotBeZero.selector);
        rbt.setInterestRate(0);
        vm.stopPrank();
    }

    function testGrantRole() public onlyOwner {
        rbt.grantRole(USER);
        bytes32 expecteRole = rbt.getRole();
        assertEq(true, rbt.hasRole(expecteRole, USER));
    }

    function testMint() public roleGranted {
        vm.startPrank(USER);
        rbt.mint(USER, INITIAL_MINT_AMOUNT);
        uint256 currentBalance = rbt.balanceOf(USER);
        assertEq(currentBalance, INITIAL_MINT_AMOUNT);
    }

    function testBurn() public mintToken {
        rbt.burn(USER, INITIAL_BURN_TOKEN);
        uint256 newBalance = rbt.balanceOf(USER);
        assertEq(newBalance, (INITIAL_MINT_AMOUNT - INITIAL_BURN_TOKEN));
    }

    function testCheckCalculateUsersAccumulatedInterestSinceLastUpdate() public mintToken {
        uint256 currentTime = block.timestamp;
        uint256 interestRate = rbt.getInterestRate();
        uint256 futuretime = currentTime + INTEREST_CALCULATION_TIME;
        vm.warp(futuretime);
        uint256 expectedCalculatedInterest = (PRECISION_FACTOR + (interestRate) * (futuretime - currentTime));
        uint256 actualCalculatedInterest = rbt.getCalculatedInterest(USER);
        vm.stopPrank();
        assertEq(expectedCalculatedInterest, actualCalculatedInterest);
    }

    function testTestVaultDeposite(uint256 amount) public roleGranted {
        amount = bound(amount, 1e5, type(uint24).max);

        //deposite into the vault
        vm.startPrank(USER);
        vault.deposite{value: amount}();

        //check the balance of the user
        uint256 startingBalance = rbt.balanceOf(USER);
        vm.warp(block.timestamp + INTEREST_CALCULATION_TIME);

        uint256 midBalance = rbt.balanceOf(USER);
        vm.warp(block.timestamp + INTEREST_CALCULATION_TIME);

        uint256 endBalance = rbt.balanceOf(USER);

        assertEq(startingBalance, amount);
        assertGt(midBalance, startingBalance);
        assertGt(endBalance, midBalance);
        assertApproxEqAbs(endBalance - midBalance, midBalance - startingBalance, 1);
        vm.stopPrank();
    }

    function testVaultRedeem(uint256 amount) public roleGranted {
        amount = bound(amount, 1e5, type(uint24).max);

        vm.startPrank(USER);
        vault.deposite{value: amount}();

        uint256 preBalance = rbt.balanceOf(USER);
        assertEq(preBalance, amount);
        vault.redeem(amount);
        uint256 userBalance = rbt.balanceOf(USER);
        assertEq(userBalance, 0);

        vm.stopPrank();
    }

    modifier onlyOwner() {
        vm.startPrank(OWNER);
        _;
    }

    modifier roleGranted() {
        vm.startPrank(OWNER);
        rbt.grantRole(USER);
        rbt.grantRole(address(vault));
        vm.stopPrank();
        _;
    }

    modifier mintToken() {
        vm.prank(OWNER);
        rbt.grantRole(USER);
        vm.startPrank(USER);
        rbt.mint(USER, INITIAL_MINT_AMOUNT);
        _;
    }
}
