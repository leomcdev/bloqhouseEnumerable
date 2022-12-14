require("dotenv").config();
const path = require("path");

const { ethers, upgrades } = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();
  await ethers.getSigners();

  const MULTICALL = await ethers.getContractFactory("Multicall");
  const multicall = await upgrades.deployProxy(MULTICALL, [], {
    initializer: "initialize",
  });
  await multicall.deployed();
  console.log("multicall Contract deployed to:", multicall.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// npx hardhat run scripts/deployUpgradeable.js --network BSCTestnet
// npx hardhat verify --network BSCTestnet
