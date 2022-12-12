const { expect } = require("chai");
const help = require("./upgradeable_helper_functions.js");
const { ethers, upgrades } = require("hardhat");

CNR = "0x0cadb0d9e410072325d2acc00aab99eb795a8c86";

describe("Claim units and check enumerable token ids", function () {
  let owner, provider, investor, testToken;

  beforeEach(async function () {
    [owner, provider, investor] = await ethers.getSigners();
    // CNR = await help.setCNR();
    testToken = await help.setTestToken();

    const Rwat = await ethers.getContractFactory("RWAT");
    const rwat = await upgrades.deployProxy(
      Rwat,
      [owner.address, "tokenName", "tokenSymbol", CNR],
      {
        initializer: "initialize",
      }
    );
    await rwat.deployed();

    let ADMIN = await rwat.ADMIN();
    await rwat.grantRole(ADMIN, owner.address);
  });
  it("Should work", async function () {
    const Rwat = await ethers.getContractFactory("RWAT");
    const rwat = await upgrades.deployProxy(
      Rwat,
      [owner.address, "tokenName", "tokenSymbol", CNR],
      {
        initializer: "initialize",
      }
    );
    await rwat.deployed();

    let ADMIN = await rwat.ADMIN();
    await rwat.grantRole(ADMIN, owner.address);
    await rwat.grantRole(ADMIN, provider.address);

    await rwat.createAsset(1, 300, testToken.address);
    await rwat.mintAsset(1, 100);

    console.log("total assets in circulation", await rwat.getTotalMinted(1));
    await rwat.setWhitelisted([investor.address], true);
    console.log(investor.address);
    let units = [1000000000, 1000000001, 1000000002];

    let i;
    // bal = await rwat.balanceOf(rwat.address);
    // console.log("bal rwat", bal);
    // for (i = 0; i < (await rwat.balanceOf(rwat.address)); i++) {
    //   console.log("ok", i);
    // }
    arr = [];
    let tokens;
    for (i = 0; i < (await rwat.balanceOf(rwat.address)); i++) {
      arr[i] = await rwat.tokenOfOwnerByIndex(rwat.address, i);
    }
    console.log("arresr", arr);
    // for (j = 0; j < arr.length; j++) {
    //   console.log("arr with tokens", arr[j]);
    // }
    // console.log("arr", arr);

    console.log("owner of: ", await rwat.tokenOfOwnerByIndex(rwat.address, 3));

    console.log("current asset cap", await rwat.getAssetCap(1));

    await rwat.updateAssetCap(1, 1000);
    console.log("asset cap after update", await rwat.getAssetCap(1));

    await rwat.mintAsset(1, 150);

    console.log(
      "total assets in circulation after creating more",
      await rwat.getTotalMinted(1)
    );

    let obj = ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "uint[]"],
      [investor.address, rwat.address, units]
    );
    const { prefix, v, r, s } = await createSignature(obj);

    await rwat.updateServer(provider.address);

    await rwat.connect(investor).claimUnits(units, prefix, v, r, s);

    expect(await rwat.ownerOf(1000000002)).to.be.equal(investor.address);
    // console.log(await rwat.balanceOf(investor.address));

    console.log(
      "hash admin",
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ADMIN")),
      rwat.address
    );
  });

  async function createSignature(obj) {
    obj = ethers.utils.arrayify(obj);
    const prefix = ethers.utils.toUtf8Bytes(
      "\x19Ethereum Signed Message:\n" + obj.length
    );
    const serverSig = await provider.signMessage(obj);
    const sig = ethers.utils.splitSignature(serverSig);
    return { ...sig, prefix };
  }
});
