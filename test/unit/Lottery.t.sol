// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {Test, console2} from "forge-std/Test.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {FailReceiver} from "../../script/Interactions.s.sol";

contract LotteryTest is Test, CodeConstants {
    /* Events */
    event EnteredLottery(address indexed player);
    event RandomWordsFulfilled(
        uint256 indexed requestId,
        uint256 outputSeed,
        uint256 indexed subId,
        uint96 payment,
        bool nativePayment,
        bool success,
        bool onlyPremium
    );

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    Lottery lottery;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    FailReceiver failReceiver;

    modifier makeTimePast() {
        vm.warp(block.timestamp + config.lotteryDuration + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier enterLotteryWithOnePlayer() {
        lottery.enterLottery{value: config.entranceFee}();
        _;
    }

    modifier enterLotteryMultiplePlayers(uint256 numberOfPlayers) {
        for (uint256 i = 1; i <= numberOfPlayers; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            lottery.enterLottery{value: config.entranceFee}();
        }
        _;
    }

    modifier performUpKeepAndRecordLogs() {
        vm.recordLogs();
        lottery.performUpKeep("");
        _;
    }

    modifier lotteryContractFundBalance() {
        vm.deal(address(lottery), 10 ether);
        _;
    }

    modifier lotteryFundPlayerBalance() {
        hoax(PLAYER, STARTING_USER_BALANCE);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployLottery deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();

        config = helperConfig.getConfig();
        failReceiver = new FailReceiver();
    }

    /*//////////////////////////////////////////////////////////////
                             GET VALUES
    //////////////////////////////////////////////////////////////*/

    function testLotteryInitializesWithCorrectEntranceFee()
        public
        lotteryFundPlayerBalance
    {
        assert(lottery.getEntranceFee() == config.entranceFee);
    }

    function testLotteryInLiveDuration() public lotteryFundPlayerBalance {
        assert(lottery.getLotteryDuration() == config.lotteryDuration);
    }

    function testLotteryInitializesWithCorrectGasLane()
        public
        lotteryFundPlayerBalance
    {
        assert(lottery.getGasLane() == config.gasLane);
    }

    // function testLotteryInitializesWithCorrectVrfCoordinator() public view {
    //     assert(lottery.getVrfCoordinator() == vrfCoordinator);
    // }

    function testLotteryInitializesWithCorrectRequestConfirmations()
        public
        lotteryFundPlayerBalance
    {
        assert(
            lottery.getRequestConfirmations() == config.requestConfirmations
        );
    }

    function testLotteryInitializesWithCorrectCallbackGasLimit()
        public
        lotteryFundPlayerBalance
    {
        assert(lottery.getCallbackGasLimit() == config.callbackGasLimit);
    }

    /*//////////////////////////////////////////////////////////////
                            ENTER LOTTERY
    //////////////////////////////////////////////////////////////*/

    function testLotteryInitializesInOpenState()
        public
        lotteryFundPlayerBalance
    {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    function testLotteryRevertWhenYouDontPayEnoughEntranceFee()
        public
        lotteryFundPlayerBalance
    {
        vm.expectRevert(Lottery.Lottery__NotEnoughEthToEnterLottery.selector);
        lottery.enterLottery{value: config.entranceFee - 1}();
    }

    function testLotteryRevertWhenYouDontPayEntranceFee()
        public
        lotteryFundPlayerBalance
    {
        vm.expectRevert(Lottery.Lottery__NotEnoughEthToEnterLottery.selector);
        lottery.enterLottery();
    }

    function testLotterySavesPlayerWhenTheyEnter()
        public
        lotteryFundPlayerBalance
    {
        lottery.enterLottery{value: config.entranceFee}();
        assert(lottery.getPlayer(0) == PLAYER);
    }

    function testLotterySetsEnteredLotteryForPlayerToTrue()
        public
        lotteryFundPlayerBalance
    {
        lottery.enterLottery{value: config.entranceFee}();
        assertTrue(lottery.hasEntered(PLAYER));
    }

    function testEmitsEnteredLotteryEventWhenPlayerEnters()
        public
        lotteryFundPlayerBalance
    {
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(PLAYER); // expecting this event to be emitted when below line enters the lottery executed
        lottery.enterLottery{value: config.entranceFee}();
    }

    function testCannotEnterLotteryWhenWinnerIsCalculating()
        public
        lotteryFundPlayerBalance
        makeTimePast
        enterLotteryWithOnePlayer
    {
        lottery.performUpKeep("");

        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        lottery.enterLottery{value: config.entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                            CHECK UP KEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpKeepReturnsFalseIfNoBalance()
        public
        lotteryFundPlayerBalance
        makeTimePast
    {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseWhenNotOpen()
        public
        lotteryFundPlayerBalance
        makeTimePast
        enterLotteryWithOnePlayer
    {
        lottery.performUpKeep("");

        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfThereAreNoPlayersYet()
        public
        lotteryFundPlayerBalance
        makeTimePast
        lotteryContractFundBalance
    {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepIfEnoughNotPassed()
        public
        lotteryFundPlayerBalance
    {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepRetunrsTrueWhenAllConditionsAreMet()
        public
        lotteryFundPlayerBalance
        makeTimePast
        enterLotteryWithOnePlayer
    {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(upKeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM UP KEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpKeepIfCheckUpKeepReturnsTrueUpdatesState()
        public
        lotteryFundPlayerBalance
        makeTimePast
        enterLotteryWithOnePlayer
    {
        lottery.performUpKeep("");

        assert(
            lottery.getLotteryState() == Lottery.LotteryState.CALCULATING_WINNER
        );
    }

    function testPerformUpKeepEmitsRequestId()
        public
        lotteryFundPlayerBalance
        makeTimePast
        enterLotteryWithOnePlayer
        performUpKeepAndRecordLogs
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // this is emitted by vrfcoordinator emit RandomWordsRequested
        bytes32 requestId = logs[0].topics[2];

        assert(uint256(requestId) > 0);
    }

    function testRevertPerformUpKeepIfCheckUpKeepReturnsFalse()
        public
        lotteryFundPlayerBalance
        enterLotteryWithOnePlayer
    {
        // Encode the error signature and parameters

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__LotteryUpkeepNotNeeded.selector,
                config.entranceFee,
                1,
                Lottery.LotteryState.OPEN
            )
        );

        lottery.performUpKeep("");
    }

    /*//////////////////////////////////////////////////////////////
                        FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    function testFulFillRandamWordsCanOnlyCalledAfterPerformUpKeep(
        uint256 randomRequestId // foundry generate random number and tests this function multiple times
    )
        public
        skipFork
        lotteryFundPlayerBalance
        makeTimePast
        enterLotteryWithOnePlayer
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function testFulfillRandomWordsAndPickWinnerAndSendMoney()
        public
        skipFork
        lotteryFundPlayerBalance
        makeTimePast
        enterLotteryWithOnePlayer
        enterLotteryMultiplePlayers(5)
        performUpKeepAndRecordLogs
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 requestId = abi.decode(logs[0].data, (uint256));

        assert(lottery.getPlayersCount() > 0);
        assert(
            lottery.getLotteryState() == Lottery.LotteryState.CALCULATING_WINNER
        );

        uint256 lotteryPrize = address(lottery).balance;
        uint256 winnerBalanceBeforeWon = STARTING_USER_BALANCE -
            config.entranceFee;

        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(
            requestId,
            address(lottery)
        );

        Vm.Log[] memory afterWinnerPickLogs = vm.getRecordedLogs();
        address winner = lottery.getRecentWinner();

        assert(lottery.getPlayersCount() == 0);
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
        assert(winner != address(0));
        assert(lottery.getStartTime() == block.timestamp);
        assert(
            address(uint160(uint256(afterWinnerPickLogs[0].topics[1]))) ==
                address(winner)
        );
        assert(
            address(winner).balance == winnerBalanceBeforeWon + lotteryPrize
        );
    }

    // This test is expected to fail and it does revert Lottery__WinnerTransferAmountFailed but then after RandomWordsFulfilled is emitted so it fails
    // function testLotteryWinnerTransferFails() public makeTimePast {
    //     // Add FailReceiver as a player
    //     address payable failReceiverAddress = payable(address(failReceiver));
    //     hoax(failReceiverAddress, 1 ether); // Fund FailReceiver with 1 ether
    //     lottery.enterLottery{value: config.entranceFee}();

    //     vm.recordLogs();
    //     // Assume we are in a state where we can pick a winner
    //     lottery.performUpKeep("");

    //     // Simulate Chainlink VRF response
    //     uint256[] memory randomWords = new uint256[](1);
    //     randomWords[0] = uint256(
    //         keccak256(abi.encodePacked(block.timestamp, block.prevrandao))
    //     );
    //     Vm.Log[] memory logs = vm.getRecordedLogs();
    //     uint256 requestId = abi.decode(logs[0].data, (uint256));

    //     // Expect the revert error

    //     VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(
    //         requestId,
    //         address(lottery)
    //     );
    // }
}
