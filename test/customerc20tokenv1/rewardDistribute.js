// var contract = require("@truffle/contract");
// var contractJson = require("../artifacts/contracts/CustomERC20TokenV1.sol/CustomERC20TokenV1.json");
// var CustomERC20TokenV1 = contract(contractJson);

const { assert } = require("chai");
const truffleAssert = require('truffle-assertions');

// const Artifactor = require("@truffle/artifactor");
const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");


contract("CustomERC20TokenV1", (accounts) => {
    it("Correct Collateral Calculation in cast and destroy", async () => {
        const instance = await CustomERC20TokenV1.new(
            web3.utils.toBN("0"),
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
        await instance.cast(250, friendToken.address);

        //reward
        await instance.rewardDistribution(accountOne,20);
        const afterRewardBalance = await instance.balanceOf(accountOne);
        assert.equal(afterRewardBalance.toString(),'270');
        await truffleAssert.reverts(instance.rewardDistribution(accountOne, 15));

    });
});
