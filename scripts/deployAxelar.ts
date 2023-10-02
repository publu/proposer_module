import hre from "hardhat";
import fs from 'fs';

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());
    
    const gateway = "0x6f015f16de9fc8791b234ef68d486d2bf203fba8";
    const executionModule = "0x02668453F6138bE9BBA9946de8472228c4400109";

    const Contract = await hre.ethers.getContractFactory("AxelarProcessor");
    const contract = await Contract.deploy(gateway, executionModule);

    await contract.deployed();

    console.log("AxelarProcessor deployed to:", contract.address);

    // Save the contract address to a json file
    const contractAddress = {
        gateway,
        executionModule,
        contractAddress: contract.address
    };

    fs.writeFileSync('axelar-deployed.json', JSON.stringify(contractAddress, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });



