const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");

module.exports = function(deployer) {
  deployer.deploy(FaceToken).then(function() {
    deployer.deploy(FaceWorthPollFactory, FaceToken.address);
  });
};
