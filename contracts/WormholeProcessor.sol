pragma solidity ^0.8.15;

import "./interfaces/IExecutionModule.sol";

/**
 * @notice Interface for a contract which can receive Wormhole messages.
 */
interface IWormholeReceiver {
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalVaas,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable;
}

/**
 * @title WormholeProcessor Contract
 * @notice This contract is used for processing messages from the Wormhole cross chain bridge
 */
contract WormholeProcessor is IWormholeReceiver {
    address public executionModule;
    uint16 public origin;
    address public wormhole;

    mapping(uint256 => mapping(address => mapping(address => bool))) private approvers;
    mapping(uint256 => mapping(address => address[])) private approversArray;
    mapping(address => mapping(bytes32 => bool)) private processedTransfers;

    /**
     * @notice Constructor for the WormholeProcessor contract
     * @param _executionModule Address of the execution module
     * @param _origin Origin of the chain
     * @param _wormhole Origin of the chain
     */
    constructor(address _executionModule, uint16 _origin, address _wormhole) {
        executionModule = _executionModule;
        origin = _origin;
        wormhole = _wormhole;
    }

    /**
     * @notice Add an approver for a specific origin
     * @param _origin Origin of the chain
     * @param approver Address of the approver
     */
    function addApprover(uint16 _origin, address approver) external {
        approvers[_origin][msg.sender][approver] = true;
        approversArray[_origin][msg.sender].push(approver);
    }

    /**
     * @notice Remove an approver for a specific origin
     * @param _origin Origin of the chain
     * @param approver Address of the approver
     */
    function removeApprover(uint16 _origin, address approver) external {
        approvers[_origin][msg.sender][approver] = false;
        for (uint256 i = 0; i < approversArray[_origin][msg.sender].length; i++) {
            if (approversArray[_origin][msg.sender][i] == approver) {
                approversArray[_origin][msg.sender][i] = approversArray[_origin][msg.sender][approversArray[_origin][msg.sender].length - 1];
                approversArray[_origin][msg.sender].pop();
                break;
            }
        }
    }

    /**
     * @notice Get the list of approvers for a specific origin and safe
     * @param _origin Origin of the chain
     * @param safe Address of the safe
     * @return Array of approvers
     */
    function getApprovers(uint16 _origin, address safe) external view returns (address[] memory) {
        return approversArray[_origin][safe];
    }

    /**
     * @notice Handle an interchain message
     * @param payload Raw bytes content of message body
     * @param sourceAddress Address of the message sender on the origin chain as bytes32
     * @param sourceChain Domain ID of the chain from which the message came
     * @return bytes memory
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalVaas,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) 
        external override payable
        returns (bytes memory) {
        require(msg.sender == wormhole, "WormholeOnly");
        // Check if the transferId has been processed before
        require(!processedTransfers[sourceAddress][deliveryHash], "TransferAlreadyProcessed");
        processedTransfers[sourceAddress][deliveryHash] = true;

        // Decode message
        (address _to, uint256 _value, bytes memory _data, Enum.Operation _operation) = abi.decode(
            payload,
            (address, uint256, bytes, Enum.Operation)
        );

        // Check if the sender is approved for the decoded safe
        if(!approvers[sourceChain][_to][sourceAddress]) {
            revert NotApproved(sourceAddress);
        }

        // Execute transaction against target
        IExecutionModule(executionModule).createExecution(_to, _value, _data, _operation, 0);
    }
}