// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
import {console2} from "forge-std/Test.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A Lottery contract
 * @author Saikrishna Sangishetty
 * @notice This contract is used to create a Lottery
 * @dev Implements the Chainlin VRFv2
 */
contract Lottery is VRFConsumerBaseV2Plus {
    error Lottery__NotEnoughEthToEnterLottery();
    error Lottery__WinnerTransferAmountFailed();
    error Lottery__LotteryNotOpen();
    error Lottery__LotteryNotOwner();
    error Lottery__LotteryOwnerAddBalance();
    error Lottery__LotteryOwnerAddBalanceNill();
    error Lottery__LotteryUpkeepNotNeeded(
        uint256 balance,
        uint256 playersCount,
        LotteryState state
    );
    /**
     * Type Declarations
     */

    enum LotteryState {
        OPEN,
        CALCULATING_WINNER
    }

    /**
     * State Variables
     */
    uint32 private immutable numWords = 1;

    // @dev entrance fee to enter the lottery
    uint256 private immutable i_entranceFee;
    // @dev duration of the lottery in seconds
    uint256 private immutable i_lotteryDuration;
    IVRFCoordinatorV2Plus private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint16 private immutable i_requestConfirmations;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_subscriptionId;
    uint256 private s_startTime;
    address payable[] private s_players;
    address private s_recentWinner;
    mapping(address => bool) private enteredPlayers;
    LotteryState private s_lotteryState;

    /**
     * Events
     */

    event EnteredLottery(address indexed player);
    event WinnerPicked(address indexed winner);

    // address link, bytes32 keyHash, uint256 fee, uint256 subscriptionId
    constructor(
        uint256 entranceFee,
        uint256 lotteryDuration,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_lotteryDuration = lotteryDuration;
        s_startTime = block.timestamp;
        i_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_requestConfirmations = requestConfirmations;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
    }

    function enterLottery() external payable {
        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__LotteryNotOpen();
        }
        // Enter the lottery
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughEthToEnterLottery();
        }
        s_players.push(payable(msg.sender));
        enteredPlayers[msg.sender] = true;

        emit EnteredLottery(msg.sender);
    }

    /**
     * @dev This function that the chainlink automation nodes call
     * to see if it's time to perform the upkeep
     * The following should be true for this to return true:
     * 1. The time interval has passed between lottery runs
     * 2. The lottery is in the OPEN state
     * 3. The contract has ETH (aka, players that entered the lottery)
     * 4. (Implicit) The subscription is funded with enough LINK
     */
    function checkUpKeep(
        bytes memory /* checkData*/
    ) public view returns (bool upKeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = (block.timestamp - s_startTime) >
            i_lotteryDuration;
        bool lotteryIsOpen = s_lotteryState == LotteryState.OPEN;
        bool hasBalance = getBalance() > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded =
            timeHasPassed &&
            lotteryIsOpen &&
            hasBalance &&
            hasPlayers;
        return (upKeepNeeded, "0x0");
    }

    function performUpKeep(bytes calldata /* performData*/) external {
        // checking if the set duration is past to start picking the winner
        (bool shouldCheckUpKeep, ) = checkUpKeep("");
        if (!shouldCheckUpKeep) {
            revert Lottery__LotteryUpkeepNotNeeded(
                getBalance(),
                getPlayersCount(),
                getLotteryState()
            );
        }
        // change the state to CALCULATING_WINNER
        s_lotteryState = LotteryState.CALCULATING_WINNER;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: i_requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // set nativePayment to true to pay for VRF requests with sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        // Pick the winner
        i_vrfCoordinator.requestRandomWords(request);
        // i_gasLane,
        //     i_subscriptionId,
        //     i_requestConfirmations,
        //     i_callbackGasLimit,
        //     numWords
    }

    function fulfillRandomWords(
        uint256 requestId,
        /*requestId*/
        uint256[] calldata randomWords
    ) internal override {
        console2.log("Random requestId: %s", requestId);
        // use the random number to pick a winner
        uint256 index = randomWords[0] % s_players.length;
        address payable winner = s_players[index];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_lotteryState = LotteryState.OPEN;
        s_startTime = block.timestamp;
        (bool success, ) = payable(winner).call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Lottery__WinnerTransferAmountFailed();
        }

        emit WinnerPicked(winner);
        // automatically transfer the money to the winner
    }

    /**
     * Getter functions
     */

    function getLotteryDuration() public view returns (uint256) {
        return i_lotteryDuration;
    }

    function getPlayer(uint256 index) public view returns (address player) {
        return s_players[index];
    }

    function getPlayersCount() public view returns (uint256) {
        return s_players.length;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLotteryState() public view returns (LotteryState) {
        return s_lotteryState;
    }

    function getStartTime() public view returns (uint256) {
        return s_startTime;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getGasLane() public view returns (bytes32) {
        return i_gasLane;
    }

    function getRequestConfirmations() public view returns (uint16) {
        return i_requestConfirmations;
    }

    function getCallbackGasLimit() public view returns (uint32) {
        return i_callbackGasLimit;
    }

    function hasEntered(address player) public view returns (bool) {
        return enteredPlayers[player];
    }
}
