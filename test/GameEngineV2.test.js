const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const rng = "0xd8540ea08052631B0B4e17ad14C1f556925e52aC";

describe("GameEngineV2 Unit Tests", async () => {
  let GameEngineV2;
  let gameEngineV2;
  let CryptoHands;
  let cryptoHands;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async () => {
    GameEngineV2 = await ethers.getContractFactory("GameEngineV2");
    CryptoHands = await ethers.getContractFactory("CryptoHands");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    gameEngineV2 = await GameEngineV2.deploy();
    await gameEngineV2.deployed();
    await gameEngineV2.deposite({ value: "100000000000000000000" });

    cryptoHands = await CryptoHands.deploy("hii", "Hii", gameEngineV2.address);
    await cryptoHands.deployed();

    await gameEngineV2.initialize(rng, cryptoHands.address);

    // await cryptoHands.updateGameAddress(gameEngineV2.address);
  });

  describe("Deployment and constructor", () => {
    it("it should make bet", async () => {
      await gameEngineV2.makeBet(0, addr2.address, {
        value: "1000000000000000000",
      });

      // await gameEngineV2.makeBet(1, addr2.address, {
      //   value: "2000000000000000000",
      // });

      // await gameEngineV2.makeBet(2, addr2.address, {
      //   value: "3000000000000000000",
      // });

      // const player = await gameEngineV2.getPlayer(owner.address);
      // console.log(player);

      // const totalSupply = await cryptoHands.totalSupply();
      // await console.log(totalSupply.toString());

      // const balance = await cryptoHands.s_cryptoHandsToken(0);
      // console.log(balance);

      // const totalSupply = await cryptoHands.totalSupply();
      // console.log(totalSupply);

      // const token = await cryptoHands.s_cryptoHandsToken(1);
      // console.log(token);

      // await time.increase(864000);
      // const claimableAmount = await gameEngineV2.getClaimAmount(owner.address);
      // console.log(claimableAmount.toString(), "CLAIMABLE AMOUNT");
    });
  });
});
