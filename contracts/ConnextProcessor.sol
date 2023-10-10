// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "./interfaces/IXReceiver.sol";
import "./interfaces/IExecutionModule.sol";

contract ConnextProcessor is IXReceiver {
    address public executionModule;
    address public connext;
    uint32 public chainId;

    mapping(uint256 => mapping(address => mapping(address => bool))) private approvers;
    mapping(uint256 => mapping(address => address[])) private approversArray;
    mapping(address => mapping(bytes32 => bool)) private processedTransfers;

    constructor(address _executionModule, address _connext, uint64 _chainId) {
        executionModule = _executionModule;
        connext = _connext;
        chainId = _chainId;
    }

    function addApprover(uint64 _chainId, address approver) external {
        approvers[_chainId][msg.sender][approver] = true;
        approversArray[_chainId][msg.sender].push(approver);
    }

    function removeApprover(uint64 _chainId, address approver) external {
        approvers[_chainId][msg.sender][approver] = false;
        for (uint256 i = 0; i < approversArray[_chainId][msg.sender].length; i++) {
            if (approversArray[_chainId][msg.sender][i] == approver) {
                approversArray[_chainId][msg.sender][i] = approversArray[_chainId][msg.sender][approversArray[_chainId][msg.sender].length - 1];
                approversArray[_chainId][msg.sender].pop();
                break;
            }
        }
    }

    function getApprovers(uint64 _chainId, address safe) external view returns (address[] memory) {
        return approversArray[_chainId][safe];
    }

    function xReceive(
        bytes32 transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes memory _callData
    ) 
        external override
        returns (bytes memory) {
        require(msg.sender == connext, "ConnextOnly");

        // Check if the transferId has been processed before
        require(!processedTransfers[_to][transferId], "TransferAlreadyProcessed");
        processedTransfers[_to][transferId] = true;

        // Decode message
        (address _to, uint256 _value, bytes memory _data, Enum.Operation _operation) = abi.decode(
            _callData,
            (address, uint256, bytes, Enum.Operation)
        );

        // Check if the sender is approved for the decoded safe
        if(!approvers[_origin][_to][_originSender]) {
            revert NotApproved(_originSender);
        }

        // Execute transaction against target
        IExecutionModule(executionModule).createExecution(_to, _value, _data, _operation, 0);
    }
}