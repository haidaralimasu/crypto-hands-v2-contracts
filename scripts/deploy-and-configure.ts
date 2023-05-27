const { ethers } = require("hardhat");
import { verify } from "../utils/verify";

const vrfCoordinator = "0xae975071be8f8ee67addbc1a82488f1c24858067";
const subscriptionId = 293;
const keyHash =
  "0xcc294a196eeeb44da2888d17c0625cc88d70d9760a69d58d853ba6581a9ab0cd";

async function main() {
  const CryptoHands = await ethers.getContractFactory("CryptoHands");
  console.log("Getting artifacts for CryptoHands......");

  const baseUri = "iambaseuri";
  const hiddenUri = "iamhiddenuri";

  const chArgs = [baseUri, hiddenUri];

  console.log("Deploying CryptoHands......");

  const cryptoHands = await CryptoHands.deploy(baseUri, hiddenUri);

  await cryptoHands.deployed();

  console.log(`CryptoHands deployed at ${cryptoHands.address}`);

  if (process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying CryptoHands....");
    await verify(cryptoHands.address, chArgs);
  }

  const RockPaperScissors = await ethers.getContractFactory(
    "RockPaperScissors"
  );

  console.log("Collecting artifacts for RockPaperScissors......");

  const minBet = "1";
  const maxBet = "10000000000000000000";
  const rpsArgs = [maxBet, minBet, cryptoHands.address];

  console.log("Deploying RockPaperScissors......");

  const rockPaperScissors = await RockPaperScissors.deploy(
    maxBet,
    minBet,
    cryptoHands.address
  );

  await rockPaperScissors.deployed();

  console.log(`RockPaperScissors deployed at ${rockPaperScissors.address}`);

  if (process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying RockPaperScissors......");
    await verify(rockPaperScissors.address, rpsArgs);
  }

  await cryptoHands.updateGameAddress(rockPaperScissors.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
