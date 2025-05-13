// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Rebase Token
 * @author Suraj
 * @notice This is a cross-chain rebase token that incentivise user to deposite collateral into the vault
 * @notice This interest rate of the smart contract can only decrease
 * @notice Every user has their own interest rate that is global interest rate at the time of depositing collateral
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyBeDecreased(uint256, uint256);

    uint256 private s_interestRate = 5e10;
    mapping(address user => uint256 interestRate) private s_usersInterestRate;

    event InterestRateSet(uint256 indexed intereseRate);

    constructor() ERC20("RebaseToken", "RBT") {}

    /**
     * @notice this function sets the new interest rate
     * @param _interestRate: The new interrest rate to set
     * @dev s_interestRate can only be decreased
     */
    function setInterestRate(uint256 _interestRate) public {
        if (s_interestRate < _interestRate) {
            revert RebaseToken__InterestRateCanOnlyBeDecreased(s_interestRate, _interestRate);
        }
        s_interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }


    /**
     * @notice this function will mint the RBT token on user address and set the interest rate 
     * @param _to the user address to mint the RBT token 
     * @param _amount the amount of the RBT token to mint 
     */
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
        s_usersInterestRate[_to] = s_interestRate;
    }


    /**
     * @notice this function returns the interestRate of the user
     * @param _user the user who's interest rate will be returned
     */
    function getUsersInterestRate(address _user) public view returns (uint256) {
        return s_usersInterestRate[_user];
    }
}
