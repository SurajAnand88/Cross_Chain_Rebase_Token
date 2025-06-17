// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {RebaseToken} from "./RebaseToken.sol";

contract Vault {
    address private immutable i_rebaseToken;

    error Vault__TransferFailed();

    event Deposited(address indexed user, uint256 indexed amount);

    constructor(address rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice this function will deposite the ETH and mint rebase Token
     */
    function deposite() external payable {
        uint256 interestRate = RebaseToken(i_rebaseToken).getInterestRate();
        RebaseToken(i_rebaseToken).mint(msg.sender, msg.value, interestRate);
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice this function allows the user to redeem their rebase token for ETH
     * @param _amount the amount of Rebase token to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = RebaseToken(i_rebaseToken).balanceOf(msg.sender);
        }
        RebaseToken(i_rebaseToken).burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) revert Vault__TransferFailed();
    }

    /**
     * @notice this function will return the rebase token address
     */
    function getRebaseTokenAddress() external view returns (address) {
        return i_rebaseToken;
    }
}
