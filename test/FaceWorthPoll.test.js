const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");
const Tronweb = require("tronweb");

contract('FaceWorthPollFactory', async (accounts) => {

  let faceToken;
  let factory;

  beforeEach(async () => {
    // factory = await FaceWorthPollFactory.deployed();
    // faceToken = await FaceToken.deployed();
  });

  it("faceTokenRewardPool is 80 percent of FaceToken totalSupply", async () => {
    factory = await FaceWorthPollFactory.deployed();
    faceToken = await FaceToken.deployed();
    let totalSupplyInSun = await faceToken.totalSupply();
    let decimals = await faceToken.decimals();
    let totalSupply = totalSupplyInSun / (10 ** decimals);
    let eightyPercentOfTotalSupply = totalSupply * 8 / 10;
    let faceTokenRewardPoolInSun = await factory.faceTokenRewardPool();
    let faceTokenRewardPool = faceTokenRewardPoolInSun / (10 ** decimals);
    assert.equal(eightyPercentOfTotalSupply, faceTokenRewardPool, "faceTokenRewardPool wasn't 80 percent of FaceToken totalSupply");
  });

  it("FaceWorthPoll contract is created successfully", async () => {
    factory = await FaceWorthPollFactory.deployed();
    faceToken = await FaceToken.deployed();

    let faceHash = Tronweb.sha3("Some face photo", true);
    let blocksBeforeReveal = 10; // min number of blocks
    let blocksBeforeEnd = 10;
    let hash = await factory.createFaceWorthPoll(faceHash, blocksBeforeReveal, blocksBeforeEnd);
    console.log("Poll hash", hash);

    let pollCount = await factory.pollCount();
    console.log(pollCount);
    assert.equal(pollCount, 1, "pollCount wasn't 1 after 1 poll is created");

    let score = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    let saltedWorthHash = Tronweb.sha3("中文-" + score[0], true);
    await factory.commit(hash, saltedWorthHash);
    // for (let i = 1; i < 10; i++) {
    //   await factory.checkBlockNumber(hash).send({
    //     feeLimit: 1000000000,
    //     callValue: 0,
    //     shouldPollResponse: true
    //   });
    // }
    let currentStage = await factory.getCurrentStage(hash);
    console.log("Current Stage", currentStage);
    //
    // await poll.checkBlockNumber();
    //
    // for (let i = 0; i < accounts.length; i++) {
    //   await poll.reveal("中文-", score[i], {from: accounts[i]});
    // }
    //
    // await poll.checkBlockNumber();
    //
    // let winners = await poll.getWinners();
    // for (let i = 0; i < winners.length; i++) {
    //   let worth = await poll.getWorthBy(winners[i]);
    //   console.log(winners[i], worth);
    // }
    //
    // let approvalEvent = faceToken.Approval();
    // let approvalCount = 0;
    // let loserCount = accounts.length - winners.length;
    // approvalEvent.watch((err, response) => {
    //   approvalCount++;
    //   console.log("Approval", response.args);
    //   if (approvalCount === loserCount) {
    //     approvalEvent.stopWatching();
    //   }
    // });
  })
});