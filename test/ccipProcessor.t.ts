import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { expect } from "chai";
import {
  ChainlinkProcessor,
  ProposerExecutionModule,
  Safe,
} from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("ChainlinkProcessor", () => {
  let chainlinkProcessor: ChainlinkProcessor;
  let executionModuleMock: ProposerExecutionModule;
  let owner: Signer;
  let chainlinkNode: SignerWithAddress;
  let approver: SignerWithAddress;
  let receiver: SignerWithAddress;
  let gnosisSafe: SignerWithAddress;
  let gnosisSafeContract: Safe;

  beforeEach(async () => {
    [owner, chainlinkNode, approver, receiver] = await ethers.getSigners();

    // Mock the ExecutionModule contract with a stubbed createExecution method
    const ExecutionModule = await ethers.getContractFactory(
      "ProposerExecutionModule"
    );
    executionModuleMock = await ExecutionModule.deploy();
    await executionModuleMock.deployed();

    const ChainlinkProcessor = await ethers.getContractFactory(
      "ChainlinkProcessor"
    );
    chainlinkProcessor = await ChainlinkProcessor.deploy(
      executionModuleMock.address,
      await chainlinkNode.getAddress()
    );
    await chainlinkProcessor.deployed();

    gnosisSafe = await ethers.getSigner(
      "0x0DA0C3e52C977Ed3cBc641fF02DD271c3ED55aFe"
    );
    gnosisSafeContract = await ethers.getContractAt("Safe", gnosisSafe.address);

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [gnosisSafe.address],
    });
  });

  describe("ccipReceive", () => {
    it("should process and forward the message from Chainlink to the ExecutionModule", async () => {
      // Add approver
      await chainlinkProcessor.addApprover(await approver.getAddress());

      // Create the message
      const to = receiver.address;
      const data = "0x";
      const amount = ethers.utils.parseEther("1");

      const message = ethers.utils.defaultAbiCoder.encode(
        ["address", "address", "bytes", "uint256"],
        [gnosisSafe.address, to, data, amount]
      );

      const any2EvmMessage = {
        messageId: "0x234",
        destTokenAmounts: [],
        sourceChainSelector: 123456, // Some random chainID not equal to the current chain
        sender: ethers.utils.defaultAbiCoder.encode(
          ["address"],
          [await approver.getAddress()]
        ),
        data: message,
      };

      // Call ccipReceive
      expect(
        chainlinkProcessor.connect(chainlinkNode).ccipReceive(any2EvmMessage)
      ).to.not.be.reverted;
    });

    // it("should revert if sourceChain is same as current chain", async () => {
    //   await chainlinkProcessor.addApprover(await approver.getAddress());
    //   const message = ethers.utils.defaultAbiCoder.encode(
    //     ["address", "address", "bytes"],
    //     [await owner.getAddress(), await owner.getAddress(), "0x"]
    //   );

    //   const any2EvmMessage = {
    //     messageId: "0x234",
    //     destTokenAmounts: [],
    //     sourceChainSelector: await owner.getChainId(),
    //     sender: ethers.utils.defaultAbiCoder.encode(
    //       ["address"],
    //       [await approver.getAddress()]
    //     ),
    //     data: message,
    //   };

    //   await expect(
    //     chainlinkProcessor.connect(chainlinkNode).ccipReceive(any2EvmMessage)
    //   ).to.be.revertedWith("SameSourceChain()");
    // });

    // it("should revert if sender is not approved", async () => {
    //   const message = ethers.utils.defaultAbiCoder.encode(
    //     ["address", "address", "bytes"],
    //     [await owner.getAddress(), await owner.getAddress(), "0x"]
    //   );
    //   const any2EvmMessage = {
    //     messageId: "0x234",
    //     destTokenAmounts: [],
    //     sourceChainSelector: await owner.getChainId(),
    //     sender: ethers.utils.defaultAbiCoder.encode(
    //       ["address"],
    //       [await approver.getAddress()]
    //     ),
    //     data: message,
    //   };

    //   await expect(
    //     chainlinkProcessor.connect(chainlinkNode).ccipReceive(any2EvmMessage)
    //   ).to.be.revertedWith("NotApproved()");
    // });
  });

  describe("addApprover and removeApprover", () => {
    it("should allow to add and remove an approver", async () => {
      await chainlinkProcessor.addApprover(await approver.getAddress());
      expect(await chainlinkProcessor.addApprover(await owner.getAddress())).to
        .be.not.be.reverted;

      await chainlinkProcessor.removeApprover(await approver.getAddress());
      expect(await chainlinkProcessor.addApprover(await owner.getAddress())).to
        .be.not.be.reverted;
    });
  });
});
