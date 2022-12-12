require("dotenv").config();
const path = require("path");

CNR = "0x0cadb0d9e410072325d2acc00aab99eb795a8c86";

const { ethers, upgrades } = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();
  await ethers.getSigners();

  const RWAT = await ethers.getContractFactory("RWAT");
  const rwat = await upgrades.deployProxy(
    RWAT,
    [owner.address, "name", "tokenSymbol", CNR],
    {
      initializer: "initialize",
    }
  );
  await rwat.deployed();
  console.log("rwat Contract deployed to:", rwat.address);

  console.log("owner address", owner.address);
  await rwat.grantRole(
    ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ADMIN")),
    owner.address
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// npx hardhat run scripts/deployUpgradeable.js --network BSCTestnet
// npx hardhat verify --network BSCTestnet
