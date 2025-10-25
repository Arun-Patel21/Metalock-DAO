const hre = require("hardhat");

async function main() {
  const MetaLockDAO = await hre.ethers.getContractFactory("MetaLockDAO");
  const dao = await MetaLockDAO.deploy();
  await dao.waitForDeployment();

  console.log("MetaLock DAO deployed to:", await dao.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
