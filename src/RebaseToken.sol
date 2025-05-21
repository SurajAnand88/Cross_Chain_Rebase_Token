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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Suraj
 * @notice This is a cross-chain rebase token that incentivise user to deposite collateral into the vault
 * @notice This interest rate of the smart contract can only decrease
 * @notice Every user has their own interest rate that is global interest rate at the time of depositing collateral
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyBeDecreased(uint256, uint256);
    error RebaseToken__InterestRateShouldNotBeZero();

    uint256 public constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;
    mapping(address user => uint256 interestRate) private s_usersInterestRate;
    mapping(address user => uint256 lastTimeStamp) private s_usersLastUpdatedTimestamp;

    event InterestRateSet(uint256 indexed intereseRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    modifier notZero(uint256 _rate) {
        if (_rate <= 0) revert RebaseToken__InterestRateShouldNotBeZero();
        _;
    }

    function grantRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice this function sets the new interest rate
     * @param _interestRate: The new interrest rate to set
     * @dev s_interestRate can only be decreased
     */
    function setInterestRate(uint256 _interestRate) external onlyOwner notZero(_interestRate) {
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
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        _mint(_to, _amount);
        s_usersInterestRate[_to] = s_interestRate;
    }

    /**
     * @notice this function will burn the token from the user
     * @param _from The user to burn the token
     * @param _amount The amount of the token to be burned
     */
    function burn(address _from, uint256 _amount) public onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) _amount = balanceOf(_from);
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
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
     * @notice this function will transfer the token from one to another user
     * @param _to The user to trnaser the token
     * @param _amount the amount of token to transfer
     */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_to);
        _mintAccuredInterest(msg.sender);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_to) == 0) {
            s_usersInterestRate[_to] = s_usersInterestRate[msg.sender];
        }

        return super.transfer(_to, _amount);
    }

    /**
     * @notice this function will transfer token from one user to another
     * @param _from the address , token will transfer from
     * @param _to the address the token will transfer
     * @param _amount the amount of the token to trnsfer
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_from);
        _mintAccuredInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        if (balanceOf(_to) == 0) {
            s_usersInterestRate[_to] = s_usersInterestRate[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @notice this function will return the principal balance of the user. This function will return the token balance of the user that has been minted without any interest accured since last time the user has intracted with the protocol.
     * @param _user the user to get the principal balance for
     * @return the principal balance of the user
     */
    function principalBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice this function returns the interestRate of the user
     * @param _user the user who's interest rate will be returned
     */
    function _mintAccuredInterest(address _user) internal {
        //find the current balance of the rebase token that has been minted to the user - principal balance
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        //calculate the number of token that needs to be minted to the user = principal balance - balanceOf
        uint256 tokensToBeMinted = currentBalance - previousPrincipalBalance;
        //call _mint to mint the token to the user
        _mint(_user, tokensToBeMinted);
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

    /**
     * @notice this function will return the interest rate of the user
     * @param _user the address of the user to return the interest rate
     */
    function getUsersInterestRate(address _user) public view returns (uint256) {
        return s_usersInterestRate[_user];
    }

    /**
     * @notice this funciton will returnt the lastupdated time stamp of the user
     * @param _user the address of the user to return the timeStamp
     */
    function getUsersLastUpdatedTimeStamp(address _user) public view returns (uint256) {
        return s_usersLastUpdatedTimestamp[_user];
    }

    /**
     * @notice this function will return the global interest rate of the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getRole() external pure returns (bytes32) {
        return MINT_AND_BURN_ROLE;
    }

    function getCalculatedInterest(address _user) external view returns (uint256) {
        return _calculateUsersAccumulatedInterestSinceLastUpdate(_user);
    }
}
