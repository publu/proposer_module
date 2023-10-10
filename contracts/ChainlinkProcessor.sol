// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "./interfaces/IExecutionModule.sol";

interface IRouterClient {
  error UnsupportedDestinationChain(uint64 destChainSelector);
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();

  /// @notice Checks if the given chain ID is supported for sending/receiving.
  /// @param chainSelector The chain to check.
  /// @return supported is true if it is supported, false if not.
  function isChainSupported(uint64 chainSelector) external view returns (bool supported);

  /// @notice Gets a list of all supported tokens which can be sent or received
  /// to/from a given chain id.
  /// @param chainSelector The chainSelector.
  /// @return tokens The addresses of all tokens that are supported.
  function getSupportedTokens(uint64 chainSelector) external view returns (address[] memory tokens);

  /// @param destinationChainSelector The destination chainSelector
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return fee returns guaranteed execution fee for the specified message
  /// delivery to destination chain
  /// @dev returns 0 fee on invalid message.
  function getFee(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Request a message to be sent to the destination chain
  /// @param destinationChainSelector The destination chain ID
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return messageId The message ID
  /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
  /// the overpayment with no refund.
  function ccipSend(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32);
}

/**
 * @title ChainlinkProcessor Contract
 * @notice This contract processes the messages received from Chainlink and forwards them for execution.
 * @dev This contract assumes integration with a Gnosis Safe-like system.
 */
contract ChainlinkProcessor is CCIPReceiver {
    
    /// @notice Error to indicate function can only be called by an approved address.
    error NotApproved(address sender);

    /// @notice Error to indicate function can only be called from any other 
    error SameSourceChain();

    /// @notice Address of the ExecutionModule contract.
    address public executionModule;
    uint64 public chainId;

    event MessageProcessed(Client.Any2EVMMessage message);
    event DataDecoded(address safe, address to, bytes data, uint256 value);

    /// @notice Mapping to track the approved senders on different chains
    mapping(uint256 => mapping(address => mapping(address => bool))) private approvers;
    mapping(uint256 => mapping(address => address[])) private approversArray;
    mapping(address => uint64[]) private usedChainIds;
    mapping(bytes32 => bool) public processedMessages;
    
    /**
     * @notice Constructor to set the ExecutionModule and Chainlink addresses
     * @param _executionModule Address of the ExecutionModule
     * @param _chainlink Address of the Chainlink
     */
    constructor(address _executionModule, address _chainlink, uint64 _chainId) CCIPReceiver(_chainlink) {
        executionModule = _executionModule;
        chainId = _chainId;
    }

    /**
     * @dev Event emitted when an approver is added.
     */
    event ApproverAdded(uint64 indexed _chainId, address indexed safe, address indexed approver);

    /**
     * @dev Event emitted when an approver is removed.
     */
    event ApproverRemoved(uint64 indexed _chainId, address indexed safe, address indexed approver);

    /**
     * @notice Allows a contract to add an approver for a given chain ID
     * @param _chainId The ID of the chain
     * @param approver The address of the approver to add
     */
    function addApprover(uint64 _chainId, address approver) external {
        approvers[_chainId][msg.sender][approver] = true;
        approversArray[_chainId][msg.sender].push(approver);
        if (!isChainIdUsed(msg.sender, _chainId)) {
            usedChainIds[msg.sender].push(_chainId);
        }
        emit ApproverAdded(_chainId, msg.sender, approver);
    }

    /**
     * @notice Allows a contract to remove an approver for a given chain ID
     * @param _chainId The ID of the chain
     * @param approver The address of the approver to remove
     */
    function removeApprover(uint64 _chainId, address approver) external {
        approvers[_chainId][msg.sender][approver] = false;
        for (uint256 i = 0; i < approversArray[_chainId][msg.sender].length; i++) {
            if (approversArray[_chainId][msg.sender][i] == approver) {
                approversArray[_chainId][msg.sender][i] = approversArray[_chainId][msg.sender][approversArray[_chainId][msg.sender].length - 1];
                approversArray[_chainId][msg.sender].pop();
                break;
            }
        }
        emit ApproverRemoved(_chainId, msg.sender, approver);
    }

    /**
     * @notice Returns the array of approvers for a given chain ID
     * @param _chainId The ID of the chain
     * @return The array of approvers
     */
    function getApprovers(uint64 _chainId, address safe) external view returns (address[] memory) {
        return approversArray[_chainId][safe];
    }

    /**
     * @notice Returns the array of all used chain IDs for a given Safe
     * @param safe The address of the Safe
     * @return The array of chain IDs
     */
    function getChainIds(address safe) external view returns (uint64[] memory) {
        return usedChainIds[safe];
    }

    /**
     * @notice Checks if a chain ID has been used for a given Safe
     * @param safe The address of the Safe
     * @param _chainId The ID of the chain
     * @return True if the chain ID has been used, false otherwise
     */
    function isChainIdUsed(address safe, uint64 _chainId) internal view returns (bool) {
        for (uint256 i = 0; i < usedChainIds[safe].length; i++) {
            if (usedChainIds[safe][i] == _chainId) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Processes the received messages from Chainlink and forwards them for execution
     * @param message The message received from Chainlink
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        processMessage(message);
    }

    /**
     * @notice Clones the _ccipReceive function but isn't an override
     * @param message The message received from Chainlink
     */
    function processMessage( Client.Any2EVMMessage memory message) internal {
        // Store the messageId in a mapping to prevent repeated messageIds
        require(!processedMessages[message.messageId], "MessageId has already been processed");
        processedMessages[message.messageId] = true;

        // Extract the necessary data
        (address safe, address to, bytes memory data, uint256 value) = abi.decode(message.data, (address, address, bytes, uint256));
        emit MessageProcessed(message);
        emit DataDecoded(safe, to, data, value);

        // CCIP sends address as a bytes
        address sender;
        bytes memory senderBytes = message.sender;

        assembly {
            sender := mload(add(senderBytes, 32))
        }

        //check if sourceChain is not same as current chain
        if(message.sourceChainSelector == chainId) {
            revert SameSourceChain();
        }
        
        // Check if the sender is approved for the decoded safe
        if(!approvers[message.sourceChainSelector][safe][sender]) {
            revert NotApproved(sender);
        }

        // Call the createExecution function from the ExecutionModule
        ExecutionModule(executionModule).createExecution(safe, to, value, data, 0);
    }

    /*
    function sendMessage(uint64 destinationChainSelector, address receiver, bytes memory payload, uint256 _gasLimit) public payable returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: payload, // bytes payload
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: _gasLimit, strict: false}) // Additional arguments, setting gas limit and non-strict sequency mode
            ),
            feeToken: address(0) // Setting feeToken to zero address, indicating native asset will be used for fees
        });

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(chainlink);

        // Get the fee required to send the message
        uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);

        // Send the message through the router and store the returned message ID
        messageId = router.ccipSend{value: fees}(
            destinationChainSelector,
            evm2AnyMessage
        );

        // Return the message ID
        return messageId;
    }*/
}