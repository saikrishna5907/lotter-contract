// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployLottery} from "../script/DeployLottery.s.sol";
import {Lottery} from "../src/Lottery.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    /* Events */
    event EnteredLottery(address indexed player);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    Lottery lottery;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 lotteryDuration;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;
    address linkTokenAddres;
    uint256 deployerKey;

    modifier makeTimePast() {
        vm.warp(block.timestamp + lotteryDuration + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier enterLotteryWithOnePlayer() {
        lottery.enterLottery{value: entranceFee}();
        _;
    }

    modifier enterLotteryMultiplePlayers(uint256 numberOfPlayers) {
        for (uint256 i = 0; i < numberOfPlayers; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            lottery.enterLottery{value: entranceFee}();
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

    function setUp() public {
        DeployLottery deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();
        (
            entranceFee,
            lotteryDuration,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            ,

        ) = helperConfig.activeNetworkConfig();
        (, , , , , , , linkTokenAddres, deployerKey) = helperConfig
            .activeNetworkConfig();
        hoax(PLAYER, STARTING_USER_BALANCE);
    }

    function testLotteryInitializesWithCorrectEntranceFee() public view {
        assert(lottery.getEntranceFee() == entranceFee);
    }

    function testLotteryInLiveDuration() public view {
        assert(lottery.getLotteryDuration() == lotteryDuration);
    }

    function testLotteryInitializesWithCorrectGasLane() public view {
        assert(lottery.getGasLane() == gasLane);
    }

    // function testLotteryInitializesWithCorrectVrfCoordinator() public view {
    //     assert(lottery.getVrfCoordinator() == vrfCoordinator);
    // }

    function testLotteryInitializesWithCorrectRequestConfirmations()
        public
        view
    {
        assert(lottery.getRequestConfirmations() == requestConfirmations);
    }

    function testLotteryInitializesWithCorrectCallbackGasLimit() public view {
        assert(lottery.getCallbackGasLimit() == callbackGasLimit);
    }

    function testLotteryInitializesInOpenState() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    function testLotteryRevertWhenYouDontPayEnoughEntranceFee() public {
        vm.expectRevert(Lottery.Lottery__NotEnoughEthToEnterLottery.selector);
        lottery.enterLottery{value: entranceFee - 1}();
    }

    function testLotteryRevertWhenYouDontPayEntranceFee() public {
        vm.expectRevert(Lottery.Lottery__NotEnoughEthToEnterLottery.selector);
        lottery.enterLottery();
    }

    function testLotterySavesPlayerWhenTheyEnter() public {
        lottery.enterLottery{value: entranceFee}();
        assert(lottery.getPlayer(0) == PLAYER);
    }

    function testEmitsEnteredLotteryEventWhenPlayerEnters() public {
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(PLAYER); // expecting this event to be emitted when below line enters the lottery executed
        lottery.enterLottery{value: entranceFee}();
    }

    function testCannotEnterLotteryWhenWinnerIsCalculating()
        public
        makeTimePast
        enterLotteryWithOnePlayer
    {
        lottery.performUpKeep("");

        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        lottery.enterLottery{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfNoBalance() public makeTimePast {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseWhenNotOpen()
        public
        makeTimePast
        enterLotteryWithOnePlayer
    {
        lottery.performUpKeep("");

        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfThereAreNoPlayersYet()
        public
        makeTimePast
        lotteryContractFundBalance
    {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepIfEnoughNotPassed() public view {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepRetunrsTrueWhenAllConditionsAreMet()
        public
        makeTimePast
        enterLotteryWithOnePlayer
    {
        (bool upKeepNeeded, ) = lottery.checkUpKeep("");
        assert(upKeepNeeded);
    }

    function testPerformUpKeepIfCheckUpKeepReturnsTrueUpdatesState()
        public
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
        makeTimePast
        enterLotteryWithOnePlayer
        performUpKeepAndRecordLogs
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // this is emitted by vrfcoordinator emit RandomWordsRequested
        bytes32 requestId = logs[0].topics[2];

        assert(uint256(requestId) > 0);
    }

    function testRevertPerformUpKeepIfCheckUpKeepReturnsFalse() public {
        // Encode the error signature and parameters

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__LotteryUpkeepNotNeeded.selector,
                0,
                0,
                Lottery.LotteryState.OPEN
            )
        );

        lottery.performUpKeep("");
    }

    function testFulFillRandamWordsCanOnlyCalledAfterPerformUpKeep(
        uint256 randomRequestId // foundry generate random number and tests this function multiple times
    ) public makeTimePast enterLotteryWithOnePlayer {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function testFulfillRandomWordsAndPickWinnerAndSendMoney()
        public
        makeTimePast
        enterLotteryWithOnePlayer
        enterLotteryMultiplePlayers(5)
        performUpKeepAndRecordLogs
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[0].topics[2];

        assert(lottery.getPlayersCount() > 0);
        assert(
            lottery.getLotteryState() == Lottery.LotteryState.CALCULATING_WINNER
        );

        uint256 lotteryPrize = address(lottery).balance;
        uint256 winnerBalanceBeforeWon = STARTING_USER_BALANCE - entranceFee;

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
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
}
