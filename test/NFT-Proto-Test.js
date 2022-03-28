const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("CreativeSocialNFT-Test", function () {
  it("Testing of the main contract", async function () {
    const accounts = await ethers.getSigners();
    console.log(accounts);
    const NFTProto = await ethers.getContractFactory("CreativeSocialNFT");
    const  nftProto = await NFTProto.deploy(0,accounts[0].address);

    await nftProto.mint(10,1,0,0,"xyz",0);

    const balanceTest=await nftProto.balanceOf(accounts[0].address,1);

    expect(balanceTest).to.equal(10);

    await nftProto.addOnSupply(accounts[0].address,1,5,0);

    const balanceTest1=await nftProto.balanceOf(accounts[0].address,1);

    expect(balanceTest1).to.equal(15);

  });
});
