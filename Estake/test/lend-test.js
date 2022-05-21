const { ethers, upgrades } = require("hardhat");

async function main() {

  await hre.run('compile');
  
  const Estake = await ethers.getContractFactory("Estake");
  const estake = await upgrades.deployProxy(Estake, [42]);
  await estake.deployed();
  console.log("Box deployed to:", estake.address);
}