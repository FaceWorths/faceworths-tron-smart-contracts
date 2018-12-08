const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");
const Tronweb = require("tronweb");
const sleep = require('sleep')

contract('FaceWorthPollFactory', async (accounts) => {

  let faceToken;
  let factory;
  let factoryContract;

  beforeEach(async () => {
    factory = await FaceWorthPollFactory.deployed();
    faceToken = await FaceToken.deployed();
    await factory.setFaceTokenAddress(faceToken.address);
    factoryContract = await tronWeb.contract().at(factory.address);
  });

  it("faceTokenRewardPool is 61.8 percent of FaceToken totalSupply", async () => {
    let totalSupplyInSun = await faceToken.totalSupply();
    let decimals = await faceToken.decimals();
    let totalSupply = totalSupplyInSun / (10 ** decimals);
    let eightyPercentOfTotalSupply = totalSupply * 618 / 1000;
    let faceTokenRewardPoolInSun = await factory.faceTokenRewardPool();
    let faceTokenRewardPool = faceTokenRewardPoolInSun / (10 ** decimals);
    assert.equal(eightyPercentOfTotalSupply, faceTokenRewardPool, "faceTokenRewardPool wasn't 61.8 percent of FaceToken totalSupply");
  });

  it("FaceWorthPoll contract is created successfully", async () => {

    let faceHash = Tronweb.sha3("Some face photo", true);
    let blocksBeforeReveal = 10; // min number of blocks
    let blocksBeforeEnd = 10;
    let balance = await tronWeb.trx.getBalance();
    console.log("balance 1", balance);
    let stake = await factory.stake();
    console.log("stake", stake);
    let currentBlock = await tronWeb.trx.getCurrentBlock();
    console.log("current block", currentBlock);
    let tx = await factory.createFaceWorthPoll(faceHash, blocksBeforeReveal, blocksBeforeEnd);
    let contractBalance = await factory.getBalance();
    console.log("Contract Balance", contractBalance);
    sleep.sleep(3);
    // currentBlock = await tronWeb.trx.getCurrentBlock();
    // console.log("current block", currentBlock);

    tronWeb.getEventByTransactionID(tx, async (err, response) => {
      if (response && response.length > 0) {
        let hash = '0x' + response[0].result.hash;
        console.log('face poll hash', hash);

        await factoryContract.checkBlockNumber(hash).send({
          feeLimit: 1000000000,
          callValue: 0,
          shouldPollResponse: false
        });

        let saltedWorthHash = Tronweb.sha3("中文-" + 8, true);
        await factoryContract.commit(hash, saltedWorthHash).send({
          feeLimit: 1000000000,
          callValue: stake,
          shouldPollResponse: false
        });
        sleep.sleep(3);
        contractBalance = await factory.getBalance();
        console.log("Contract Balance", contractBalance);
        let numberOfParticipants = await factory.getNumberOfParticipants(hash);
        console.log("number of participants", numberOfParticipants);
        balance = await tronWeb.trx.getBalance();
        console.log("balance 2", balance);
        for (let i = 0; i < blocksBeforeReveal; i ++) {
          sleep.sleep(3);
          await factoryContract.checkBlockNumber(hash).send({
            feeLimit: 1000000000,
            callValue: 0,
            shouldPollResponse: false
          });
        }
        balance = await tronWeb.trx.getBalance();
        console.log("balance 3", balance);
        sleep.sleep(3);
        contractBalance = await factory.getBalance();
        console.log("New Balance", contractBalance)
      }
    });
  })
});