import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import {
  ProposerExecutionModule,
  ProposerExecutionModule__factory,
  Safe,
} from "../typechain-types";
import { ethers } from "hardhat";

const { expect } = require("chai");

describe("Delayed Execution", function () {
  let ExecutionProposerFactory: ProposerExecutionModule__factory;
  let executionProposer: ProposerExecutionModule;
  let deployer: SignerWithAddress;
  let receiver: SignerWithAddress;
  let gnosisSafe: SignerWithAddress;
  let gnosisSafeContract: Safe;

  before(async function () {
    [deployer, receiver] = await ethers.getSigners();

    ExecutionProposerFactory = await ethers.getContractFactory(
      "ProposerExecutionModule"
    );

    executionProposer = await ExecutionProposerFactory.deploy();
    gnosisSafe = await ethers.getSigner(
      "0x0DA0C3e52C977Ed3cBc641fF02DD271c3ED55aFe"
    );
    gnosisSafeContract = await ethers.getContractAt("Safe", gnosisSafe.address);

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [gnosisSafe.address],
    });
  });

  it("Should execute ETH transfer after delay with execution proposer", async () => {
    const initialSafeBalance = await ethers.provider.getBalance(
      gnosisSafe.address
    );
    const initialReceiverBalance = await ethers.provider.getBalance(
      receiver.address
    );
    //1. Mint some ETH to the Gnosis Safe
    const mintAmount = ethers.utils.parseEther("10");
    await deployer.sendTransaction({
      to: gnosisSafe.address,
      value: mintAmount,
    });

    // add propposer as whitelisted
    gnosisSafeContract
      .connect(gnosisSafe)
      .enableModule(executionProposer.address);

    // // Confirm that the Safe received the ETH
    const newSafeBalance = await ethers.provider.getBalance(gnosisSafe.address);
    expect(newSafeBalance.sub(initialSafeBalance)).to.equal(mintAmount);

    await executionProposer.connect(gnosisSafe).addProposer(deployer.address);

    //2. Use the ExecutionProposer to queue a transaction that will transfer the ETH after a delay
    const transferAmount = ethers.utils.parseEther("0.5");
    const data = "0x"; // Assuming simple ETH transfer, so no additional data required
    const operation = 0; // Call operation
    await executionProposer.createExecution(
      gnosisSafe.address,
      receiver.address,
      transferAmount,
      data,
      operation
    ); // 24 hours delay

    // 3. Simulate passage of 24 hours
    await time.increase(60 * 60 * 24 * 7 + 1);

    const executionRequestId = await ethers.utils.solidityKeccak256(
      ["bytes"],
      [
        ethers.utils.solidityPack(
          ["address", "address", "uint256", "bytes", "uint8"],
          [
            gnosisSafe.address,
            receiver.address,
            transferAmount,
            data,
            operation,
          ]
        ),
      ]
    );

    // After delay, execute the proposed transaction
    await executionProposer.executeExecutions(gnosisSafe.address, [
      executionRequestId,
    ]);

    // 4. Confirm the ETH was correctly transferred
    const finalSafeBalance = await ethers.provider.getBalance(
      gnosisSafe.address
    );
    const finalReceiverBalance = await ethers.provider.getBalance(
      receiver.address
    );

    expect(finalReceiverBalance.sub(initialReceiverBalance)).to.equal(
      transferAmount
    );
  });
});
