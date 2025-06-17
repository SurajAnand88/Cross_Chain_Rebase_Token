// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
    uint256 public interestRate;

    event InterestRateSet(uint256 indexed intereseRate);

    function setUp() external {
        DeployRebaseToken deployer = new DeployRebaseToken();
        (rbt, vault) = deployer.run();
        vm.prank(msg.sender);
        rbt.transferOwnership(OWNER);
        vm.deal(USER, 100 ether);
        interestRate = rbt.getInterestRate();
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
        rbt.mint(USER, INITIAL_MINT_AMOUNT, interestRate);
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

    function testVaultRedeemAfterSomeTimePassed(uint256 depositAmount, uint256 time) public roleGranted {
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);

        vm.deal(USER, depositAmount);
        vm.prank(USER);
        vault.deposite{value: depositAmount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterTimePassed = rbt.balanceOf(USER);

        vm.prank(OWNER);
        vm.deal(OWNER, balanceAfterTimePassed - depositAmount);
        addRewardsToVault(balanceAfterTimePassed - depositAmount);

        vm.prank(USER);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(USER).balance;
        assertEq(ethBalance, balanceAfterTimePassed);
        assertGt(ethBalance, depositAmount);
    }

    function testTransferAndInterestRate(uint256 amount) public roleGranted {
        amount = bound(amount, 1, INITIAL_MINT_AMOUNT);
        vm.startPrank(USER);
        rbt.mint(USER, INITIAL_MINT_AMOUNT, interestRate);
        rbt.transfer(USER2, amount);
        vm.stopPrank();
        uint256 user2Balance = rbt.balanceOf(USER2);
        uint256 globalInterestRate = rbt.getInterestRate();
        uint256 user2InterestRate = rbt.getUsersInterestRate(USER2);

        assertEq(user2InterestRate, globalInterestRate);
        assertEq(user2Balance, amount);
    }

    function testTransferFrom(uint256 amount) public roleGranted mintToken {
        amount = bound(amount, 1, INITIAL_MINT_AMOUNT);
        rbt.approve(OWNER, amount);
        vm.stopPrank();
        vm.prank(OWNER);
        rbt.transferFrom(USER, USER2, amount);
        uint256 user2Bal = rbt.balanceOf(USER2);
        assertEq(user2Bal, amount);
    }

    function testPrincipalBalanceOfTheUser(uint256 amount) public roleGranted {
        amount = bound(amount, 1, INITIAL_MINT_AMOUNT);
        vm.startPrank(USER);

        rbt.mint(USER, amount, interestRate);
        uint256 futureTime = block.timestamp + INTEREST_CALCULATION_TIME;
        vm.warp(futureTime);

        uint256 balAfterSomeTime = rbt.balanceOf(USER);
        rbt.mint(USER, 0, interestRate);
        uint256 principalBal = rbt.principalBalanceOf(USER);
        vm.stopPrank();
        uint256 userLastTimeStamp = rbt.getUsersLastUpdatedTimeStamp(USER);
        assertEq(principalBal, balAfterSomeTime);
        assertEq(userLastTimeStamp, futureTime);
    }

    function testRebaseTokenAddress() public view {
        address rebaseToken = vault.getRebaseTokenAddress();
        assertEq(address(rbt), rebaseToken);
    }

    function addRewardsToVault(uint256 amount) public {
        (bool success,) = payable(address(vault)).call{value: amount}("");
        if (!success) revert("Transfer_Failed");
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
        rbt.mint(USER, INITIAL_MINT_AMOUNT, interestRate);
        _;
    }
}
