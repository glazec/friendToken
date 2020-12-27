const { assert } = require("chai");

const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");
const truffleAssert = require('truffle-assertions');

contract("CustomERC20TokenV1", (accounts) => {
    it("burn", async () => {
        const instance = await CustomERC20TokenV1.new(
            web3.utils.toBN("300"),
            "DAEE",
            "EE"
        );
        const accountOne = accounts[0];

        await instance.increaseAllowance(instance.address, 100);
        truffleAssert.reverts(instance.burn(accountOne, 100,))
    });
    it("mint", async () => {
        const instance = await CustomERC20TokenV1.new(
            web3.utils.toBN("300"),
            "DAEE",
            "EE"
        );
        const accountOne = accounts[0];
        truffleAssert.reverts(instance.mint(accountOne, 100))
        assert.equal((await instance.balanceOf(accountOne)).toNumber(),300)
    });
});
