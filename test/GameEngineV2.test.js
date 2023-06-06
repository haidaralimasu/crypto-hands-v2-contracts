const { expect } = require("chai");
const { ethers } = require("hardhat");

const rng = "0xd8540ea08052631B0B4e17ad14C1f556925e52aC";
const cryptoHands = "0x635Af72bC3904DFf40e31538467A0A1528e338c4";

describe("GameEngineV2 Unit Tests", async () => {
  let GameEngineV2;
  let gameEngineV2;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async () => {
    GameEngineV2 = await ethers.getContractFactory("GameEngineV2");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    gameEngineV2 = await GameEngineV2.deploy();
    await gameEngineV2.deployed();
    await gameEngineV2.initialize(rng, cryptoHands);
  });

  describe("Deployment and constructor", () => {
    it("it should make bet", async () => {
      // await gameEngineV2.deposite({ value: "1000000000000000000" });
      // await gameEngineV2
      //   .connect(addr1)
      //   .makeBet(2, addr2.address, { value: "1000000000000000000" });
      // const player = await gameEngineV2.s_players(addr1.address);
      // console.log(player);
      // const refree = await gameEngineV2.s_players(addr2.address);
      // console.log(refree);
      // const commission = await gameEngineV2._getComissionFromBet(
      //   "1000000000000000000",
      //   addr1.address
      // );
      // console.log(commission);

      const winPercentage = await gameEngineV2._getNftWinPercentage(
        "100000000000000"
      );
      console.log(winPercentage);
    });
  });

  describe("Bet", () => {
    it("it should make bet", async () => {
      // await gameEngineV2.deposite({ value: "1000000000000000000" });
      // await gameEngineV2
      //   .connect(addr1)
      //   .makeBet(2, addr2.address, { value: "1000000000000000000" });
      // const player = await gameEngineV2.s_players(addr1.address);
      // console.log(player);
      // const refree = await gameEngineV2.s_players(addr2.address);
      // console.log(refree);
      // const commission = await gameEngineV2._getComissionFromBet(
      //   "1000000000000000000",
      //   addr1.address
      // );
      // console.log(commission);

      const winPercentage = await gameEngineV2._getNftWinPercentage(
        "100000000000000"
      );
      console.log(winPercentage);
    });
  });
});
