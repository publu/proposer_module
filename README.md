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

## Running tests

tbd

