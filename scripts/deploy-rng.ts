const { ethers } = require("hardhat");
import { verify } from "../utils/verify";

const vrfCoordinator = "0x8103b0a8a00be2ddc778e6e7eaa21791cd364625";
const subscriptionId = 4796;
const keyHash =
  "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f";

async function main() {
  const RNGChainlinkV2 = await ethers.getContractFactory("RNGChainlinkV2");
  const rngChainlikV2 = await RNGChainlinkV2.deploy(
    vrfCoordinator,
    subscriptionId,
    keyHash
  );

  await rngChainlikV2.deployed();

  if (process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying RNGChainlinkV2......");
    await verify(rngChainlikV2.address, [
      vrfCoordinator,
      subscriptionId,
      keyHash,
    ]);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
