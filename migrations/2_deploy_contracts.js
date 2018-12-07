const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");

module.exports = function(deployer) {
  deployer.deploy(FaceToken, "419d9E55aBbf526Ad4117ccBF08aeD1A2611124CbC").then(function() {
    deployer.deploy(FaceWorthPollFactory, FaceToken.address);
  });
};
