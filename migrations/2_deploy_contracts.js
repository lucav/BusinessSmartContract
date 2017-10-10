var IterableMappingLib = artifacts.require("IterableMappingLib.sol");
var Business = artifacts.require("Business.sol");
var DateTimeLib = artifacts.require("DateTimeLib.sol");

module.exports = function(deployer) {
  deployer.deploy(IterableMappingLib);
  deployer.link(IterableMappingLib, Business);
  deployer.deploy(DateTimeLib);
  deployer.link(DateTimeLib, Business);
  deployer.deploy(Business, 100, 51, 120);
};
