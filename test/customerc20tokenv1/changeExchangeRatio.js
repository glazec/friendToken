// var contract = require("@truffle/contract");
// var contractJson = require("../artifacts/contracts/CustomERC20TokenV1.sol/CustomERC20TokenV1.json");
// var CustomERC20TokenV1 = contract(contractJson);

const { assert } = require("chai");
const truffleAssert = require('truffle-assertions');


// const Artifactor = require("@truffle/artifactor");
const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");


contract("CustomERC20TokenV1", (accounts) => {
    it("should increase ratio", async () => {
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
        await instance.cast(250, friendToken.address); 
        truffleAssert.reverts(instance.cancelRequireChangeExchangeRatio());
        truffleAssert.reverts(instance.stake(friendToken.address,10));

        // want to increase exchange ratio
        await instance.requireChangeExchangeRatio(friendToken.address,web3.utils.toBN(11*10**4));
        const beginningCollateralRatio = await instance.collateralRatio();
        assert.equal(beginningCollateralRatio.toNumber(),1.2*10**5,'Wrong collateral ratio after requiring changing exchange ratio');

        //stake token
        //need to cast extra 3/7 if want to increase exchange 10%
        //with 1.2 collateral, bump up 5% immediately.
        await friendToken.increaseAllowance(instance.address, 12)
        await instance.stake(friendToken.address, web3.utils.toBN(25));
        const endingCurrentCollateralRatio = await instance.currentCollateralRatio();
        const endingCollateralRatio = await instance.collateralRatio();
        assert.equal(endingCurrentCollateralRatio.toNumber(),109818,'Wrong current collateral ratio')
        // assert.equal(endingCollateralRatio.toNumber(),130182)

        });
});