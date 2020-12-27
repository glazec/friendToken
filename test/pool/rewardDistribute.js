const { assert } = require("chai");

const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");

const Pool = artifacts.require("Pool");
const truffleAssert = require('truffle-assertions');

contract("CustomERC20TokenV1", (accounts) => {
    it("reward distribution", async () => {
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
        await instance.createPool(friendToken.address, web3.utils.toBN(2.5 * 10 ** 5));
        const poolAddr = (await instance.pool())[0]
        let pool = await Pool.at(poolAddr.toString());

        const accountOne = accounts[0];
        const accountTwo = accounts[1];
        await friendToken.increaseAllowance(poolAddr, 200 * 1.2)
        await instance.increaseAllowance(poolAddr, 250)
        //casting
        await pool.cast(250);
        truffleAssert.reverts(pool.rewardDistribute(accountOne, 24));
        await pool.rewardDistribute(accountOne, 22);
        assert.equal((await instance.balanceOf(accountOne)).toNumber(), 272);



    });

});