const { ethers, upgrades } = require("hardhat");

async function setCNR() {
  const ChromiaNetResolver = await ethers.getContractFactory(
    "ChromiaNetResolver"
  );
  const chromiaNetResolver = await ChromiaNetResolver.deploy();
  await chromiaNetResolver.deployed();
  return chromiaNetResolver;
}

async function setTestToken() {
  const [owner, addr1, addr2, addr3] = await ethers.getSigners();
  const TestToken = await ethers.getContractFactory("TestToken");
  const testToken = await TestToken.deploy();
  await testToken.deployed();
  await testToken.connect(owner).faucet();
  await testToken.connect(addr1).faucet();
  await testToken.connect(addr2).faucet();
  await testToken.connect(addr3).faucet();
  return testToken;
}

async function setAsset() {
  const State = await ethers.getContractFactory("Asset");
  const state = await State.deploy();
  await state.deployed();
  return state;
}

module.exports = {
  setCNR,
  setTestToken,
  setAsset,
};
