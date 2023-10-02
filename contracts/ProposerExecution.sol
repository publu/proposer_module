// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing the necessary Gnosis Safe contracts
import "@gnosis.pm/safe-contracts/contracts/interfaces/ISignatureValidator.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

interface IGnosisSafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Enum.Operation operation)
        external
        returns (bool success);
}

/// @title ProposerExecutionModule
/// @notice A module for the Gnosis Safe Multisig wallet which allows allowlisted addresses 
/// to propose transactions with a delay before execution. Only the multisig can add or remove
/// addresses from the whitelist.
contract ProposerExecutionModule {
    
    // The delay before a proposed transaction can be executed, default to no delay
    uint256 public delay = 0;

    // The maximum delay that can be set.
    uint256 public constant maxDelay = 4 weeks;

    // Mapping to store the nonce for each Safe address
    mapping(address => uint256) public safeNonce;

    // Execution struct represents a proposed transaction.
    struct Execution {
        uint256 timestamp;       // When the transaction was proposed.
        address to;              // The recipient address of the transaction.
        uint256 value;           // The amount of ether to send.
        bytes data;              // Data payload of the transaction.
        Enum.Operation operation; // Operation type of the transaction.
        uint8 executed;           // Whether the transaction has been executed or not.
    }

    // SafeSettings struct to keep track of proposers and delay for each Safe 
    struct SafeSettings {
        mapping(address => bool) proposerWhitelist;  // A mapping of allowlisted proposers.
        uint256 delay;                               // Delay specific to this Safe.
    }

    // A mapping to store Safe settings for each Safe address.
    mapping(address => SafeSettings) public safeSettings;

    // A mapping to store all the proposed transactions.
    mapping(address => mapping(bytes32 => Execution)) public executionRequests;

    // Emitted when a new proposed transaction is created.
    event ExecutionCreated(address indexed safe, bytes32 indexed executionRequestId);

    // Emitted when the delay is changed.
    event DelayChanged(address indexed safe, uint256 newDelay);

    // Emitted when a proposer is added to the whitelist.
    event ProposerAdded(address indexed safe, address indexed proposer);

    // Emitted when a proposer is removed from the whitelist.
    event ProposerRemoved(address indexed safe, address indexed proposer);

    // Emitted when an execution request is cleared.
    event ExecutionCleared(address indexed safe, bytes32 indexed executionRequestId);

    // Modifier to check if the caller is a allowlisted proposer.
    modifier onlyValidProposer(address safe) {
        require(safeSettings[safe].proposerWhitelist[msg.sender], "Caller is not a proposer");
        _;
    }

    constructor() {}

    /// @notice Allows a allowlisted proposer to propose a transaction.
    /// @param safe The address of the Gnosis Safe.
    /// @param to The address of the recipient.
    /// @param value The amount of ether to send.
    /// @param data The data payload of the transaction.
    /// @param operation The operation type of the transaction.
    function createExecution(
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external onlyValidProposer(safe) {
        require(to != address(0), "Invalid target address");

        // Create a unique identifier for the proposed transaction.
        // Adding a nonce to the executionRequestId to ensure uniqueness for repeated transactions.
        // Nonce is a global variable that is incremented for each safe to ensure uniqueness.
        uint256 nonce = safeNonce[safe]++;
        bytes32 executionRequestId = keccak256(abi.encodePacked(safe, to, value, data, operation, nonce));
        require(executionRequests[safe][executionRequestId].timestamp == 0, "Execution request already exists");

        // Create the proposed transaction and store it.
        executionRequests[safe][executionRequestId] = Execution({
            timestamp: block.timestamp,
            to: to,
            value: value,
            data: data,
            operation: operation,
            executed: 0
        });

        emit ExecutionCreated(safe, executionRequestId);
    }

    /// @notice Internal function for executing transactions from module.
    /// @param safe The address of the Gnosis Safe.
    /// @param executionRequestId The unique identifier of the proposed transaction.
    /// @param fast A boolean indicating if the transaction should bypass the delay.
    function _executeFromModule(address safe, bytes32 executionRequestId, bool fast) internal {
        Execution storage request = executionRequests[safe][executionRequestId];

        // Check that the request exists.
        require(request.timestamp > 0, "Execution request not found");
        // Check if the delay for this transaction has passed or if the transaction should bypass the delay.
        require((block.timestamp >= request.timestamp + delay) || fast, "Delay period not passed for request");
        // Check that the request has not been executed.
        require(request.executed == 0, "Execution request already executed");

        // Mark the transaction as executed.
        request.executed = 1;

        // Execute the transaction using Gnosis Safe's execTransactionFromModule function.
        require(
            IGnosisSafe(safe).execTransactionFromModule(
                request.to, 
                request.value, 
                request.data, 
                request.operation
            ), 
            "Could not execute transaction"
        );
    }

    /// @notice Allows anyone to execute a transaction after its delay.
    /// @param safe The address of the Gnosis Safe.
    /// @param executionRequestId The unique identifier of the proposed transaction.
    function executeExecution(address safe, bytes32 executionRequestId) external {
        _executeFromModule(safe, executionRequestId, false);
    }

    /// @notice Allows an approved proposer to execute a transaction immediately, bypassing the delay.
    /// @param safe The address of the Gnosis Safe.
    /// @param executionRequestId The unique identifier of the proposed transaction.
    function executeExecutionFast(address safe, bytes32 executionRequestId) external onlyValidProposer(safe) {
        _executeFromModule(safe, executionRequestId, true);
    }

    /// @notice Allows anyone to clear multiple executions if their proposers were removed from the whitelist.
    /// @param safe The address of the Gnosis Safe.
    /// @param executionRequestIds An array of unique identifiers of the proposed transactions.
    function clearExecutions(address safe, bytes32[] calldata executionRequestIds) external {
        for (uint256 i = 0; i < executionRequestIds.length; i++) {
            Execution storage request = executionRequests[safe][executionRequestIds[i]];

            // Check that the request exists.
            require(request.timestamp > 0, "Execution request not found");
            // Check that the request has not been executed.
            require(request.executed==0, "Execution request already executed");
            // Check if the proposer is no longer allowlisted.
            require(!safeSettings[safe].proposerWhitelist[msg.sender], "Proposer still allowlisted");

            // Clear the execution request.
            executionRequests[safe][executionRequestIds[i]].executed=2;

            emit ExecutionCleared(safe, executionRequestIds[i]);
        }
    }

    /// @notice Allows the manager (Safe Multisig) to change the delay period.
    /// @param _delay The new delay in seconds.
    function changeDelay(uint256 _delay) external {
        require(_delay <= maxDelay, "Delay too long");
        safeSettings[msg.sender].delay = _delay;
        emit DelayChanged(msg.sender,_delay);
    }

    /// @notice Allows the manager (Safe Multisig) to add a proposer to the whitelist.
    /// @param proposer The address of the proposer to add.
    function addProposer(address proposer) external {
        safeSettings[msg.sender].proposerWhitelist[proposer] = true;
        emit ProposerAdded(msg.sender, proposer);
    }

    /// @notice Allows the manager (Safe Multisig) to remove a proposer from the whitelist.
    /// @param proposer The address of the proposer to remove.
    function removeProposer(address proposer) external {
        safeSettings[msg.sender].proposerWhitelist[proposer] = false;
        emit ProposerRemoved(msg.sender, proposer);
    }
}
