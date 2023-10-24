pragma solidity ^0.8.15;

import "./interfaces/IExecutionModule.sol";

/**
 * @title Interface for the Message Recipient (Hyperlane)
 * @notice This interface allows other contracts to call the handle function from the Message Recipient contract.
 */
interface IMessageRecipient {
    /**
     * @notice Handle an interchain message
     * @param _origin Domain ID of the chain from which the message came
     * @param _sender Address of the message sender on the origin chain as bytes32
     * @param _body Raw bytes content of message body
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _body
    ) external;
}

/**
 * @title HyperLaneProcessor Contract
 * @notice This contract is used for processing messages from the Hyperlane cross chain bridge
 */
contract HyperLaneProcessor is IMessageRecipient {
    address public executionModule;
    address public hyperlane;
    uint32 public origin;

    mapping(uint256 => mapping(address => mapping(address => bool))) private approvers;
    mapping(uint256 => mapping(address => address[])) private approversArray;
    mapping(address => mapping(bytes32 => bool)) private processedTransfers;

    /**
     * @notice Constructor for the HyperLaneProcessor contract
     * @param _executionModule Address of the execution module
     * @param _hyperlane Address of the hyperlane
     * @param _origin Origin of the chain
     */
    constructor(address _executionModule, address _hyperlane, uint64 _origin) {
        executionModule = _executionModule;
        hyperlane = _hyperlane;
        origin = _origin;
    }

    /**
     * @notice Add an approver for a specific origin
     * @param _origin Origin of the chain
     * @param approver Address of the approver
     */
    function addApprover(uint64 _origin, address approver) external {
        approvers[_origin][msg.sender][approver] = true;
        approversArray[_origin][msg.sender].push(approver);
    }

    /**
     * @notice Remove an approver for a specific origin
     * @param _origin Origin of the chain
     * @param approver Address of the approver
     */
    function removeApprover(uint64 _origin, address approver) external {
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
    function getApprovers(uint64 _origin, address safe) external view returns (address[] memory) {
        return approversArray[_origin][safe];
    }

    /**
     * @notice Handle an interchain message
     * @param _origin Domain ID of the chain from which the message came
     * @param _sender Address of the message sender on the origin chain as bytes32
     * @param _body Raw bytes content of message body
     * @return bytes memory
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _body
    ) 
        external override
        returns (bytes memory) {
        require(msg.sender == hyperlane, "HyperlaneOnly");

        // Check if the transferId has been processed before
        require(!processedTransfers[_to][_sender], "TransferAlreadyProcessed");
        processedTransfers[_to][_sender] = true;

        // Decode message
        (address _to, uint256 _value, bytes memory _data, Enum.Operation _operation) = abi.decode(
            _body,
            (address, uint256, bytes, Enum.Operation)
        );

        // Check if the sender is approved for the decoded safe
        if(!approvers[_origin][_to][_sender]) {
            revert NotApproved(_sender);
        }

        // Execute transaction against target
        IExecutionModule(executionModule).createExecution(_to, _value, _data, _operation, 0);
    }
}