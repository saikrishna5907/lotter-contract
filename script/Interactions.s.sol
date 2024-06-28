// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscription(
        address vrfCoordinator
    ) public returns (uint64) {
        // create a subscription
        console.log("Creating a subscription on ChainId:", block.chainid);

        vm.startBroadcast();
        uint64 subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your Subscription Id:", block.chainid);
        return subscriptionId;
    }

    function createSubscriptionFromConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , , ) = helperConfig
            .activeNetworkConfig();

        return createSubscription(vrfCoordinator);
    }

    function run() external returns (uint64) {
        // create a subscription
        return createSubscriptionFromConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionWithConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            address linkTokenAddress,

        ) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subscriptionId, linkTokenAddress);
    }

    function fundSubscriptionLocalChainId(
        address vrfCoordinator,
        uint64 subscriptionId
    ) private {
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
            subscriptionId,
            FUND_AMOUNT
        );
        vm.stopBroadcast();
    }

    function fundSubscriptionLinkToken(
        address vrfCoordinator,
        uint64 subscriptionId,
        address linkTokenAddress
    ) private {
        vm.startBroadcast();
        LinkToken(linkTokenAddress).transferAndCall(
            vrfCoordinator,
            FUND_AMOUNT,
            abi.encode(subscriptionId)
        );
        vm.stopBroadcast();
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address linkTokenAddress
    ) public {
        console.log("Funding subscription with:", subscriptionId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("Using linkTokenAddress", linkTokenAddress);
        console.log("On ChainId:", block.chainid);

        if (block.chainid == 31337) {
            fundSubscriptionLocalChainId(vrfCoordinator, subscriptionId);
        } else {
            fundSubscriptionLinkToken(
                vrfCoordinator,
                subscriptionId,
                linkTokenAddress
            );
        }

        console.log("Subscription funded with:", FUND_AMOUNT);
    }

    function run() external {
        fundSubscriptionWithConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            ,

        ) = helperConfig.activeNetworkConfig();

        addConsumer(lottery, vrfCoordinator, subscriptionId);
    }

    function addConsumer(
        address lottery,
        address vrfCoordinator,
        uint64 subscriptionId
    ) public {
        console.log("Adding consumer contract:", lottery);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("Using Subscription:", subscriptionId);
        console.log("On ChainId:", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            lottery
        );
        vm.stopBroadcast();
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );

        addConsumerUsingConfig(lottery);
    }
}
