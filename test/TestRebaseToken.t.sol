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
    uint256 public constant INTEREST_RATE = 5e10;
    uint256 public constant INITIAL_MINT_AMOUNT= 200e18;
    uint256 public constant INITIAL_BURN_TOKEN = 100e18;

    event InterestRateSet(uint256 indexed intereseRate);

    function setUp() external {
        DeployRebaseToken deployer = new DeployRebaseToken();
        (rbt, vault) = deployer.run();
        vm.prank(msg.sender);
        rbt.transferOwnership(OWNER);
        vm.deal(USER, 100 ether);
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

    function testMint() public roleGranted{
        vm.startPrank(USER);
        rbt.mint(USER,INITIAL_MINT_AMOUNT);
        uint256 currentBalance  =rbt.balanceOf(USER);
        console.log(currentBalance);
        assertEq(currentBalance, INITIAL_MINT_AMOUNT);

    }

    function testBurn() public mintToken{
        rbt.burn(USER,INITIAL_BURN_TOKEN);
        uint256 newBalance = rbt.balanceOf(USER);
        assertEq(newBalance, (INITIAL_MINT_AMOUNT-INITIAL_BURN_TOKEN));
    }

    modifier onlyOwner() {
        vm.startPrank(OWNER);
        _;
    }

    modifier roleGranted() {
        vm.startPrank(OWNER);
        rbt.grantRole(USER);
        vm.stopPrank();
        _;
    }
    modifier mintToken(){
        vm.prank(OWNER);
        rbt.grantRole(USER);
        vm.startPrank(USER);
        rbt.mint(USER, INITIAL_MINT_AMOUNT);
        _;
    }
}
