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

/**@dev This token utilizes DAI like mechanics to rebalance. The base colletarl ratio is 1.2x. Borrowing 1x TOKEN needs 1.2x FRIEND.
If the TOKEN price goes up, user has the incentive to stake FRIEND and get TOKEN.
If the TOKEN price goes down, user has the incentive to burn TOKEN and get FRIEND back.

The owner can increase the target price, which leads to the decrease of the total colletarl(1.1x-1.2x). The contract will bump up the colletarl ratio to rebase the total colletarl to supply ratio.
Similarly to decrease the target price.

Let x be the total colletarl/total supply, y be the current colletarl ratio. 
Then y=0.1\cdot-\tan\left(8\left(x-1.2\right)\right)+1.2. It has follwoing points(1.1,1.303),(1.2,1.2),(1.3,1.097)

!! The total colletarl/total supply should be within [1.1,1.3]
 **/
contract CustomERC20TokenV1 is ERC20, ERC20Burnable, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    //use EnumerateSet Openzeppelin
    EnumerableSet.AddressSet private _acceptedTokenList;
    // 1 friend token=?Token, also 5 decimals point
    mapping(address => uint256) private _exchangeRatioMap;
    // The current colletaral raio with 5 decimals point
    uint256 private _collateralRaio;

    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) {
        // By default is 18 decimals
        _mint(msg.sender, initialSupply);
        _collateralRaio = 1.2 * 10**5;
    }

    function colletarlRatio() external view returns (uint256) {
        // 5 decimal points
        return _collateralRaio;
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

    function setFriendToken(address _addr, uint256 _ratio) external onlyOwner {
        require(_addr != address(this));
        require(_addr != address(this));
        _acceptedTokenList.add(_addr);
        _exchangeRatioMap[_addr] = _ratio;
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

    function removeFriendToken(address _addr) external onlyOwner {
        _acceptedTokenList.remove(_addr);
        delete _exchangeRatioMap[_addr];
    }

    function cast(uint256 _amount, address _friendTokenaddr) external {
        require(_acceptedTokenList.length() >= 1);
        require(_acceptedTokenList.contains(_friendTokenaddr));
        // check allowance,balance,transfer,mint
        uint256 _ratio = _exchangeRatioMap[_friendTokenaddr];
        FriendToken _friendToken = FriendToken(_friendTokenaddr);
        uint256 _allowance = _friendToken.allowance(msg.sender, address(this));
        uint256 _balance = _friendToken.balanceOf(msg.sender);
        require(
            _allowance >= _collateralRaio.mul(_amount).div(_ratio),
            "not enough FRIEND Token allowance"
        );
        require(
            _balance >= _collateralRaio.mul(_amount).div(_ratio),
            "not enough FRIEND Token balance"
        );
        _friendToken.transferFrom(
            msg.sender,
            address(this),
            _collateralRaio.mul(_amount).div(_ratio)
        );
        _mint(msg.sender, _amount);
        //emit event
    }

    function destroy(uint256 _amount, address _addr) external {
        uint256 _allowance = allowance(msg.sender, address(this));
        uint256 _balance = balanceOf(msg.sender);
        require(_allowance >= _amount);
        require(_balance >= _amount);
        require(_acceptedTokenList.contains(_addr), "unaccepted FRIEND");
        FriendToken _friendToken = FriendToken(_addr);
        uint256 _ratio = _exchangeRatioMap[_addr];
        require(
            _friendToken.balanceOf(address(this)) >=
                _amount.div(_ratio).mul(_collateralRaio)
        );
        _burn(msg.sender, _amount);
        _friendToken.transfer(
            msg.sender,
            _collateralRaio.mul(_amount).div(_ratio)
        );
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
