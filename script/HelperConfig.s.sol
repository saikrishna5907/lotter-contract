// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint96 MOCK_BASE_FEE = 0.25 ether; //0.25 LINK token
    uint96 MOCK_GAS_PRICE_LINK = 1e9; //1 gwei token
    // LINK / ETH price
    int256 MOCK_WEI_PER_UNIT_LINK = 1e18; //1 LINK token
    uint256 public constant ETH_SEPOLIA_ZKSYNC_CHAIN_ID = 300;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__NetworkConfigNotFound(uint256 chainId);
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 lotteryDuration;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        address linkTokenAddress;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaNetworkConfig();
        networkConfigs[
            ETH_SEPOLIA_ZKSYNC_CHAIN_ID
        ] = getZKZyncSepoliaNetworkConfig();
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }

    function getNetworkConfigByChainId(
        uint256 chainId
    ) private returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        }
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        }

        revert HelperConfig__NetworkConfigNotFound(chainId);
    }

    function getZKZyncSepoliaNetworkConfig()
        private
        view
        returns (NetworkConfig memory)
    {
        // when zkSync is available for chainLink vrf we will update this
    }

    function getSepoliaNetworkConfig()
        private
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                lotteryDuration: 30,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 1893,
                requestConfirmations: 4,
                callbackGasLimit: uint32(500000),
                linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0x36615Cf349d7F6344891B1e7CA7C72883F5dc049
            });
    }

    function getOrCreateAnvilEthConfig()
        private
        returns (NetworkConfig memory)
    {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        address account = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38; // DEFAULT_SENDER from forge-std Base.sol
        LinkToken linkToken = new LinkToken();
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            lotteryDuration: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // random number not 0
            requestConfirmations: 4,
            callbackGasLimit: 500000,
            linkTokenAddress: address(linkToken),
            account: account
        });
        return localNetworkConfig;
    }
}
