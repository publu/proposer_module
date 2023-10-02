const hre = require("hardhat");

async function main() {
    console.log("hello!")
    const ProposerExecutionModule = await hre.ethers.getContractFactory("ProposerExecutionModule");
    console.log("hello!1")
    const proposerExecutionModule = await ProposerExecutionModule.deploy();

    await proposerExecutionModule.deployed();

    console.log("ProposerExecutionModule deployed to:", proposerExecutionModule.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
