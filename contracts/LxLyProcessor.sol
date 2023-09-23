// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "./interfaces/IBridgeMessageReceiver.sol";
import "./interfaces/IPolygonZkEVMBridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
 * LxLyProposer is a contract that uses the message layer of the PolygonZkEVMBridge to propose transactions
 */
contract LxLyProposer is IBridgeMessageReceiver, Ownable {
    // Global Exit Root address
    IPolygonZkEVMBridge public immutable polygonZkEVMBridge;
    ExecutionModule public immutable executionModule;

    // Current network identifier
    uint32 public immutable networkID;

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
    event ProposerReceived(address originAddress, uint32 originNetwork, bytes data);

    error NotPolygonZkEVMBridge(address sender);

    /**
     * @notice Verify merkle proof and withdraw tokens/ether
     * @param originAddress Origin address that the message was sended
     * @param originNetwork Origin network that the message was sended ( not usefull for this contract)
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

        // Extract the necessary data
        (address safe, address to, bytes memory data, uint256 value) = abi.decode(data, (address, address, bytes, uint256));

        // Call the createExecution function from the ExecutionModule
        executionModule.createExecution(safe, to, value, data, 0);

        emit ProposerReceived(originAddress, originNetwork, data);
    }
}