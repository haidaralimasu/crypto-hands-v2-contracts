const { ethers } = require("hardhat");

async function main() {
  const RNGChainlinkV2 = await ethers.getContractFactory("RNGChainlinkV2");
  const rngChainlikV2 = await RNGChainlinkV2.attach(
    "0x8cfdc06d844f1579aec011eea8abdd818d1b06b7"
  );

  await rngChainlikV2.requestRandomNumber({ gasLimit: "1000000" });
  const lastRequestId = await rngChainlikV2.getLastRequestId();
  console.log(lastRequestId);
  await console.log("fone");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
