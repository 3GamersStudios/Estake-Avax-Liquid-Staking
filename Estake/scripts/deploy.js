const { ethers, upgrades } = require("hardhat");

async function main() {
  // Deploying
  const Estake = await ethers.getContractFactory("Estake");
  const instance = await upgrades.deployProxy(Estake, [12900, 15738]);
  await instance.deployed();
  console.log(instance.address);

  // Upgrading
  //const BoxV2 = await ethers.getContractFactory("BoxV2");
  //const upgraded = await upgrades.upgradeProxy(instance.address, BoxV2);
}

main();