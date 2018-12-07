const FaceToken = artifacts.require("../contracts/FaceToken.sol");

module.exports = function(deployer) {
  deployer.deploy(FaceToken);
};
