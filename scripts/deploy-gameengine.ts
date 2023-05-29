const { ethers, upgrades } = require("hardhat");

const rng = "0x9C5AB333475af6ECD3De08AF72D7ee7e10B4B2e7";
const cryptoHands = "0x072Ef85515E9c61e13aa09BA4a861F8bc2632c43";

async function main() {
  const GameEngineV2 = await ethers.getContractFactory("GameEngineV2");
  console.log("Deploying GameEngineV2 .....");
  const proxy = await upgrades.deployProxy(GameEngineV2, [rng, cryptoHands], {
    initializer: "initialize",
    kind: "uups",
  });

  console.log("Proxy depoyed at:", proxy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
