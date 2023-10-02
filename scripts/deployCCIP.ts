const hre = require("hardhat");

async function main() {
    const ChainlinkProcessor = await hre.ethers.getContractFactory("ChainlinkProcessor");
    const executionModuleAddress = "0x863f234d40E42b748102a5173Ced83e171FBf2D5"; // replace with the address of the ExecutionModule
    const chainlinkAddress = "0xa8c0c11bf64af62cdca6f93d3769b88bdd7cb93d"; // replace with the address of the Chainlink
    const chainlinkOfframp = "0x06eb6ebdc74f30c612ccf0fd7560560f5d67ef87"
    const chainlinkProcessor = await ChainlinkProcessor.deploy(executionModuleAddress, chainlinkAddress);

    await chainlinkProcessor.deployed();

    console.log("ChainlinkProcessor deployed to:", chainlinkProcessor.address);
}
/*
BASE GOERLI FREE MINTABLE TOKEN
0x8D6CeBD76f18E1558D4DB88138e2DeFB3909fAD6
mint(amount) mints it to sender
*/
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

