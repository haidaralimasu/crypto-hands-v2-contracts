const { ethers: any } = require("hardhat");

async function main() {
  const GameEngineV2 = await ethers.getContractFactory("GameEngineV2");
  console.log("Deploying GameEngineV2 .....");
  const GameEngineV2Proxy = GameEngineV2.attach(
    "0x072Ef85515E9c61e13aa09BA4a861F8bc2632c43"
  );
  await GameEngineV2Proxy.makeBet(
    1,
    "0x48652DEa929463e9591B5Bcdaf847708b3db3E77",
    { value: "1000000000000000" }
  );
  await console.log("done");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
