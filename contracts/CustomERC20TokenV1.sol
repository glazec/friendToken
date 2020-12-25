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
    uint256 private _totalCollateral;
    // The up to date collateral ratio with 5 decimals point
    uint256 private _currentCollateralRatio;
    uint256 private _requireExchangeRatio;
    bool private _changeExchangeRatioState;
    address private _changeExchangeRatioAddress;
    // FRIEND amound
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
    event Rewarded(address recipient, uint256 amount);
    event CollateralRatioRebase(uint256 ratio);
    event UpdateExchangeRatio(address addr, uint256 ratio);

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
        _castToken(addr, amount, ratio);
    }

    function destroy(uint256 amount, address addr) external {
        // use min(_collateralRatio,_currentCollateralRatio) to destroy
        // use _currentCollateralRatio to destory
        uint256 token_allowance = allowance(msg.sender, address(this));
        uint256 token_balance = balanceOf(msg.sender);
        uint256 returnRatio = 1.2 * 10**5;
        if (_currentCollateralRatio <= 1.2 * 10**5) {
            returnRatio = _currentCollateralRatio;
        }
        require(token_allowance >= amount);
        require(token_balance >= amount);
        require(_acceptedTokenList.contains(addr), "unaccepted FRIEND");
        FriendToken friendToken = FriendToken(addr);
        uint256 ratio = _exchangeRatioMap[addr];
        require(
            friendToken.balanceOf(address(this)) >=
                returnRatio.mul(amount).div(ratio)
        );
        _burn(msg.sender, amount);
        friendToken.transfer(msg.sender, returnRatio.mul(amount).div(ratio));
        _collateralAmountMap[addr] -= returnRatio.mul(amount).div(ratio);
        _totalCollateral -= returnRatio.mul(amount).div(10**5);
        if (totalSupply() == 0) {
            _currentCollateralRatio = 0;
        } else {
            _currentCollateralRatio = _totalCollateral.mul(10**5).div(
                totalSupply()
            );
        }
        _recaculateCollateralRatio();
        emit Destroyed(
            returnRatio.mul(amount).div(ratio),
            amount,
            addr,
            msg.sender
        );
        // emit CurrentCollateralRatio(_currentCollateralRatio);
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
        _currentCollateralRatio = _totalCollateral.mul(10**5).div(
            totalSupply()
        );
        _recaculateCollateralRatio();
        emit Rewarded(recipient, amount);
    }

    function _recaculateCollateralRatio() internal {
        _collateralRatio = 1.2 * 10**5 * 2 - _currentCollateralRatio;
        if (_collateralRatio < 1.2 * 10**5 || totalSupply() == 0) {
            _collateralRatio = 1.2 * 10**5;
        }
        emit CollateralRatioRebase(_collateralRatio);
    }

    /// @notice change exchangeRatio require to check global currentcollateralRatio
    function _changeExchangeRatio() internal {
        require(_checkCollateralRatio(), "Not satisfy prerequisites");
        _exchangeRatioMap[_changeExchangeRatioAddress] = _exchangeRatioMap[
            _changeExchangeRatioAddress
        ]
            .mul(_requireExchangeRatio)
            .div(10**5);
        _totalCollateral =
            _totalCollateral.mul(10**5).div(_requireExchangeRatio);
        _currentCollateralRatio = _totalCollateral.mul(10**5).div(totalSupply());
        _recaculateCollateralRatio();
        _changeExchangeRatioState = false;
        emit UpdateExchangeRatio(
            _changeExchangeRatioAddress,
            _requireExchangeRatio
        );
    }

    function requireChangeExchangeRatio(address addr, uint256 ratio)
        external
        onlyOwner
    {
        require(
            _changeExchangeRatioState == false,
            "Yor are already changing exchange ratio"
        );
        _requireExchangeRatio = ratio;
        _changeExchangeRatioState = true;
        _changeExchangeRatioAddress = addr;
        if (_checkCollateralRatio()) {
            _changeExchangeRatio();
        }
    }

    function cancelRequireChangeExchangeRatio() public onlyOwner {
        require(_changeExchangeRatioState == true, "No ongoing changes");
        _changeExchangeRatioState = false;
    }

    function stake(address addr, uint256 amount) external {
        require(_changeExchangeRatioState,'You are not changing exchange ratio');
        uint256 ratio =
            _requireExchangeRatio
                .mul(_exchangeRatioMap[addr])
                .mul(0.98 * 10**5)
                .div(10**10);
        console.log(ratio);
        console.log('Before stake',_currentCollateralRatio);
        _castToken(addr, amount, ratio);
        console.log('current collateral ratio',_currentCollateralRatio);
        console.log('if increase exchange ratio, the current collateral ratio is',_currentCollateralRatio.mul(10**5).div(_requireExchangeRatio));
        console.log(_collateralAmountMap[addr].mul(10**5).mul(_exchangeRatioMap[addr]).div(_requireExchangeRatio).div(totalSupply()));
        if (_checkCollateralRatio()) {
            _changeExchangeRatio();
        }
    }

    ///@notice This is used as the prerequisites for changing exchange ratio
    function _checkCollateralRatio() internal view returns (bool) {
        if (_requireExchangeRatio >= 1 * 10**5) {
            if (
                _currentCollateralRatio.mul(10**5).div(_requireExchangeRatio) >
                1.1 * 10**5
            ) {
                return true;
            }
        } else if (_requireExchangeRatio < 1 * 10**5) {
            if (
                _currentCollateralRatio.mul(10**5).div(_requireExchangeRatio) <
                1.3 * 10**5 
            ) {
                return true;
            }
        }
        return false;
    }

    function _castToken(
        address addr,
        uint256 amount,
        uint256 ratio
    ) internal returns (bool) {
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
        _collateralAmountMap[addr] += _collateralRatio.mul(amount).div(ratio);
        if (_changeExchangeRatioState){
            _totalCollateral += _collateralRatio.mul(amount).mul(_requireExchangeRatio).div(10**5).mul(ratio).div(10**10);
        }
        else{
        _totalCollateral += _collateralRatio.mul(amount).div(10**5);
        }
        _currentCollateralRatio = _totalCollateral.mul(10**5).div(
            totalSupply()
        );
        _recaculateCollateralRatio();
        // console.log('overflow','_collateralRatio);
        emit Casted(
            _collateralRatio.mul(amount).div(ratio),
            amount,
            addr,
            msg.sender
        );
        emit CurrentCollateralRatio(_currentCollateralRatio);
        return true;
    }
}
