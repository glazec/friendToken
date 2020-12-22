// contracts/CustomERC20TokenV1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaCoin is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Meta Coin", "Meta") {
        // By default is 18 decimals
        _mint(msg.sender, 2000 * 10**18);
    }
}
