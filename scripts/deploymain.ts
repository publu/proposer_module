const hre = require("hardhat");

async function main() {
    console.log("hello!")
    const ProposerExecutionModule = await hre.ethers.getContractFactory("ProposerExecutionModule");
    console.log("hello!1")
    const proposerExecutionModule = await ProposerExecutionModule.deploy();

    await proposerExecutionModule.deployed();

    console.log("ProposerExecutionModule deployed to:", proposerExecutionModule.address);

    const ChainlinkProcessor = await hre.ethers.getContractFactory("ChainlinkProcessor");
    const chainlinkAddress = "0xa8c0c11bf64af62cdca6f93d3769b88bdd7cb93d"; // replace with the address of the Chainlink

    const chainlinkProcessor = await ChainlinkProcessor.deploy(proposerExecutionModule.address, chainlinkAddress, "5790810961207155433");

    await chainlinkProcessor.deployed();
    console.log("ChainlinkProcessor deployed to: ", chainlinkProcessor.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
