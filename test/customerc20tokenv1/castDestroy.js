// var contract = require("@truffle/contract");
// var contractJson = require("../artifacts/contracts/CustomERC20TokenV1.sol/CustomERC20TokenV1.json");
// var CustomERC20TokenV1 = contract(contractJson);

const { assert } = require("chai");

// const Artifactor = require("@truffle/artifactor");
const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");


contract("CustomERC20TokenV1", (accounts) => {
    it("should cast and destroy coin successfully", async () => {
        const instance = await CustomERC20TokenV1.new(
            0,
            "DAEE",
            "EE"
        );
        const friendToken = await CustomERC20TokenV1.new(
            web3.utils.toBN("20000"),
            "AATTUU",
            "ATU"
        );
        const accountOne = accounts[0];
        await instance.setFriendToken(friendToken.address, web3.utils.toBN(2.5 * 10 ** 5));
        await friendToken.increaseAllowance(instance.address, 100 * 1.2)

        // Casting
        const accountOneAEEStartingBalance = await instance.balanceOf(accountOne);
        const accountOneATUStartingBalance = await friendToken.balanceOf(accountOne);
        await instance.cast(250, friendToken.address);
        const accountOneAEEEndingBalance = await instance.balanceOf(accountOne);
        const accountOneATUEndingBalance = await friendToken.balanceOf(accountOne);
        assert.equal(
            accountOneAEEStartingBalance.toString(),
            (accountOneAEEEndingBalance.subn(250)).toString(),
            "Casting wrong number of token"
        );
        assert.equal(
            accountOneATUStartingBalance.toString(),
            accountOneATUEndingBalance.addn(120).toString(),
            "Staking wrong number of friend token"
        );

        //destroy
        await instance.increaseAllowance(instance.address, 250);
        await instance.destroy(250, friendToken.address);
        const accountOneAEEDestroyingBalance = await instance.balanceOf(accountOne);
        const accountOneATUDestroyingBalance = await friendToken.balanceOf(accountOne);
        assert.equal(
            accountOneAEEStartingBalance.toString(),
            accountOneAEEDestroyingBalance.toString(),
            "Destroy wrong number of tokens"
        );
        assert.equal(
            accountOneATUDestroyingBalance.toString(),
            accountOneATUStartingBalance.toString(),
            "Unstake wrong number of friend token"
        );
    });
});