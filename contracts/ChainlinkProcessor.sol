// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * @title Interface for the ExecutionModule contract.
 * @notice This interface allows other contracts to call the createExecution function from the ExecutionModule contract.
 */
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
 * @title ChainlinkProcessor Contract
 * @notice This contract processes the messages received from Chainlink and forwards them for execution.
 * @dev This contract assumes integration with a Gnosis Safe-like system.
 */
contract ChainlinkProcessor {
    
    /// @notice Error to indicate function can only be called by an approved address.
    error NotApproved(address sender);

    /// @notice Error to indicate function can only be called from any other 
    error SameSourceChain();

    /// @notice Address of the ExecutionModule contract.
    address public executionModule;
    address public chainlink;

    /// @notice Mapping to track the approved senders on different chains
    mapping(uint256 => mapping(address => mapping(address => bool))) private approvers;

    error OnlyChainlink(address sender);

    /**
     * @notice Ensures only Chainlink can call the method
     */
    modifier onlyChainlink() {
        if(msg.sender != chainlink) 
            revert OnlyChainlink(msg.sender);
        _;
    }

    /**
     * @notice Constructor to set the ExecutionModule and Chainlink addresses
     * @param _executionModule Address of the ExecutionModule
     * @param _chainlink Address of the Chainlink
     */
    constructor(address _executionModule, address _chainlink) {
        executionModule = _executionModule;
        chainlink = _chainlink;
    }

    /**
     * @notice Allows a contract to add an approver for a given chain ID
     * @param chainId The ID of the chain
     * @param approver The address of the approver to add
     */
    function addApprover(uint256 chainId, address approver) external {
        approvers[chainId][msg.sender][approver] = true;
    }

    /**
     * @notice Allows a contract to remove an approver for a given chain ID
     * @param chainId The ID of the chain
     * @param approver The address of the approver to remove
     */
    function removeApprover(uint256 chainId, address approver) external {
        approvers[chainId][msg.sender][approver] = false;
    }

    /**
     * @notice Processes the received messages from Chainlink and forwards them for execution
     * @param any2EvmMessage The message received from Chainlink
     */
    function ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        external
        onlyChainlink
    {
        // nonce the message, or just the hash of the evm thing
        
        // Extract the necessary data
        (address safe, address to, bytes memory data, uint256 value) = abi.decode(any2EvmMessage.data, (address, address, bytes, uint256));


        address sender = abi.decode(any2EvmMessage.sender, (address));

        //check if sourceChain is not same as current chain
        if(any2EvmMessage.sourceChainSelector == block.chainid) {
            revert SameSourceChain();
        }

        // Check if the sender is approved for the decoded safe
        if(!approvers[any2EvmMessage.sourceChainSelector][safe][sender]) {
            revert NotApproved(sender);
        }

        // Call the createExecution function from the ExecutionModule
        ExecutionModule(executionModule).createExecution(safe, to, value, data, 0);
    }
}