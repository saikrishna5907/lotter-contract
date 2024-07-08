// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        // create a subscription
        console2.log(
            "Creating a subscription on ChainId:",
            block.chainid,
            account
        );

        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console2.log("Your Subscription Id:", subscriptionId);
        return (subscriptionId, vrfCoordinator);
    }

    function createSubscriptionFromConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        return createSubscription(config.vrfCoordinator, config.account);
    }

    function run() external returns (uint256, address) {
        // create a subscription
        return createSubscriptionFromConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint96 private constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionWithConfig() private {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        fundSubscription(
            config.vrfCoordinator,
            config.subscriptionId,
            config.linkTokenAddress,
            config.account
        );
    }

    function fundSubscriptionLocalChainId(
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) private {
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
            subscriptionId,
            FUND_AMOUNT * 100
        );
        vm.stopBroadcast();
    }

    function fundSubscriptionLinkToken(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkTokenAddress,
        address account
    ) private {
        vm.startBroadcast(account);
        LinkToken(linkTokenAddress).transferAndCall(
            vrfCoordinator,
            FUND_AMOUNT,
            abi.encode(subscriptionId)
        );
        vm.stopBroadcast();
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkTokenAddress,
        address account
    ) public {
        console2.log("Funding subscription with:", subscriptionId);
        console2.log("Using vrfCoordinator", vrfCoordinator);
        console2.log("Using linkTokenAddress", linkTokenAddress);
        console2.log("On ChainId:", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            fundSubscriptionLocalChainId(
                vrfCoordinator,
                subscriptionId,
                account
            );
        } else {
            fundSubscriptionLinkToken(
                vrfCoordinator,
                subscriptionId,
                linkTokenAddress,
                account
            );
        }

        console2.log("Subscription funded with:", FUND_AMOUNT);
    }

    function run() external {
        fundSubscriptionWithConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(
        address mostRecentlyDeployedLottery
    ) private {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        addConsumer(
            mostRecentlyDeployedLottery,
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );
    }

    function addConsumer(
        address mostRecentlyDeployedLottery,
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console2.log(
            "Adding contract:",
            mostRecentlyDeployedLottery,
            "as a consumer"
        );
        console2.log("Using vrfCoordinator:", vrfCoordinator);
        console2.log("Using Subscription:", subscriptionId);
        console2.log("On ChainId:", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            mostRecentlyDeployedLottery
        );
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployedLottery = DevOpsTools
            .get_most_recent_deployment("Lottery", block.chainid);

        addConsumerUsingConfig(mostRecentlyDeployedLottery);
    }
}

contract FailReceiver {
    // Receive function to reject any ETH transfer
    receive() external payable {
        revert("Transfer failed");
    }
}
