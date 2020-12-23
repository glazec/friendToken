// var contract = require("@truffle/contract");
// var contractJson = require("../artifacts/contracts/CustomERC20TokenV1.sol/CustomERC20TokenV1.json");
// var CustomERC20TokenV1 = contract(contractJson);

const { assert } = require("chai");

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

    //check total supply
    const beginningSupply = await instance.totalSupply();
    const beginningTotalCollateral = await instance.totalCollateral();
    const beginningCollateralOfATU = await instance.collateralOf(friendToken.address);
    const beginningCurrentCollateralRatio = await instance.currentCollateralRatio();
    const beginningCollateralRatio = await instance.collateralRatio();
    assert.equal(beginningSupply.toString(), '0', 'wrong beginning total supply');
    assert.equal(beginningTotalCollateral.toString(), '0', 'wrong beginning total collateral');
    assert.equal(beginningCollateralOfATU.toString(), '0', 'wrong collateral amount of ATU');
    assert.equal(beginningCurrentCollateralRatio.toString(), 0, 'wrong updated collateral ratio');
    assert.equal(beginningCollateralRatio.toString(), (1.2 * 10 ** 5).toString(), 'wrong collateral ratio in used');

    // Casting
    await instance.cast(250, friendToken.address);
    const afterCastingSupply = await instance.totalSupply();
    const afterCastingTotalCollateral = await instance.totalCollateral();
    const afterCastingCollateralOfATU = await instance.collateralOf(friendToken.address);
    const afterCastingCurrentCollateralRatio = await instance.currentCollateralRatio();
    const afterCastingCollateralRatio = await instance.collateralRatio();
    assert.equal(afterCastingSupply.toString(), '250', 'wrong total supply after casting');
    assert.equal(afterCastingTotalCollateral.toString(), '300', 'wrong total collateral after casting');
    assert.equal(afterCastingCollateralOfATU.toString(), '120', 'wrong collateral amount of ATU');
    assert.equal(afterCastingCurrentCollateralRatio.toNumber(), Math.round(300 / 250 * 10 ** 5), 'wrong updated collateral ratio after casting');
    assert.equal(afterCastingCollateralRatio.toString(), (1.2 * 10 ** 5).toString(), 'wrong collateral ratio in used after casting');

    //destroy
    await instance.increaseAllowance(instance.address, 250);
    await instance.destroy(250, friendToken.address);
    const afterDestroyingSupply = await instance.totalSupply();
    const afterDestroyingTotalCollateral = await instance.totalCollateral();
    const afterDestroyingCollateralOfATU = await instance.collateralOf(friendToken.address);
    const afterDestroyingCurrentCollateralRatio = await instance.currentCollateralRatio();
    const afterDestroyingCollateralRatio = await instance.collateralRatio();
    assert.equal(afterDestroyingSupply.toString(), '0', 'wrong total supply after Destroying');
    assert.equal(afterDestroyingTotalCollateral.toString(), '0', 'wrong total collateral after Destroying');
    assert.equal(afterDestroyingCollateralOfATU.toString(), '0', 'wrong collateral amount of ATU');
    assert.equal(afterDestroyingCurrentCollateralRatio.toString(), (0).toString(), 'wrong updated collateral ratio after Destroying');
    assert.equal(afterDestroyingCollateralRatio.toString(), (1.2 * 10 ** 5).toString(), 'wrong collateral ratio in used after Destroying');
  });
});
