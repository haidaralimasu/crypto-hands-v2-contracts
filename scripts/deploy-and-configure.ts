const { ethers, upgrades } = require("hardhat");
import { verify } from "../utils/verify";

const vrfCoordinator = "0xbd13f08b8352a3635218ab9418e340c60d6eb418"; //TESTNET
const subscriptionId = 228;
const keyHash =
  "0x121a143066e0f2f08b620784af77cccb35c6242460b4a8ee251b4b416abaebd4"; //TESTNET

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
    [rngChainlikV2.address, cryptoHands.address],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await gameEngineV2.deployed();

  await cryptoHands.updateGameAddress(gameEngineV2.address);

  if (process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying RNGChainlinkV2......");
    await verify(rngChainlikV2.address, [
      vrfCoordinator,
      subscriptionId,
      keyHash,
    ]);

    console.log("Verifying CryptoHands......");
    await verify(cryptoHands.address, [baseURI, hiddenURI]);

    console.log("Verifying GameEngineV2......");
    await verify(gameEngineV2.address, []);
  }

  await console.log("RNGChainlinkV2: ", rngChainlikV2.address);
  await console.log("CryptoHands: ", cryptoHands.address);
  await console.log("GameEngineV2: ", gameEngineV2.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
