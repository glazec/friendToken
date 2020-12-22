// contracts/CustomERC20TokenV1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract CustomERC20TokenV1 is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    //use EnumerateSet Openzeppelin
    address[] private _acceptedTokenList;
    // 1 friend token=? this token
    mapping(address => uint256) private _exchangeRatioList;

    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) {
        // By default is 18 decimals
        _mint(msg.sender, initialSupply);
    }

    function acceptedTokenList() public view returns (address[] memory) {
        return _acceptedTokenList;
    }

    function exchangeRatioList(address _addr) public view returns (uint256) {
        return _exchangeRatioList[_addr];
    }

    function setFriendToken(address _addr, uint256 _ratio) public onlyOwner {
        bool _repeated = false;
        for (uint256 i = 0; i < _acceptedTokenList.length; i++) {
            if (_addr == _acceptedTokenList[i]) {
                _repeated = true;
            }
        }
        if (!_repeated) {
            _acceptedTokenList.push(_addr);
        }
        _exchangeRatioList[_addr] = _ratio;
    }

    function removeFriendToken(address _addr) public onlyOwner {
        for (uint256 i = 0; i < _acceptedTokenList.length; i++) {
            if (_addr == _acceptedTokenList[i]) {
                _acceptedTokenList[i] = _acceptedTokenList[
                    _acceptedTokenList.length - 1
                ];
                _acceptedTokenList.pop();
                break;
            }
        }
        delete _exchangeRatioList[_addr];
    }

    function cast(uint256 _amount) public {
        require(_acceptedTokenList.length >= 1);
        // check allowance,balance,transfer,mint
        for (uint256 i = 0; i < _acceptedTokenList.length; i++) {
            address _addr = _acceptedTokenList[i];
            uint256 _ratio = _exchangeRatioList[_addr];
            FriendToken _friendToken = FriendToken(_addr);
            uint256 _allowance =
                _friendToken.allowance(msg.sender, address(this));
            uint256 _balance = _friendToken.balanceOf(msg.sender);
            require(
                _allowance >= _amount.div(_ratio).div(_acceptedTokenList.length)
            );
            require(
                _balance >= _amount.div(_ratio).div(_acceptedTokenList.length)
            );
            _friendToken.transferFrom(
                msg.sender,
                address(this),
                _amount.div(_ratio).div(_acceptedTokenList.length)
            );
            _mint(msg.sender, _amount);
        }
        //emit event
    }

    function destroy(uint256 _amount) public {
        uint256 _allowance = allowance(msg.sender, address(this));
        uint256 _balance = balanceOf(msg.sender);
        require(_allowance >= _amount);
        require(_balance > _amount);
        _burn(msg.sender, _amount);
        for (uint256 i = 0; i < _acceptedTokenList.length; i++) {
            address _addr = _acceptedTokenList[i];
            uint256 _ratio = _exchangeRatioList[_addr];
            FriendToken _friendToken = FriendToken(_addr);
            _friendToken.transfer(
                msg.sender,
                _amount.div(_ratio).div(_acceptedTokenList.length)
            );
        }
        //emit event
    }
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
