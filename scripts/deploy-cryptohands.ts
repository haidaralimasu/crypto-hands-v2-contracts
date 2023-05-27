const { ethers } = require("hardhat");
import { verify } from "../utils/verify";

const baseURI = "iambaseuri";
const hiddenURI = "iamhiddenuri";

async function main() {
  const CryptoHands = await ethers.getContractFactory("CryptoHands");
  const cryptoHands = await CryptoHands.deploy(baseURI, hiddenURI);

  await cryptoHands.deployed();

  console.log(cryptoHands.address);

  if (process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying CryptoHands......");
    await verify(cryptoHands.address, [baseURI, hiddenURI]);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
