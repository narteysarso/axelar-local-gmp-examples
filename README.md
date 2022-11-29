# Axelar cross-chain dApp
In this work [/examples/call-contract-with-tokens](https://github.com/narteysarso/axelar-local-gmp-examples/blob/main/examples/call-contract-with-token)/`DistributionExecutable.sol` is modified to allow sending tokens with a message. 

To achieve this:
- A new `paymentMessage` parameter is added to the `sendToMany` function on the contract on line 29.
    ```
        function sendToMany(
            string memory destinationChain,
            string memory destinationAddress,
            address[] calldata destinationAddresses,
            string calldata paymentMessage, // message parameter
            string memory symbol,
            uint256 amount
        ) external payable
    ```

- The payload of `callContractWithToken` of `IAxelarGateway` instance `gateway` is abi encoded with both `destinationAddress` and `paymentMessage` on line 38
 ```
    // Encode both `paymentMessages` and `destinationAddresses` as part of payload
    bytes memory payload = abi.encode(
        abi.encode(destinationAddresses), 
        abi.encode(paymentMessage)
    );

 ```
 - line 55
 ```
    gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, amount);

 ```

 - The payload is decoded in `_executeWithToken` in two steps. First to get the bytes for destinationAddress and paymentMessage, then to decoded again to get thier respective values in their dataTypes. onl

 ```
        // Decode `paymentMessages` and `destinationAddresses` from payload
        (bytes memory _addresses, bytes memory _message)= abi.decode(payload, (bytes, bytes ));

        // Abi decode recipient addresses
        address[] memory recipients = abi.decode(_addresses, (address[]));
        
        // Abi decode message
        string memory message = abi.decode(_message, (string));
 ```

- Next message is set to the state variable `paymentMessages` mapping the transaction number `paymentCounter` to the message
```
 // Store message in `paymentMessages mapping`
    paymentMessages[paymentCounter.current()] = message;

    paymentCounter.increment();
```

- And tokens are transfered to recipients as usual
```
    for (uint256 i = 0; i < recipients.length; i++) {
        IERC20(tokenAddress).transfer(recipients[i], sentAmount);

    }
```

# Contracts Address
Contracts are deployed to Avalanche and Polygon

- Deployed DistributionExecutable for Avalanche at [0x9B6e6F904F45D8b71e82d4F296677810A6Ac63AA](https://testnet.snowtrace.io/address/0x9B6e6F904F45D8b71e82d4F296677810A6Ac63AA).

- Deployed DistributionExecutable for Polygon at [0x0660bF3b6bD1f5167E8F54E3a781577BfE5f6660](https://mumbai.polygonscan.com/address/0x0660bF3b6bD1f5167E8F54E3a781577BfE5f6660).

- Example transaction: [0x8682579fd98c5feb8cd90d38c5c50f8a561d02c929f7d33fe824fda327db06b4](https://testnet.axelarscan.io/gmp/0x8682579fd98c5feb8cd90d38c5c50f8a561d02c929f7d33fe824fda327db06b4)


## One-time setup

Install [nodejs](https://nodejs.org/en/download/). Run `node -v` to check your installation.

Version 16 is required. If needed you can switch your node version (or lower, if you are on a higher version) via

```bash
sudo npm i -g n
sudo n v16.15.0
```

Clone this repo:

```bash
git clone https://github.com/axelarnetwork/axelar-local-gmp-examples.git
```

Build contracts and tests:

```bash
npm ci
npm run build
```

## Set up deployer key

```bash
cp .env.example .env
```

Then update to your own private key.

## Deploy and test each example

In order to run the examples against the local emulator, cd to `axelar-local-gmp-examples` and run

```bash
node scripts/createLocal
```

Leave this node running on a separate terminal before deploying and testing the dApps.

Each example has several arguments as described below:

| Variable                                  | Valid Values                                       | Default                                                                                    | Example                                    | Notes                                                   |
| ----------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------ | ------------------------------------------------------- |
| network                                   | local, testnet                                     | no default                                                                                 | local                                      |                                                         |
| source-chain                              | Moonbeam, Avalanche, Fantom, Ethereum, and Polygon | `Avalanche`                                                                                | "Moonbeam" or 'Moonbeam'                   | case-sensitive                                          |
| destination-chain                         | Moonbeam, Avalanche, Fantom, Ethereum, and Polygon | `Fantom`                                                                                   | "Avalanche" or 'Avalanche'                 | case-sensitive                                          |
| message for call-contract                 | any string                                         | `Hello ${destination.name} from ${source.name}, it is ${new Date().toLocaleTimeString()}.` | 'Hello World'                              |                                                         |
| message for nonced-execution and send-ack | any string                                         | `Hello, the time is ${time}.`                                                              | 'Hello World'                              |                                                         |
| amount                                    | integer or float                                   | `10`                                                                                       | 53                                         | Any non-integer is rounded down to the nearest integer. |
| account                                   | any wallet address                                 | no default                                                                                 | 0xBa86A5719722B02a5D5e388999C25f3333c7A9fb | case-sensitive.                                         |

Run the deploy and test code specific to each example described below.

To use defaults, substitute `${}` for any or all of the variables.

### Call contract

Relay a message from source-chain to destination-chain.

Deploy:

```bash
node scripts/deploy examples/call-contract [local|testnet]
```

Run the test:

```bash
node scripts/test examples/call-contract [local|testnet] ${"source-chain"} ${"destination-chain"} ${'message'}
```

#### Example

```bash
node scripts/deploy examples/call-contract local
node scripts/test examples/call-contract local "Moonbeam" "Avalanche" 'Hello World'
```

Output:

```
--- Initially ---
value at Avalanche is
--- After ---
value at Avalanche is Hello World
```

### Call contract with token

Send aUSDC from source-chain to destination-chain and distribute it equally among all accounts specified.

Deploy:

```bash
node scripts/deploy examples/call-contract-with-token [local|testnet]
```

Run the test:

```bash
node scripts/test examples/call-contract-with-token [local|testnet] ${"source-chain"} ${"destination-chain"} ${"Payment Message"} ${amount} ${account} ${account2} ...
```

#### Example

```bash
node scripts/deploy examples/call-contract-with-token local
node scripts/test examples/call-contract-with-token local "Avalance" "Polygon" "Payment message" 100 0xBa86A5719722B02a5D5e388999C25f3333c7A9fb
```

Output:

```
--- Initially ---
0xBa86A5719722B02a5D5e388999C25f3333c7A9fb has 100 aUSDC
--- After ---
0xBa86A5719722B02a5D5e388999C25f3333c7A9fb has 199 aUSDC
```

### Cross-chain token

Mints some token at source-chain and send it to destination-chain.

Deploy:

```bash
node scripts/deploy examples/cross-chain-token [local|testnet]
```

Run the test:

```bash
node scripts/test examples/cross-chain-token [local|testnet] ${"source-chain"} ${"destination-chain"} ${amount}
```

#### Example

```bash
node scripts/deploy examples/cross-chain-token local
node scripts/test examples/cross-chain-token local "Ethereum" "Fantom" 1
```

Output:

```
--- Initially ---
Balance at Ethereum is 0
Balance at Fantom is 0
--- After getting some token on the source chain ---
Balance at Ethereum is 1
Balance at Fantom is 0
--- After ---
Balance at Ethereum is 0
Balance at Fantom is 1
```

### Deposit address, send token

Two different examples. Send aUSDC from source-chain to destination-chain:

1. `deposit-address`: get an [Axelar deposit address](https://docs.axelar.dev/dev/tokens#get-a-deposit-address).
2. `send-token`: call an [Axelar Gateway contract](https://docs.axelar.dev/dev/tokens#call-sendtoken).

No smart contract to deploy for these examples.

If running on `testnet` then ensure that `0xBa86A5719722B02a5D5e388999C25f3333c7A9fb` is funded with aUSDC.

**Note:** We use `0xBa86A5719722B02a5D5e388999C25f3333c7A9fb` to deploy and test all examples. It's funded by default in the `local` environment when you run `createLocal`. To make sure that it's funded on all five supported testnets, run `node/printBalances`.

Run the `deposit-address` test:

```bash
node scripts/test examples/deposit-address [local|testnet] ${"source-chain"} ${"destination-chain"} ${amount}
```

Run the `send-token` test:

```bash
node scripts/test examples/send-token [local|testnet] ${"source-chain"} ${"destination-chain"} ${amount}
```

#### Example

```bash
node scripts/test examples/deposit-address local
node scripts/test examples/send-token local
```

Output:

```
--- Initially ---
Balance at Avalanche is 100000000
Balance at Fantom is 100000000
0xb54eA64537F3307907E06d3B93ccd4A3E711623f
--- After ---
Balance at Avalanche is 90000000
Balance at Fantom is 109000000
```

```
--- Initially ---
Balance of 0xBa86A5719722B02a5D5e388999C25f3333c7A9fb at Avalanche is 90000000
Balance of 0xBa86A5719722B02a5D5e388999C25f3333c7A9fb at Fantom is 109000000
--- After ---
Balance of 0xBa86A5719722B02a5D5e388999C25f3333c7A9fb at Avalanche is 80000000
Balance of 0xBa86A5719722B02a5D5e388999C25f3333c7A9fb at Fantom is 118000000
```

### Headers

Informs destination-chain of the last header of source-chain.

Deploy:

```bash
node scripts/deploy examples/headers [local|testnet]
```

Run the test:

```bash
node scripts/test examples/headers [local|testnet] ${"source-chain"} ${"destination-chain"}
```

#### Example

```bash
node scripts/deploy examples/headers local
node scripts/test examples/headers local "Fantom" "Moonbeam"
```

Output:

```
Success!
```

### NFT linker

Send the NFT that was originally minted at source-chain to destination-chain.

Deploy:

```bash
node scripts/deploy examples/nft-linker [local|testnet]
```

A single NFT is minted to the deployer (`0xBa86A5719722B02a5D5e388999C25f3333c7A9fb`) on each chain.

Run the test:

```bash
node scripts/test examples/nft-linker [local|testnet] ${"source-chain"} ${"destination-chain"}
```

It's not possible to send a duplicate NFT to a chain. The dApp fails when the NFT is already at the destination-chain.

#### Example

```bash
node scripts/deploy examples/nft-linker local
node scripts/test examples/nft-linker local "Avalanche" "Polygon"
```

Output:

```
--- Initially ---
Token that was originally minted at Moonbeam is at Moonbeam.
Token that was originally minted at Avalanche is at Avalanche.
Token that was originally minted at Fantom is at Fantom.
Token that was originally minted at Ethereum is at Ethereum.
Token that was originally minted at Polygon is at Polygon.
--- Then ---
Token that was originally minted at Moonbeam is at Moonbeam.
Token that was originally minted at Avalanche is at Polygon.
Token that was originally minted at Fantom is at Fantom.
Token that was originally minted at Ethereum is at Ethereum.
Token that was originally minted at Polygon is at Polygon.
```

### Nonced execution

Send a message from source-chain to destination-chain.

Deploy:

```bash
node scripts/deploy examples/nonced-execution [local|testnet]
```

Run the test:

```bash
node scripts/test examples/nonced-execution [local|testnet] ${"source-chain"} ${"destination-chain"} ${'message'}
```

#### Example

```bash
node scripts/deploy examples/nonced-execution local
node scripts/test examples/nonced-execution local ${} ${} ${}
```

Output:

```
--- Initially ---
Last message sent from Avalanche@0xBa86A5719722B02a5D5e388999C25f3333c7A9fb to Fantom was "" with a nonce of -1.
--- After ---
Last message sent from Avalanche@0xBa86A5719722B02a5D5e388999C25f3333c7A9fb to Fantom was "Hello, the time is 1654191658288." with a nonce of 0.
```

### Send ack

Send a message from source-chain to destination-chain.

Deploy:

```bash
node scripts/deploy examples/send-ack [local|testnet]
```

Run the test:

```bash
node scripts/test examples/send-ack [local|testnet] ${"source-chain"} ${"destination-chain"} ${'message'}
```

#### Example

```bash
node scripts/deploy examples/send-ack local
node scripts/test examples/send-ack local "Fantom" "Moonbeam" 'Received'
```

Output:

```
--- Initially ---
SendAckReceiverImplementation at Moonbeam has 0 messages and the last one is "".
--- After ---
SendAckReceiverImplementation at Moonbeam has 1 messages and the last one is "Received".
```

### Cross-chain lending

Supply collateral and borrow tokens from a satellite chain to a fork of Ethereum's mainnet using existing Compound Protocol. The script `scripts/createLocal` shouldn't be executed in order to run this test, the needed mainnet fork and the satellite chain are setup while running the test script.

Deploy:

No need for prior deployment. Everything is setup while running the test.

Run the test:

```bash
node scripts/test examples/cross-chain-lending local
```

#### Example

```bash
node scripts/test examples/cross-chain-lending local
```

Output:

```
------ Initial balances
User WBCT balance 100000000000000000000
User SUSHI balance 100000000000000000000
CompoundInterface CWBCT balance 0
CompoundInterface CSUSHI balance 0
------ Balances after supply and borrow
User WBCT balance 99989999999999000000
User SUSHI balance 100000000009999000000
CompoundInterface CWBCT balance 494939543254751868
CompoundInterface CSUSHI balance 0
------ Balances after repay and redeem
User WBCT balance 99999999999997999999
User SUSHI balance 99999999999998000000
CompoundInterface CWBCT balance 1
CompoundInterface CSUSHI balance 0
```
