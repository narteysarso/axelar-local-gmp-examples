//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import "@openzeppelin/contracts/utils/Counters.sol";

contract DistributionExecutable is AxelarExecutable {
    using Counters for Counters.Counter;

    IAxelarGasService public immutable gasReceiver;

    // Track the number of calls
    Counters.Counter public paymentCounter;

    // Track payment messages
     mapping(uint => string) public paymentMessages;

    constructor(address gateway_, address gasReceiver_) AxelarExecutable(gateway_) {
        gasReceiver = IAxelarGasService(gasReceiver_);
    }

    function sendToMany(
        string memory destinationChain,
        string memory destinationAddress,
        address[] calldata destinationAddresses,
        string calldata paymentMessage,
        string memory symbol,
        uint256 amount
    ) external payable {
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), amount);

        // Encode both `paymentMessages` and `destinationAddresses` as part of payload
        bytes memory payload = abi.encode(
            abi.encode(destinationAddresses), 
            abi.encode(paymentMessage)
        );

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCallWithToken{ value: msg.value }(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                symbol,
                amount,
                msg.sender
            );
        }
        
        gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, amount);
    }

    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        // Decode `paymentMessages` and `destinationAddresses` from payload
        (bytes memory _addresses, bytes memory _message)= abi.decode(payload, (bytes, bytes ));

        address[] memory recipients = abi.decode(_addresses, (address[]));

        address tokenAddress = gateway.tokenAddresses(tokenSymbol);
        
        string memory message = abi.decode(_message, (string));

        uint256 sentAmount = amount / recipients.length;

        // Store message in `paymentMessages mapping`
        paymentMessages[paymentCounter.current()] = message;

        paymentCounter.increment();

        for (uint256 i = 0; i < recipients.length; i++) {
            IERC20(tokenAddress).transfer(recipients[i], sentAmount);

        }

    }

}
