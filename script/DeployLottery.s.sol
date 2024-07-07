// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            // create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, ) = createSubscription.createSubscription(
                config.vrfCoordinator,
                config.account
            );

            // fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.linkTokenAddress,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        Lottery lottery = new Lottery(
            config.entranceFee,
            config.lotteryDuration,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.requestConfirmations,
            config.callbackGasLimit
        );

        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(lottery),
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );

        return (lottery, helperConfig);
    }
}
