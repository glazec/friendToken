const CustomERC20TokenV1 = artifacts.require("CustomERC20TokenV1");
const ERC20 = artifacts.require("openzeppelin/contracts/token/ERC20/ERC20");

module.exports = function (deployer) {
  //   deployer.deploy(ERC20);
  //   deployer.link(ERC20, GLDToken);
  deployer.deploy(
    CustomERC20TokenV1,
    web3.utils.toBN("0"),
    "DAEE",
    "EE"
  );
};
