// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 lotteryDuration;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        address linkTokenAddres;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
            return;
        }
        activeNetworkConfig = getOrCreateAnvilEthConfig();
    }

    function getSepoliaNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                lotteryDuration: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 1893,
                requestConfirmations: 4,
                callbackGasLimit: uint32(500000),
                linkTokenAddres: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether; //0.25 LINK token
        uint96 gasPriceLink = 1e9; //1 gwei token
        LinkToken linkToken = new LinkToken();
        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                lotteryDuration: 30,
                vrfCoordinator: address(vrfCoordinatorMock),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                requestConfirmations: 4,
                callbackGasLimit: 500000,
                linkTokenAddres: address(linkToken),
                deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
            });
    }
}
