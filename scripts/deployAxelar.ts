const hre = require("hardhat");
const fs = require('fs');
const chains = [
    {
        "chainId": 1,
        "chainName": "Ethereum",
        "gatewayContract": "0x4F4495243837...B3eEdf548D56A5"
    },
    // ... other chains
];

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());
    
    const gateway = "0x1234567890";
    const executionModule = "0x1234567890";

    const Contract = await hre.ethers.getContractFactory("AxelarProcessor");
    const contract = await Contract.deploy(gateway, executionModule);

    await contract.deployed();

    console.log("AxelarProcessor deployed to:", contract.address);

    // Save the contract addresses to a json file
    const contractAddresses = chains.map(chain => ({
        ...chain,
        contractAddress: contract.address
    }));

    fs.writeFileSync('axelar-deployed.json', JSON.stringify(contractAddresses, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });


