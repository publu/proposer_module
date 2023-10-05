# Execution Module

The execution module is an extension that interfaces with the Gnosis Safe. It enables scheduled execution of transactions after a predetermined delay. Each proposed transaction is associated with an identifier, ensuring a unique reference for future interactions such as execution or clearance.

All transaction executions are specific to a Safe and its corresponding execution request identifier.

This is not about direct, immediate execution but involves a delay to allow potential interventions or other conditional checks before the actual transaction occurs.

## Setting up Execution Requests

The module is designed to provide scheduled transaction functionality for any Gnosis Safe without requiring each Safe to deploy its module. Sharing this module across different Safes can reduce redundancy and associated gas costs.

To propose a new transaction for delayed execution, the Safe needs to create an execution request. Each execution request is uniquely identified by an `executionRequestId` which serves as a reference for future interactions.

Once the delay period associated with a request has passed, the request can be executed. It's crucial to ensure the transaction has not been executed before and that the delay requirement is met.

## Execution of Transactions

Transaction execution is handled by the `executeExecution` function. The function checks the following:

1. The validity of the `executionRequestId`.
2. The delay period associated with the request has passed.
3. The request has not been executed before.

If all these checks pass, the transaction associated with the request is executed using the Gnosis Safe's `execTransactionFromModule` function.

Multiple transaction executions can be batched in one go using the `executeExecutions` function, leading to potential gas savings.

## Removing Execution Requests

An execution request can be cleared from the system if not needed anymore. This is essential for efficient memory usage and to avoid unnecessary storage costs. Clearing a request ensures it cannot be executed in the future.

## Considerations

- Always ensure adequate checks before executing a transaction, especially in batched scenarios, as the failure of one transaction in a batch might lead to the failure of the entire batch.
- As this module introduces delayed execution, it's essential to factor in the state changes that might occur in the delay period.

## Architecture

The execution requests are stored in a mapping structure `executionRequests`, keyed by the Safe address and the unique `executionRequestId`. The stored `Execution` struct contains all the necessary details about the transaction, including the recipient, value, data, and operation type. Each request also maintains its timestamp and an executed flag to ensure each transaction is only executed once.

the contracts are:

zkEVM Proposer Module:
https://zkevm.polygonscan.com/address/0x1EaF18086C07D4d6a59B94277F80204274Ccc54d

this is the createExecution test from an EOA:
https://polygonscan.com/tx/0xae9e6b334cfe1d6ac4bb6d648f604527bd728a9e431ab61cd937879fc8dcd44e#eventlog

This is it being executed (verifying that safe module works):
https://polygonscan.com/tx/0xd3eaa7e48a31ef7aba2d67c557d2ecceb5ce94040a8189c7b3d3fb8bd84ec0f


Axelar execution:

https://axelarscan.io/gmp/0xdfd625647f4985429e69cb860cb15068396dcc7cf7d3058c1fe3931187c74da3

Proposer Execution Module:
https://polygonscan.com/address/0x02668453F6138bE9BBA9946de8472228c4400109#writeContract

Axelar Execution Proposer:
https://polygonscan.com/address/0xD2BeD6f2b32832ddA397C9FcA6d1E503d627C49d#writeContract


Axelar gateway contracts:
https://docs.axelar.dev/dev/reference/mainnet-contract-addresses

Short description:
Crosschain governance project utilizing Axelar and LxLy bridge for seamless interoperability and transaction execution.

Description:
This project is a crosschain governance system that leverages the power of Axelar, LxLy bridge, and Chainlink's cross chain interoperability protocol. It includes several smart contracts that interact with each other to facilitate crosschain transactions. The system allows for the execution of transactions not only from an Externally Owned Account (EOA), but also from any multisig. This means an Ethereum multisig can message any other chain to execute a change, as demonstrated in the provided polygonscan links. The project also integrates with the Axelar gateway contracts, the Proposer Execution Module, and Chainlink for enhanced functionality and interoperability.




