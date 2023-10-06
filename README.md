```
 _______                                                        
|_   __ \                                                       
  | |__) |_ .--.   .--.   _ .--.    .--.   .--.  .---.  _ .--.  
  |  ___/[ `/'`\]/ .'`\ \[ '/'`\ \/ .'`\ \( (`\]/ /__\\[ `/'`\] 
 _| |_    | |    | \__. | | \__/ || \__. | `'.'.| \__., | |     
|_____|  [___]    '.__.'  | ;.__/  '.__.' [\__) )'.__.'[___]    
                         [__|                                   
```

# Execution Module Overview

The Execution Module is an extension that interfaces with the Gnosis Safe, providing a mechanism for scheduled transaction execution after a predetermined delay. Each proposed transaction is uniquely identified, allowing for future interactions such as execution or clearance.

The module is not designed for immediate execution, but rather introduces a delay to allow for potential interventions or additional conditional checks before the transaction is processed.

## Execution Requests Setup

The Execution Module offers scheduled transaction functionality for any Gnosis Safe without the need for each Safe to deploy its own module. This shared module approach reduces redundancy and associated gas costs.

To schedule a transaction for delayed execution, the Safe creates an execution request. Each request is uniquely identified by an `executionRequestId`, which serves as a reference for future interactions.

Once the delay period for a request has passed, the request can be executed, provided the transaction has not been executed before and the delay requirement has been met.

## Transaction Execution

Transaction execution is managed by the `executeExecution` function. This function validates the `executionRequestId`, ensures the delay period has passed, and verifies the request has not been executed before.

If all these conditions are met, the transaction associated with the request is executed using the Gnosis Safe's `execTransactionFromModule` function.

The `executeExecutions` function allows for batching multiple transaction executions, potentially saving on gas costs.

## Execution Requests Removal

Execution requests can be removed from the system when no longer needed, optimizing memory usage and reducing unnecessary storage costs. Once a request is cleared, it cannot be executed in the future.

## Key Considerations

- Always perform adequate checks before executing a transaction, particularly in batched scenarios, as the failure of one transaction in a batch could cause the entire batch to fail.
- Given the delayed execution introduced by this module, it's crucial to consider potential state changes that might occur during the delay period.

## System Architecture

Execution requests are stored in a `executionRequests` mapping structure, keyed by the Safe address and the unique `executionRequestId`. The `Execution` struct stores all necessary transaction details, including the recipient, value, data, and operation type. Each request also maintains its timestamp and an executed flag to ensure each transaction is only executed once.

The contracts are:

zkEVM Proposer Module:
https://zkevm.polygonscan.com/address/0x1EaF18086C07D4d6a59B94277F80204274Ccc54d

Test for createExecution from an EOA:
https://polygonscan.com/tx/0xae9e6b334cfe1d6ac4bb6d648f604527bd728a9e431ab61cd937879fc8dcd44e#eventlog

Execution verification (verifying that safe module works):
https://polygonscan.com/tx/0xd3eaa7e48a31ef7aba2d67c557d2ecceb5ce94040a8189c7b3d3fb8bd84ec0f

Axelar execution:

https://axelarscan.io/gmp/0xdfd625647f4985429e69cb860cb15068396dcc7cf7d3058c1fe3931187c74da3

Proposer Execution Module:
https://polygonscan.com/address/0x02668453F6138bE9BBA9946de8472228c4400109#writeContract

Axelar Execution Proposer:
https://polygonscan.com/address/0xD2BeD6f2b32832ddA397C9FcA6d1E503d627C49d#writeContract

Axelar gateway contracts:
https://docs.axelar.dev/dev/reference/mainnet-contract-addresses

Project Summary:
This project is a crosschain governance system that leverages the power of Axelar, LxLy bridge, and Chainlink's cross chain interoperability protocol. It includes several smart contracts that interact with each other to facilitate crosschain transactions. The system allows for the execution of transactions not only from an Externally Owned Account (EOA), but also from any multisig. This means an Ethereum multisig can message any other chain to execute a change, as demonstrated in the provided polygonscan links. The project also integrates with the Axelar gateway contracts, the Proposer Execution Module, and Chainlink for enhanced functionality and interoperability.




