// contracts/CustomERC20TokenV1Factory
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
import "./CustomERC20TokenV1.sol";

contract CustomERC20TokenV1Factory {
    event CreateToken(
        address from,
        address tokenAddr,
        string name,
        string symbol
    );

    function createToken(string memory name, string memory symbol)
        public
        returns (address)
    {
        CustomERC20TokenV1 token = new CustomERC20TokenV1(0, name, symbol);
        token.transferOwnership(msg.sender);
        emit CreateToken(msg.sender, address(token), name, symbol);
        return address(token);
    }
}
