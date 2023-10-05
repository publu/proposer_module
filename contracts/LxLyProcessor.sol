// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0;

import "./interfaces/IBridgeMessageReceiver.sol";
import "./interfaces/IPolygonZkEVMBridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IExecutionModule.sol";

/**
 * LxLyProposer is a contract that uses the message layer of the PolygonZkEVMBridge to propose transactions
 */
contract LxLyProposer is IBridgeMessageReceiver, Ownable {
    // Global Exit Root address
    IPolygonZkEVMBridge public immutable polygonZkEVMBridge;
    ExecutionModule public immutable executionModule;

    // Current network identifier
    uint32 public immutable networkID;

    // Mapping to track the approved senders on different networks
    mapping(uint32 => mapping(address => bool)) private approvers;
    
    /**
     * @dev Mapping to track the processed messages
     */
    mapping(bytes32 => bool) private processedMessages;

    /**
     * @param _polygonZkEVMBridge Polygon zkevm bridge address
     */
    constructor(IPolygonZkEVMBridge _polygonZkEVMBridge, ExecutionModule _executionModule) {
        polygonZkEVMBridge = _polygonZkEVMBridge;
        networkID = polygonZkEVMBridge.networkID();
        executionModule = _executionModule;
    }

    /**
     * @dev Emitted when a message is received from another network
     */
    event TransactionReceived(address originAddress, uint32 originNetwork, bytes data);

    error NotPolygonZkEVMBridge(address sender);
    error NotApproved(address sender, uint32 networkId);
    error MessageAlreadyProcessed(bytes32 messageId);

    /**
     * @notice Verify merkle proof and withdraw tokens/ether
     * @param originAddress Origin address that the message was sended
     * @param originNetwork Origin network that the message was sended
     * @param data Abi encoded metadata
     */
    function onMessageReceived(
        address originAddress,
        uint32 originNetwork,
        bytes memory data
    ) external payable override {
        // Can only be called by the bridge
        if(msg.sender != address(polygonZkEVMBridge)) 
            revert NotPolygonZkEVMBridge(msg.sender);

        // Check if the sender is approved for the decoded safe
        if(!approvers[originNetwork][originAddress]) {
            revert NotApproved(originAddress, originNetwork);
        }

        // Extract the necessary data
        (address safe, address to, bytes memory data, uint256 value, uint256 nonce) = abi.decode(data, (address, address, bytes, uint256, uint256));

        // Generate a unique message ID using the nonce and originAddress
        bytes32 messageId = keccak256(data);

        // Check if the message has already been processed
        if (processedMessages[messageId]) {
            revert MessageAlreadyProcessed(messageId);
        }

        // Mark the message as processed
        processedMessages[messageId] = true;

        // Call the createExecution function from the ExecutionModule
        executionModule.createExecution(safe, to, value, data, 0);

        emit TransactionReceived(originAddress, originNetwork, data);
    }
}