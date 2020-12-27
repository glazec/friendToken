const { assert } = require("chai");

const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");

const Pool = artifacts.require("Pool");
const truffleAssert = require('truffle-assertions');

contract("CustomERC20TokenV1", (accounts) => {
    it("change exchange ratio", async () => {
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
        await friendToken.increaseAllowance(poolAddr, 2000 * 1.2)
        await instance.increaseAllowance(poolAddr, 250)
        //casting
        await pool.cast(25);
        truffleAssert.reverts(pool.stake(20));
        //require change
        await pool.requireChangeExchangeRatio(web3.utils.toBN(2 * 10 ** 5));
        await pool.stake(50);
        const endingExchangeRatio = await pool.exchangeRatio();
        assert.equal(endingExchangeRatio.toNumber(), 2 * 10 ** 5, 'Not updating exchange ratio');
        truffleAssert.reverts(pool.cancelChangeExchangeRatio());
        assert.equal((await pool.getRequireExchangeRatio()).toNumber(), 0)
        // console.log((await pool.currentCollateralRatio()).toNumber())
        // console.log((await pool.useCollateralRatio()).toNumber())

    });

});