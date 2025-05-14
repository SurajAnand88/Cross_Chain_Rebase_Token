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

    uint256 public constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address user => uint256 interestRate) private s_usersInterestRate;
    mapping(address user => uint256 lastTimeStamp) private s_usersLastUpdatedTimestamp;

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
     * @notice this function will mint the RBT token on user address and set the interest rate when they deposite into the vault
     * @param _to the user address to mint the RBT token
     * @param _amount the amount of the RBT token to mint
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccuredInterest(_to);
        _mint(_to, _amount);
        s_usersInterestRate[_to] = s_interestRate;
    }

    /**
     * @notice this function will calculated the balance of the user including interest that has been accumulated since last update
     *  principal balance + some interest that has accured
     * @param _user the user who's balance need to be calculated
     * @return the balance of the user including any interest
     */
    function balanceOf(address _user) public view override returns (uint256) {
        //get the current principal balance (the number of  rebase token that have actually been minted to the user)
        //multiply the principal balance by the interest that has accumulated in the time since balance was lastUpdated
        return (super.balanceOf(_user) * _calculateUsersAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }
    /**
     * @notice this function returns the interestRate of the user
     * @param _user the user who's interest rate will be returned
     */

    function _mintAccuredInterest(address _user) internal {
        //find the current balance of the rebase token that has been minted to the user - principal balance
        // calculate their current balance including any interest -> balanceOf
        //calculate the number of token that needs to be minted to the user = principal balance - balanceOf
        //call _mint to mint the token to the user
        s_usersLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
     * @notice this function will calculate the accumulated interest of the user since last updated time
     * @param _user the user who's accumulated interest need to be calculated
     */
    function _calculateUsersAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // Interest is going to be linear grwoth with time
        // calculate the time since last updated
        // calculate the amount of liner growth
        // (principalamount)+(principalAmount * user_interestRate * timeElapsed)
        uint256 timeElapsed = block.timestamp - s_usersLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_usersInterestRate[_user] * timeElapsed);
    }

    function getUsersInterestRate(address _user) public view returns (uint256) {
        return s_usersInterestRate[_user];
    }

    function getUsersLastUpdatedTimeStamp(address _user) public view returns (uint256) {
        return s_usersLastUpdatedTimestamp[_user];
    }
}
