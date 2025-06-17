// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Pool} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";

contract RebaseTokenPool is TokenPool {
    uint8 public constant DECIMAL = 18;

    constructor(IERC20 _token, address[] memory _allowlist, address _rmnProxy, address _router)
        TokenPool(_token, DECIMAL, _allowlist, _rmnProxy, _router)
    {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        uint256 interestRate = RebaseToken(address(i_token)).getUsersInterestRate(lockOrBurnIn.originalSender);
        // The way ccip works is first you approve your token,then you send your token to ccip and the ccip sends to token
        // to the token pool that's why we are buring the token from the tokenPool itself
        RebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(interestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn);
        // Now we need to decode the destPoolData that coming from another chain here
        uint256 interestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        RebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, interestRate);
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
