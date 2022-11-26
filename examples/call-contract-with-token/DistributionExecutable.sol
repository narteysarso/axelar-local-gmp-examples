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
    Counters.Counter public callCounter;
    // Track recipient address and messages
    mapping(address => mapping(uint => string)) public recipientMessages;

    constructor(address gateway_, address gasReceiver_) AxelarExecutable(gateway_) {
        gasReceiver = IAxelarGasService(gasReceiver_);
    }

    function sendToMany(
        string memory destinationChain,
        string memory destinationAddress,
        address[] calldata destinationAddresses,
        string calldata destinationMessages,
        string memory symbol,
        uint256 amount
    ) external payable {
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), amount);
        bytes memory payload = abi.encode(destinationAddresses);

        // convert `destinationMessages` to bytes
        bytes memory _destinationMessages = abi.encode(destinationMessages); 

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
        gateway.callContractWithToken(destinationChain, destinationAddress, payload, _destinationMessages, symbol, amount);
    }

    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        bytes calldata messages,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        address[] memory recipients = abi.decode(payload, (address[]));
        string memory _messages = abi.decode(messages,(string[]));
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);
        uint _callCountIndex = callCounter.current();

        callCounter.increment();

        uint256 sentAmount = amount / recipients.length;
        for (uint256 i = 0; i < recipients.length; i++) {
            recipientMessages[recipients[i]][_callCountIndex] = _messages;
            IERC20(tokenAddress).transfer(recipients[i], sentAmount);
        }

    }
}
