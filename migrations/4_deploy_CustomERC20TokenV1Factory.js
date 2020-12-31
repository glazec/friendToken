const CustomERC20TokenV1Factory = artifacts.require("CustomERC20TokenV1Factory");

module.exports = function (deployer) {
    deployer.deploy(
        CustomERC20TokenV1Factory,
    );
};
