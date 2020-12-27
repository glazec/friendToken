const { assert } = require("chai");

const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");

const Pool = artifacts.require("Pool");
const truffleAssert = require('truffle-assertions');

contract("CustomERC20TokenV1", (accounts) => {
    it("cast and destroy", async () => {
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
        await friendToken.increaseAllowance(poolAddr, 100 * 1.2)

        //casting
        const accountOneAEEStartingBalance = await instance.balanceOf(accountOne);
        const accountOneATUStartingBalance = await friendToken.balanceOf(accountOne);
        await pool.cast(250);
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

        // destroy
        await instance.increaseAllowance(poolAddr, 250);
        await pool.destroy(250);
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