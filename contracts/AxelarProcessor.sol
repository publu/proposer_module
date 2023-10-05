pragma solidity ^0.8.0;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';

interface ExecutionModule {
    /**
     * @notice Allows an external contract to request the execution of a transaction.
     * @param safe The address of the Gnosis Safe.
     * @param to The address of the recipient.
     * @param value The amount of ether to send.
     * @param data The data payload of the transaction.
     * @param operation The operation type of the transaction.
     */
    function createExecution(
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) external;
}
/**
 * @title AxelarProcessor
 * @notice This contract is an extension for the ProposerExecution Gnosis Safe module.
 * It allows an external contract to request the execution of a transaction.
 */
contract AxelarProcessor is AxelarExecutable {

    ExecutionModule public executionModule;
    mapping(string => mapping(address => mapping(string => bool))) public approvers;
    mapping(bytes32 => bool) public processedMessages;

    error NotApproved(string sender);
    error MessageAlreadyProcessed(bytes32 messageId);

    /**
     * @notice Constructs the AxelarProcessor contract.
     * @param gateway_ The address of the AxelarGateway contract.
     */
    constructor(address gateway_, ExecutionModule _executionModule) AxelarExecutable(gateway_) {
        executionModule = _executionModule;
    }

    /**
     * @notice Allows a contract to add an approver for a given chain ID
     * @param chainId The ID of the chain
     * @param approver The address of the approver to add
     */
    function addApprover(string memory chainId, string memory approver) external {
        approvers[chainId][msg.sender][approver] = true;
    }

    /**
     * @notice Allows a contract to remove an approver for a given chain ID
     * @param chainId The ID of the chain
     * @param approver The address of the approver to remove
     */
    function removeApprover(string memory chainId, string memory approver) external {
        approvers[chainId][msg.sender][approver] = false;
    }

    /**
     * @notice Executes the transaction.
     * @param sourceChain_ The name of the source chain.
     * @param sourceAddress_ The address of the source.
     * @param payload_ The payload of the transaction.
     */
    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload_
    ) internal override {
        // Decode the payload to get the necessary data
        (address safe, address to, bytes memory data, uint256 value,) = abi.decode(payload_, (address, address, bytes, uint256, uint256));
        
        // Generate a unique message ID using the nonce and originAddress
        bytes32 messageId = keccak256(data);

        // Check if the message has already been processed
        if (processedMessages[messageId]) {
            revert MessageAlreadyProcessed(messageId);
        }

        // Check if the sender is approved for the decoded safe
        if(!approvers[sourceChain_][safe][sourceAddress_]) {
            revert NotApproved(sourceAddress_);
        }
        // Call the createExecution function from the ExecutionModule
        ExecutionModule(executionModule).createExecution(safe, to, value, data, 0);
    }
}