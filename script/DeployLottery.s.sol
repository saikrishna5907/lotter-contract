// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 lotteryDuration,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint16 requestConfirmations,
            uint32 callbackGasLimit,
            address linkTokenAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator
            );

            // fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                linkTokenAddress
            );
        }

        vm.startBroadcast();
        Lottery lottery = new Lottery(
            entranceFee,
            lotteryDuration,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit
        );

        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(lottery),
            vrfCoordinator,
            subscriptionId
        );

        return (lottery, helperConfig);
    }
}
