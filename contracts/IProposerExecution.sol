// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

interface IProposerExecutionModule {
    function createExecution(
        address safe,
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external;
    function executeExecutions(address safe, bytes32[] calldata executionRequestIds) external;
    function clearExecutions(address safe, bytes32[] calldata executionRequestIds) external;
    function changeDelay(uint256 _delay) external;
    function addProposer(address proposer) external;
    function removeProposer(address proposer) external;
}
