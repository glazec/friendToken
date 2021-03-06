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
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Pool.sol";

/** @notice This token utilizes DAI like mechanics to rebalance. The base collateral ratio is 1.2x. Borrowing 1x TOKEN needs 1.2x FRIEND.
If the TOKEN price goes up, user has the incentive to stake FRIEND and get TOKEN.
If the TOKEN price goes down, user has the incentive to burn TOKEN and get FRIEND back.

The owner can increase the target price, which leads to the decrease of the total collateral(1.1x-1.2x). The contract will bump up the collateral ratio to rebase the total collateral to supply ratio.
Similarly to decrease the target price.

Let x be the total collateral/total supply, y be the current collateral ratio. 
Then y=0.1\cdot-\tan\left(8\left(x-1.2\right)\right)+1.2. It has follwoing points(1.1,1.303),(1.2,1.2),(1.3,1.097)

!! The total collateral/total supply should be within [1.1,1.3]

How to setup token icon
https://forum.openzeppelin.com/t/how-to-add-erc20-token-icon-to-etherscan/3491
 **/
contract CustomERC20TokenV1 is ERC20, ERC20Burnable, Ownable, AccessControl {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    //use EnumerateSet Openzeppelin
    EnumerableSet.AddressSet private _poolAddrSet;
    EnumerableSet.AddressSet private _acceptedTokenAddrSet;
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");

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
        require(!_poolAddrSet.contains(to));
        _;
    }

    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) public ERC20(tokenName, tokenSymbol) {
        // By default is 18 decimals
        _mint(msg.sender, initialSupply);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function pool() external view returns (address[] memory) {
        uint256 tokenListLength = _poolAddrSet.length();
        address[] memory _addr = new address[](tokenListLength);
        for (uint256 i = 0; i < tokenListLength; i++) {
            _addr[i] = _poolAddrSet.at(i);
        }
        return _addr;
    }

    function mint(address addr, uint256 amount)
        external
        validDestination(addr)
        returns (bool)
    {
        require(hasRole(POOL_ROLE, msg.sender), "Caller is not a pool");
        _mint(addr, amount);
        return true;
    }

    function burn(address addr, uint256 amount)
        external
        validDestination(addr)
        returns (bool)
    {
        require(hasRole(POOL_ROLE, msg.sender), "Caller is not a pool");
        _burn(addr, amount);
        return true;
    }

    function createPool(address friendTokenAddr, uint256 exchangeRatio)
        external
        validDestination(friendTokenAddr)
        onlyOwner
        returns (address)
    {
        Pool newPool = new Pool(friendTokenAddr, exchangeRatio);
        newPool.transferOwnership(msg.sender);
        _poolAddrSet.add(address(newPool));
        _acceptedTokenAddrSet.add(friendTokenAddr);
        grantRole(POOL_ROLE, address(newPool));
        return address(newPool);
    }
}
