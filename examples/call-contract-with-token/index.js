'use strict';

const {
    getDefaultProvider,
    Contract,
    constants: { AddressZero },
} = require('ethers');
const {
    utils: { deployContract },
} = require('@axelar-network/axelar-local-dev');

const { sleep } = require('../../utils');
const DistributionExecutable = require('../../artifacts/examples/call-contract-with-token/DistributionExecutable.sol/DistributionExecutable.json');
const Gateway = require('../../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol/IAxelarGateway.json');
const IERC20 = require('../../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol/IERC20.json');

async function deploy(chain, wallet) {
    console.log(`Deploying DistributionExecutable for ${chain.name}.`);
    const contract = await deployContract(wallet, DistributionExecutable, [chain.gateway, chain.gasReceiver]);
    chain.distributionExecutable = contract.address;
    console.log(`Deployed DistributionExecutable for ${chain.name} at ${chain.distributionExecutable}.`);
}

async function test(chains, wallet, options) {
    const args = options.args || [];
    const getGasPrice = options.getGasPrice;
    const source = chains.find((chain) => chain.name === (args[0] || 'Avalanche'));
    const destination = chains.find((chain) => chain.name === (args[1] || 'Fantom'));
    const message = args[2] || "default message";
    const amount = (parseFloat(args[3]) * 1e18).toString();
    const accounts = args.slice(4);

    if (accounts.length === 0) accounts.push(wallet.address);

    for (const chain of [source, destination]) {
        const provider = getDefaultProvider(chain.rpc);
        chain.wallet = wallet.connect(provider);
        chain.contract = new Contract(chain.distributionExecutable, DistributionExecutable.abi, chain.wallet);
        chain.gateway = new Contract(chain.gateway, Gateway.abi, chain.wallet);
        const usdcAddress = await chain.gateway.tokenAddresses('WMATIC');
        chain.usdc = new Contract(usdcAddress, IERC20.abi, chain.wallet);

        console.log(chain.name, chain.distributionExecutable)

    }

    async function logAccountBalances() {
        for (const account of accounts) {
            console.log(`${account} has ${(await destination.usdc.balanceOf(account)) / 1e18} WMATIC`);
        }
    }
    
    async function logMessage(paymentCounter){
        
        console.log(`Message for payment is: ${await destination.contract.paymentMessages(paymentCounter)}`);
    }

    const paymentCounter = await destination.contract.paymentCounter();
   
    console.log('--- Initially ---');
    console.log(`Payment no: ${paymentCounter.toString()}`);
    await logAccountBalances();
    await logMessage(paymentCounter);

    const gasLimit = 1e6;
    const gasPrice = await getGasPrice(source, destination, AddressZero);

    // const balance = BigInt(await destination.usdc.balanceOf(accounts[0]));

    const approveTx = await source.usdc.approve(source.contract.address, amount);
    await approveTx.wait();

    const sendTx = await source.contract.sendToMany(destination.name, destination.distributionExecutable, accounts, message, 'WMATIC', amount, {
        value: BigInt(Math.floor(gasLimit * gasPrice)),
    });
    await sendTx.wait();

    await sleep(8000);
    
    console.log('--- After ---');
    await logAccountBalances();
    await logMessage(paymentCounter);
}

module.exports = {
    deploy,
    test,
};
