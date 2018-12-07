const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const Tronweb = require("tronweb");

contract('FaceWorthPollFactory', async (accounts) => {

  const HttpProvider = Tronweb.providers.HttpProvider;
  const fullNode = new HttpProvider('http://127.0.0.1:9090');
  const solidityNode = new HttpProvider('http://127.0.0.1:9090');
  const eventServer = 'http://127.0.0.1:9090';
  const pks = [
    'd606505c3e136f2eed43f93660a4192a89c4e3eadc1bfbf4ea720efc18faede7',
    'd20f75308282b2cd8f90b2eceef93ac4b00d45344c19557c00cd3362aa4e1c0c',
    '4dd7c078faa0530372d22aad9405dfb98780479b7d057999f571664294979ac4',
    '8193afe53ea7cc24334e1c4a2069ca174d627c5865f1bf2506e7711ddc9b3d4f',
    '1d050666510e0c60bfc0beca7afadc0545460d9c89912f677b6616788c6b8ab8',
    '2ee4f488c7534ca4bb4758a3b18cb6e21bf95ea6c1375ac848bb98e860d5b6dd',
    '60bae2d7bf4079eceb548cdd11772b66c49d015dcb795a24d2fa5c33d0fc5d4c',
    'a07a52dc4f332d0dbc65f5365d491c03af73f36ba073e419ed0d55dd4843a605',
    'c75a7e4ec355cab761b1fbce4bf698ef3ecf10d05c3828cdd74140c322a8a205',
    '3f98a7d159591a7e4bf886d0b6bbb9323fd5b263420b7269500960e9803c9161'  
  ];
  const tronWeb = new Tronweb(
    fullNode,
    solidityNode,
    eventServer,
    pks[0]
  );
  let faceToken;
  let factory;

  beforeEach(async () => {
    faceToken = await FaceToken.deployed();
    factory = await tronWeb.contract().at("THn2q7zFHxEF8kx3hgNp4BeXxdCV1FEJ7f");
  });

  it("faceTokenRewardPool is 80 percent of FaceToken totalSupply", async () => {
    let totalSupplyInSun = await faceToken.totalSupply();
    let decimals = await faceToken.decimals();
    let totalSupply = totalSupplyInSun / (10 ** decimals);
    let eightyPercentOfTotalSupply = totalSupply * 8 / 10;
    let faceTokenRewardPoolInSun = await factory.faceTokenRewardPool().call();
    let faceTokenRewardPool = faceTokenRewardPoolInSun / (10 ** decimals);
    assert.equal(eightyPercentOfTotalSupply, faceTokenRewardPool, "faceTokenRewardPool wasn't 80 percent of FaceToken totalSupply");
  });

  it("FaceWorthPoll contract is created successfully", async () => {
    let faceHash = Tronweb.sha3("Some face photo", true);
    let blocksBeforeReveal = 10; // min number of blocks
    let blocksBeforeEnd = blocksBeforeReveal;
    let participantsRequired = 3;
    let contractAddress = await factory.deployFaceWorthPoll(faceHash, blocksBeforeReveal, blocksBeforeEnd, participantsRequired).send({
      feeLimit: 1000000000,
      callValue: 0,
      shouldPollResponse: true
    });
    console.log("Poll contract address", contractAddress);

    let valid = await factory.verify(contractAddress).call();
    assert.equal(valid, true, "The valid wasn't valid");

    let numberOfPolls = await factory.getNumberOfPolls().call();
    assert.equal(numberOfPolls, 1, "Number of polls wasn't 1 after 1 poll is created");

    // let poll = await tronWeb.contract().at(response.args.contractAddress);

    let stake = await factory.stake().call();
    console.log("stake", stake);

    let poll = await tronWeb.contract().at(contractAddress);
    let saltedWorthHash = Tronweb.sha3("中文-", 10, true);
    await poll.commit(saltedWorthHash).send({
      feeLimit: 1000000000,
      callValue: 100000000,
      shouldPollResponse: true
    });
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