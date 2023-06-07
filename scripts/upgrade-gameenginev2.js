const { ethers, upgrades } = require("hardhat");

async function main(deployer) {
  const GameEngineV2 = await ethers.getContractFactory("GameEngineV2");
  console.log("Deploying Smart Contract");
  const proxy = await upgrades.upgradeProxy(
    "0x072Ef85515E9c61e13aa09BA4a861F8bc2632c43",
    GameEngineV2,
    {
      initializer: "initialize",
      kind: "uups",
    }
  );

  console.log("Proxy depoyed at:", proxy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
