// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing the necessary Gnosis Safe contracts
import "@gnosis.pm/safe-contracts/contracts/interfaces/ISignatureValidator.sol";
import "IProposerExectution";
import "@gnosis.pm/zodiac/contracts/core/Module.sol";

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

/// @title ProposerExecutionModuleZodiac
/// @notice A module for the Gnosis Safe Multisig wallet which allows allowlisted addresses 
/// to propose transactions with a delay before execution. Only the multisig can add or remove
/// addresses from the whitelist. This module is part of Zodiac, an expansion pack for DAOs.
/// Zodiac is a collection of tools built according to an open standard. The Zodiac open standard
/// enables DAOs to act more like constellations, connecting protocols, platforms, and chains,
/// no longer confined to monolithic designs.
contract ProposerExecutionModuleZodiac is Module, IProposerExectution {
    
    // The delay before a proposed transaction can be executed, default to no delay
    uint256 public delay = 0;

    // The maximum delay that can be set.
    uint256 public constant maxDelay = 4 weeks;

    // Mapping to store the nonce for each Safe address
    uint256 public safeNonce;

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
        address[] proposers;                         // An array of allowlisted proposers.
        bytes32[] executions;                         // An array of proposed executions
        uint256 delay;                               // Delay specific to this Safe.
    }

    // A mapping to store Safe settings for each Safe address.
    SafeSettings public safeSettings;

    // A mapping to store all the proposed transactions.
    mapping(bytes32 => Execution) public executionRequests;

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

    // Error to show when the caller is not a proposer
    error CallerIsNotAProposer();

    // Error to show when the target address is invalid
    error InvalidTargetAddress();

    // Error to show when the execution request already exists
    error ExecutionRequestAlreadyExists();

    // Error to show when the execution request is not found
    error ExecutionRequestNotFound();

    // Error to show when the delay period has not passed for the request
    error DelayPeriodNotPassedForRequest();

    // Error to show when the execution request has already been executed
    error ExecutionRequestAlreadyExecuted();

    // Error to show when the transaction could not be executed
    error CouldNotExecuteTransaction();

    // Error to show when the proposer is still allowlisted
    error ProposerStillAllowlisted();

    // Error to show when the delay is too long
    error DelayTooLong();

    // Error to show when the proposer has already been added
    error ProposerAlreadyAdded();

    // Modifier to check if the caller is a allowlisted proposer.
    modifier onlyValidProposer() {
        if (!proposerWhitelist[msg.sender]) {
            revert CallerIsNotAProposer();
        }
        _;
    }

    /**
     * @dev Contract constructor.
     * @param _owner The address of the owner.
     * @param _avatar The address of the avatar.
     * @param _target The address of the target.
     */
    constructor(
        address _owner,
        address _avatar,
        address _target
    ) {
        bytes memory initParams = abi.encode(
            _owner,
            _avatar,
            _target
        );
        setUp(initParams);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams ABI encoded initialization params, in the same order as the parameters for this contract's constructor.
    /// @notice Only callable once.
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (
            address _owner,
            address _avatar,
            address _target
        ) = abi.decode(initializeParams, (address, address, address));

        setAvatar(_avatar);
        setTarget(_target);
        transferOwnership(_owner);

        emit ModuleSetUp(owner(), avatar, target);
    }
    /// @notice Allows a allowlisted proposer to propose a transaction.
    /// @param to The address of the recipient.
    /// @param value The amount of ether to send.
    /// @param data The data payload of the transaction.
    /// @param operation The operation type of the transaction.
    function createExecution(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external onlyValidProposer() {
        if (to == address(0)) {
            revert InvalidTargetAddress();
        }

        // Create a unique identifier for the proposed transaction.
        // Adding a nonce to the executionRequestId to ensure uniqueness for repeated transactions.
        // Nonce is a global variable that is incremented for each safe to ensure uniqueness.
        uint256 nonce = safeNonce++;
        bytes32 executionRequestId = keccak256(abi.encodePacked(to, value, data, operation, nonce));
        if (executionRequests[executionRequestId].timestamp != 0) {
            revert ExecutionRequestAlreadyExists();
        }

        // Create the proposed transaction and store it.
        executionRequests[executionRequestId] = Execution({
            timestamp: block.timestamp,
            to: to,
            value: value,
            data: data,
            operation: operation,
            executed: 0
        });

        // Add the executionRequestId to the executions array in the SafeSettings for the safe.
        safeSettings.executions.push(executionRequestId);

        emit ExecutionCreated(safe, executionRequestId);
    }

    /// @notice Internal function for executing transactions from module.
    /// @param safe The address of the Gnosis Safe.
    /// @param executionRequestId The unique identifier of the proposed transaction.
    /// @param fast A boolean indicating if the transaction should bypass the delay.
    function _executeFromModule(address safe, bytes32 executionRequestId, bool fast) internal {
        Execution storage request = executionRequests[executionRequestId];

        // Check that the request exists.
        if (request.timestamp == 0) {
            revert ExecutionRequestNotFound();
        }
        // Check if the delay for this transaction has passed or if the transaction should bypass the delay.
        if (block.timestamp < request.timestamp + delay && !fast) {
            revert DelayPeriodNotPassedForRequest();
        }
        // Check that the request has not been executed.
        if (request.executed != 0) {
            revert ExecutionRequestAlreadyExecuted();
        }

        // Mark the transaction as executed.
        request.executed = 1;

        // Execute the transaction using Gnosis Safe's execTransactionFromModule function.
        if (!exec(
                request.to, 
                request.value, 
                request.data, 
                request.operation
            )) {
            revert CouldNotExecuteTransaction();
        }

        // Remove the executionRequestId from the executions array in the SafeSettings for the safe.
        for (uint256 i = 0; i < safeSettings.executions.length; i++) {
            if (safeSettings.executions[i] == executionRequestId) {
                safeSettings.executions[i] = safeSettings.executions[safeSettings.executions.length - 1];
                safeSettings.executions.pop();
                break;
            }
        }
    }

    /// @notice Allows anyone to execute a transaction after its delay.
    /// @param executionRequestId The unique identifier of the proposed transaction.
    function executeExecution(bytes32 executionRequestId) external {
        _executeFromModule(executionRequestId, false);
    }

    /// @notice Allows an approved proposer to execute a transaction immediately, bypassing the delay.
    /// @param executionRequestId The unique identifier of the proposed transaction.
    function executeExecutionFast(bytes32 executionRequestId) external onlyOwner() {
        _executeFromModule(executionRequestId, true);
    }

    /// @notice Allows anyone to clear multiple executions if their proposers were removed from the whitelist.
    /// @param safe The address of the Gnosis Safe.
    /// @param executionRequestIds An array of unique identifiers of the proposed transactions.
    function clearExecutions(bytes32[] calldata executionRequestIds) external {
        for (uint256 i = 0; i < executionRequestIds.length; i++) {
            Execution storage request = executionRequests[executionRequestIds[i]];

            // Check that the request exists.
            if (request.timestamp == 0) {
                revert ExecutionRequestNotFound();
            }
            // Check that the request has not been executed.
            if (request.executed != 0) {
                revert ExecutionRequestAlreadyExecuted();
            }
            // Check if the proposer is no longer allowlisted.
            if (safeSettings.proposerWhitelist[msg.sender]) {
                revert ProposerStillAllowlisted();
            }

            // Clear the execution request.
            executionRequests[executionRequestIds[i]].executed = 2;

            // Remove the executionRequestId from the executions array in the SafeSettings for the safe.
            for (uint256 j = 0; j < safeSettings.executions.length; j++) {
                if (safeSettings.executions[j] == executionRequestIds[i]) {
                    safeSettings.executions[j] = safeSettings.executions[safeSettings.executions.length - 1];
                    safeSettings.executions.pop();
                    break;
                }
            }

            emit ExecutionCleared(executionRequestIds[i]);
        }
    }

    /// @notice Allows the owner (Safe Multisig) to change the delay period.
    /// @param _delay The new delay in seconds.
    function changeDelay(uint256 _delay) external onlyOwner {
        if (_delay > maxDelay) {
            revert DelayTooLong();
        }
        safeSettings.delay = _delay;
        emit DelayChanged(msg.sender,_delay);
    }

    /// @notice Allows the owner (Safe Multisig) to add a proposer to the whitelist.
    /// @param proposer The address of the proposer to add.
    function addProposer(address proposer) external onlyOwner {
        if (safeSettings.proposerWhitelist[proposer]) {
            revert ProposerAlreadyAdded();
        }
        safeSettings.proposerWhitelist[proposer] = true;
        safeSettings.proposers.push(proposer);
        emit ProposerAdded(msg.sender, proposer);
    }

    /// @notice Allows the owner (Safe Multisig) to remove a proposer from the whitelist.
    /// @param proposer The address of the proposer to remove.
    function removeProposer(address proposer) external onlyOwner {
        safeSettings.proposerWhitelist[proposer] = false;
        for (uint256 i = 0; i < safeSettings.proposers.length; i++) {
            if (safeSettings.proposers[i] == proposer) {
                safeSettings.proposers[i] = safeSettings.proposers[safeSettings.proposers.length - 1];
                safeSettings.proposers.pop();
                break;
            }
        }
        emit ProposerRemoved(msg.sender, proposer);
    }

    /// @notice Returns the array of approvers for a given Safe.
    /// @param safe The address of the Gnosis Safe.
    function getProposers(address safe) external view returns (address[] memory) {
        return safeSettings.proposers;
    }

    /// @notice Returns the array of execution request ids for a given Safe.
    /// @param safe The address of the Gnosis Safe.
    function getExecutionIds(address safe) external view returns (bytes32[] memory) {
        return safeSettings.executions;
    }
}