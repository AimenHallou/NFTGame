// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {

  const Vault = await hre.ethers.getContractFactory("Vault");
  const vault = await Vault.deploy();
  const test = await vault.deployed();

  const Diamond = await hre.ethers.getContractFactory("Diamond");
  const diamond = await Diamond.deploy(vault.address);
  const test2 = await diamond.deployed();

  const Miner = await hre.ethers.getContractFactory("Miner");
  const miner = await Miner.deploy();
  const test3 = await miner.deployed();

  const Mine = await hre.ethers.getContractFactory("Mine");
  const mine = await Mine.deploy(miner.address, diamond.address, vault.address);
  await mine.deployed();

  console.log("Vault contract deployed to:", vault.address);
  console.log("Diamond contract deployed to:", diamond.address);
  console.log("Miner contract deployed to:", miner.address);
  console.log("Mine contract deployed to:", mine.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
