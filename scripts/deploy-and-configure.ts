const { ethers, upgrades } = require("hardhat");
import { verify } from "../utils/verify";

const vrfCoordinator = "0x7a1bac17ccc5b313516c5e16fb24f7659aa5ebed"; //TESTNET
const subscriptionId = "4796";
const keyHash =
  "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f"; //TESTNET

const baseURI = "iambaseuri";
const hiddenURI = "iamhiddenuri";

async function main() {
  const CryptoHands = await ethers.getContractFactory("CryptoHands");
  const GameEngineV2 = await ethers.getContractFactory("GameEngineV2");
  const RNGChainlinkV2 = await ethers.getContractFactory("RNGChainlinkV2");

  const cryptoHands = await CryptoHands.deploy(baseURI, hiddenURI);
  await cryptoHands.deployed();

  const rngChainlikV2 = await RNGChainlinkV2.deploy(
    vrfCoordinator,
    subscriptionId,
    keyHash
  );
  await rngChainlikV2.deployed();

  const gameEngineV2 = await upgrades.deployProxy(
    GameEngineV2,
    ["0x8CfdC06D844f1579Aec011EEA8AbDd818D1b06b7", cryptoHands.address],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await gameEngineV2.deployed();

  await cryptoHands.updateGameAddress(gameEngineV2.address);

  // if (process.env.ETHERSCAN_API_KEY) {
  //   console.log("Verifying RNGChainlinkV2......");
  //   await verify(rngChainlikV2.address, [
  //     vrfCoordinator,
  //     subscriptionId,
  //     keyHash,
  //   ]);

  //   console.log("Verifying CryptoHands......");
  //   await verify(cryptoHands.address, [baseURI, hiddenURI]);

  //   console.log("Verifying GameEngineV2......");
  //   await verify(gameEngineV2.address, []);
  // }

  await console.log("RNGChainlinkV2: ", rngChainlikV2.address);
  await console.log("CryptoHands: ", cryptoHands.address);
  await console.log("GameEngineV2: ", gameEngineV2.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
