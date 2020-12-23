// contracts/CustomERC20TokenV1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";

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

/** @notice This token utilizes DAI like mechanics to rebalance. The base collateral ratio is 1.2x. Borrowing 1x TOKEN needs 1.2x FRIEND.
If the TOKEN price goes up, user has the incentive to stake FRIEND and get TOKEN.
If the TOKEN price goes down, user has the incentive to burn TOKEN and get FRIEND back.

The owner can increase the target price, which leads to the decrease of the total collateral(1.1x-1.2x). The contract will bump up the collateral ratio to rebase the total collateral to supply ratio.
Similarly to decrease the target price.

Let x be the total collateral/total supply, y be the current collateral ratio. 
Then y=0.1\cdot-\tan\left(8\left(x-1.2\right)\right)+1.2. It has follwoing points(1.1,1.303),(1.2,1.2),(1.3,1.097)

!! The total collateral/total supply should be within [1.1,1.3]
 **/
contract CustomERC20TokenV1 is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    //use EnumerateSet Openzeppelin
    EnumerableSet.AddressSet private _acceptedTokenList;
    // 1 friend token=?Token, also 5 decimals point
    mapping(address => uint256) private _exchangeRatioMap;
    // The collateral ratio used to caculate collateral with 5 decimals point
    uint256 private _collateralRatio;
    uint256 private _totalSupply;
    uint256 private _totalCollateral;
    // The up to date collateral ratio with 5 decimals point
    uint256 private _currentCollateralRatio;
    mapping(address => uint256) private _collateralAmountMap;
    uint256 private constant _minCollateralRatio = 1.1 * 10**5;

    event Casted(
        uint256 friendTokenAmount,
        uint256 tokenAmount,
        address friendTokenAddress,
        address sender
    );
    event Destroyed(
        uint256 friendTokenAmount,
        uint256 tokenAmount,
        address friendTokenAddress,
        address sender
    );
    event CurrentCollateralRatio(uint256 currentCollateralRatio);
    event Rewarded(address recipient,uint256 amount);

    modifier validDestination(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) {
        // By default is 18 decimals
        _mint(msg.sender, initialSupply);
        _collateralRatio = 1.2 * 10**5;
    }

    function collateralRatio() external view returns (uint256) {
        // 5 decimal points
        return _collateralRatio;
    }

    function collateralOf(address addr) external view returns (uint256) {
        // 18 decimals
        return _collateralAmountMap[addr];
    }

    function currentCollateralRatio() external view returns (uint256) {
        return _currentCollateralRatio;
    }

    function totalCollateral() external view returns (uint256) {
        return _totalCollateral;
    }

    function acceptedTokenList() external view returns (address[] memory) {
        uint256 tokenListLength = _acceptedTokenList.length();
        address[] memory _addr = new address[](tokenListLength);
        for (uint256 i = 0; i < _acceptedTokenList.length(); i++) {
            _addr[i] = _acceptedTokenList.at(i);
        }
        return _addr;
    }

    function exchangeRatioMap(address _addr) external view returns (uint256) {
        return _exchangeRatioMap[_addr];
    }

    function setFriendToken(address addr, uint256 ratio) external onlyOwner {
        require(addr != address(this));
        require(addr != address(this));
        _acceptedTokenList.add(addr);
        _exchangeRatioMap[addr] = ratio;
        // bool _repeated = false;
        // for (uint256 i = 0; i < _acceptedTokenList.length(); i++) {
        //     if (_addr == _acceptedTokenList.at(i)) {
        //         _repeated = true;
        //     }
        // }
        // if (!_repeated) {
        //     _acceptedTokenList.add(_addr);
        // }
        // _exchangeRatioMap[_addr] = _ratio;
    }

    function removeFriendToken(address addr) external onlyOwner {
        _acceptedTokenList.remove(addr);
        delete _exchangeRatioMap[addr];
    }

    /// @param addr friendToken address
    function cast(uint256 amount, address addr) external {
        require(_acceptedTokenList.length() >= 1);
        require(_acceptedTokenList.contains(addr));
        // check allowance,balance,transfer,mint
        uint256 ratio = _exchangeRatioMap[addr];
        FriendToken friendToken = FriendToken(addr);
        uint256 friendAllowance =
            friendToken.allowance(msg.sender, address(this));
        uint256 balance = friendToken.balanceOf(msg.sender);
        require(
            friendAllowance >= _collateralRatio.mul(amount).div(ratio),
            "not enough FRIEND Token allowance"
        );
        require(
            balance >= _collateralRatio.mul(amount).div(ratio),
            "not enough FRIEND Token balance"
        );
        friendToken.transferFrom(
            msg.sender,
            address(this),
            _collateralRatio.mul(amount).div(ratio)
        );
        _mint(msg.sender, amount);
        _totalSupply += amount;
        _collateralAmountMap[addr] += _collateralRatio.mul(amount).div(ratio);
        _totalCollateral += _collateralRatio.mul(amount).div(10**5);
        _currentCollateralRatio = _totalCollateral.mul(10**5).div(
            totalSupply()
        );
        emit Casted(
            _collateralRatio.mul(amount).div(ratio),
            amount,
            addr,
            msg.sender
        );
        emit CurrentCollateralRatio(_currentCollateralRatio);
    }

    function destroy(uint256 amount, address addr) external {
        uint256 _allowance = allowance(msg.sender, address(this));
        uint256 _balance = balanceOf(msg.sender);
        require(_allowance >= amount);
        require(_balance >= amount);
        require(_acceptedTokenList.contains(addr), "unaccepted FRIEND");
        FriendToken friendToken = FriendToken(addr);
        uint256 ratio = _exchangeRatioMap[addr];
        require(
            friendToken.balanceOf(address(this)) >=
                _collateralRatio.mul(amount).div(ratio)
        );
        _burn(msg.sender, amount);
        friendToken.transfer(
            msg.sender,
            _collateralRatio.mul(amount).div(ratio)
        );
        _totalSupply -= amount;
        _collateralAmountMap[addr] -= _collateralRatio.mul(amount).div(ratio);
        _totalCollateral -= _collateralRatio.mul(amount).div(10**5);
        _currentCollateralRatio = _totalCollateral.mul(10**5).div(
            totalSupply()
        );
        emit Destroyed(
            _collateralRatio.mul(amount).div(ratio),
            amount,
            addr,
            msg.sender
        );
        emit CurrentCollateralRatio(_currentCollateralRatio);
    }
    
    function rewardDistribution(address recipient, uint256 amount)
        external
        validDestination(recipient)
    {
        require(
            _totalCollateral.mul(10**5).div(totalSupply().add(amount)) >
                _minCollateralRatio,
            "Too little Collateral"
        );
        _mint(recipient, amount);
        emit Rewarded(recipient, amount);
    }
}
