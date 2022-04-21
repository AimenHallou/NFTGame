const { expect } = require("chai");
const { ethers } = require("hardhat");



describe("test NFT Game", function () {
  this.timeout(500);
  it("setup", async function (done) {

    // Deploy all 4 contracts

    const Vault = await hre.ethers.getContractFactory("Vault");
    const vault = await Vault.deploy();
    const test = await vault.deployed();
    const vaultAddress = vault.address;
  
    const Diamond = await hre.ethers.getContractFactory("Diamond");
    const diamond = await Diamond.deploy(vault.address);
    const test2 = await diamond.deployed();
    const diamondAddress = diamond.address;
  
    const Miner = await hre.ethers.getContractFactory("Miner");
    const miner = await Miner.deploy();
    const test3 = await miner.deployed();
    const minerAddress = miner.address;

  
    const Mine = await hre.ethers.getContractFactory("Mine");
    const mine = await Mine.deploy(miner.address, diamond.address, vault.address);
    await mine.deployed();
    const mineAddress = mine.address;

    //Log that they are all published

    console.log("Vault contract deployed to:", vaultAddress);
    console.log("Diamond contract deployed to:", diamondAddress);
    console.log("Miner contract deployed to:", minerAddress);
    console.log("Mine contract deployed to:", mineAddress);



    console.log(await miner.presaleOpen());
    var ts = Math. round((new Date()). getTime() / 1000);
    await miner.setPresaleStartTime(ts+4);
    setTimeout(done, 250);
    console.log(await miner.presaleOpen());
  });
});



// describe("mint", function () {
//   it("mint", async function () {

//     });
//   });