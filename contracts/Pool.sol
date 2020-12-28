// contracts/Pool.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface PersonalToken {
    function mint(address addr, uint256 amount) external;

    function allowance(address owner, address spender)
        external
        returns (uint256);

    function balanceOf(address account) external returns (uint256);

    function burn(address account, uint256 amount) external;
}

interface FriendToken {
    function allowance(address owner, address spender)
        external
        returns (uint256);

    function transferFrom(
        address sender,
        address receiver,
        uint256 amount
    ) external returns (bool);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transfer(address recipient, uint256 amound)
        external
        returns (bool);
}

contract Pool is Ownable {
    // emit event
    // modify view and pure
    using SafeMath for uint256;

    // internal may be better.
    address private _acceptedTokenAddr;
    // 5 digit decimal 1 friend token=?Token, also 5 decimals point
    uint256 private _exchangeRatio;
    uint256 private _targetCollateralRatio;
    uint256 private _targetMinCollateralRatio;
    uint256 private _targetMaxCollateralRatio;
    uint256 private _useCollateralRatio;
    bool private _requireChangeExchangeRatio;
    // the new candiate exchange ratio
    uint256 private _requireExchangeRatio;
    uint256 private _friendTokenAmount;
    uint256 private _totalTokenAmount;
    uint256 private _currentCollateralRatio;
    PersonalToken private _personalToken;
    bool private _deprecated;
    FriendToken private _friendToken;

    modifier validDestination(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    constructor(
        address acceptedTokenAddr,
        uint256 initExchangeRatio,
        address ownerAddr
    ) public validDestination(acceptedTokenAddr) {
        _acceptedTokenAddr = acceptedTokenAddr;
        _exchangeRatio = initExchangeRatio;
        _targetCollateralRatio = 1.2 * 10**5;
        _targetMinCollateralRatio = 1.1 * 10**5;
        _targetMaxCollateralRatio = 1.3 * 10**5;
        _useCollateralRatio = _targetCollateralRatio;
        _requireChangeExchangeRatio = false;
        _friendTokenAmount = 0;
        _totalTokenAmount = 0;
        _personalToken = PersonalToken(msg.sender);
        _deprecated = false;
        _friendToken = FriendToken(acceptedTokenAddr);
        _currentCollateralRatio = _targetCollateralRatio;
        transferOwnership(ownerAddr);
    }

    function getRequireExchangeRatio() external view returns (uint256) {
        return _requireExchangeRatio;
    }

    function deprecated() external view returns (bool) {
        return _deprecated;
    }

    function useCollateralRatio() external view returns (uint256) {
        return _useCollateralRatio;
    }

    function currentCollateralRatio() external view returns (uint256) {
        return _currentCollateralRatio;
    }

    function exchangeRatio() external view returns (uint256) {
        return _exchangeRatio;
    }

    function cancelChangeExchangeRatio() external onlyOwner returns (bool) {
        require(
            _requireChangeExchangeRatio,
            "not require change exchange ratio"
        );
        _requireChangeExchangeRatio = false;
        return true;
    }

    function deprecateToggle() external onlyOwner {
        _deprecated = !_deprecated;
    }

    function cast(uint256 tokenAmount) external returns (bool) {
        require(!_deprecated);
        uint256 friendAmount =
            _tokenToFriend(tokenAmount, _exchangeRatio, _useCollateralRatio);
        _castToken(friendAmount, tokenAmount);
        return true;
    }

    function destroy(uint256 tokenAmount) external returns (bool) {
        uint256 friendAmount =
            _tokenToFriend(tokenAmount, _exchangeRatio, _useCollateralRatio);
        _destroyToken(friendAmount, tokenAmount);
        return true;
    }

    function stake(uint256 tokenAmount) external returns (bool) {
        require(
            _requireChangeExchangeRatio,
            "not in changing exchange ratio period"
        );
        uint256 friendAmount =
            _tokenToFriend(
                tokenAmount,
                _requireExchangeRatio,
                _useCollateralRatio
            );
        _castToken(friendAmount, tokenAmount);
        if (_requireExchangeRatio > _exchangeRatio) {
            if (
                _friendTokenAmount.mul(_requireExchangeRatio).div(
                    _totalTokenAmount
                ) <= _targetMaxCollateralRatio
            ) {
                _changeExchangeRatio();
            }
        } else if (_requireExchangeRatio < _exchangeRatio) {
            if (
                _friendTokenAmount.mul(_requireExchangeRatio).div(
                    _totalTokenAmount
                ) >= _targetMinCollateralRatio
            ) {
                _changeExchangeRatio();
            }
        }
        return true;
    }

    function requireChangeExchangeRatio(uint256 requireExchangeRatio)
        external
        onlyOwner
        returns (bool)
    {
        require(
            !_requireChangeExchangeRatio,
            "already require change exchange ratio"
        );
        require(
            requireExchangeRatio != _exchangeRatio,
            "cannot set the same exchange ratio"
        );
        _requireChangeExchangeRatio = true;
        _requireExchangeRatio = requireExchangeRatio;
        return true;
    }

    function rewardDistribute(address recipient, uint256 tokenAmount)
        external
        onlyOwner
        returns (bool)
    {
        _updateTokenAmount(0, tokenAmount, 1);
        _updateCollateral();
        _personalToken.mint(recipient, tokenAmount);
        return true;
    }

    /// @dev mint token and get friend token
    /// @notice need to check the msg.sender is not personaltoken address
    function _castToken(uint256 friendAmount, uint256 tokenAmount)
        internal
        returns (bool)
    {
        uint256 friendAllowance =
            _friendToken.allowance(msg.sender, address(this));
        uint256 friendBalance = _friendToken.balanceOf(msg.sender);
        require(
            friendAllowance >= friendAmount,
            "not enough FRIEND Token allowance"
        );
        require(
            friendBalance >= friendAmount,
            "not enough FRIEND Token balance"
        );
        _updateTokenAmount(friendAmount, tokenAmount, 1);
        _updateCollateral();
        _friendToken.transferFrom(msg.sender, address(this), friendAmount);
        _personalToken.mint(msg.sender, tokenAmount);
        return true;
    }

    function _destroyToken(uint256 friendAmount, uint256 tokenAmount)
        internal
        returns (bool)
    {
        uint256 tokenAllowance =
            _personalToken.allowance(msg.sender, address(this));
        uint256 tokenBalance = _personalToken.balanceOf(msg.sender);
        require(tokenBalance >= tokenAmount, "not enough Token allowance");
        require(tokenAllowance >= tokenAmount, "not enough Token balance");
        _updateTokenAmount(friendAmount, tokenAmount, 0);
        _updateCollateral();
        _personalToken.burn(msg.sender, tokenAmount);
        _friendToken.transfer(msg.sender, friendAmount);
        return true;
    }

    /// @dev updates _totalTokenAmount,_friendTokenAmount
    function _updateTokenAmount(
        uint256 friendAmount,
        uint256 tokenAmount,
        uint256 updateMode
    ) internal returns (bool) {
        if (updateMode == 1) {
            _totalTokenAmount += tokenAmount;
            _friendTokenAmount += friendAmount;
        } else if (updateMode == 0) {
            _totalTokenAmount -= tokenAmount;
            _friendTokenAmount -= friendAmount;
        }
        return true;
    }

    function _updateCollateral() internal returns (bool) {
        if (_friendTokenAmount == 0) {
            _currentCollateralRatio = _targetCollateralRatio;
        } else {
            _currentCollateralRatio = _friendTokenAmount
                .mul(_exchangeRatio)
                .div(_totalTokenAmount);
        }
        require(
            _currentCollateralRatio >= _targetMinCollateralRatio,
            "too little collateral"
        );
        _useCollateralRatio = _recaculateUseCollateralRatio(
            _currentCollateralRatio
        );
        return true;
    }

    /// @param ccr current collateral ratio
    function _recaculateUseCollateralRatio(uint256 ccr)
        internal
        view
        returns (uint256)
    {
        uint256 newCollateralRatio;
        if (_totalTokenAmount == 0) {
            newCollateralRatio = _targetCollateralRatio;
        } else {
            newCollateralRatio = _targetCollateralRatio.mul(2).sub(ccr);
        }
        if (newCollateralRatio < _targetCollateralRatio) {
            newCollateralRatio = _targetCollateralRatio;
        }
        return newCollateralRatio;
    }

    function _changeExchangeRatio() internal returns (bool) {
        _requireChangeExchangeRatio = false;
        _exchangeRatio = _requireExchangeRatio;
        _requireExchangeRatio = 0;
        _updateCollateral();
        return true;
    }

    ///@dev caculate the required amount of friend token
    /// library
    function _tokenToFriend(
        uint256 tokenAmount,
        uint256 exchangRatio,
        uint256 collateralRatio
    ) internal pure returns (uint256) {
        return collateralRatio.mul(tokenAmount).div(exchangRatio);
    }
}
