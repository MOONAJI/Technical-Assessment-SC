// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TarikTambang.sol";

contract TarikTambangTest is Test {
    TarikTambang public game;

    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    uint256 constant GAME_DURATION = 1 hours;

    event GameStarted(uint256 deadline);
    event BetPlaced(address indexed user, TarikTambang.Team team, uint256 amount);
    event GameFinalized(TarikTambang.GameResult result, uint256 totalPot);
    event RewardClaimed(address indexed user, uint256 amount);
    event RefundClaimed(address indexed user, uint256 amount);

    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);

        game = new TarikTambang();
    }

    // ============ Test Game Initialization ============

    function testStartGame() public {
        vm.expectEmit(false, false, false, false);
        emit GameStarted(block.timestamp + GAME_DURATION);

        game.startGame(GAME_DURATION);

        assertTrue(game.gameActive());
        assertEq(game.gameDeadline(), block.timestamp + GAME_DURATION);
    }

    function testStartGameOnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert("Only admin can call this");
        game.startGame(GAME_DURATION);
    }

    function testCannotStartGameTwice() public {
        game.startGame(GAME_DURATION);

        vm.expectRevert("Game is already active");
        game.startGame(GAME_DURATION);
    }

    // ============ Test Betting ============

    function testBetTeamA() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 1 ether}();

        assertEq(game.totalTeamA(), 1 ether);
        assertEq(game.teamAContributions(user1), 1 ether);
    }

    function testBetTeamB() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamB{value: 1 ether}();

        assertEq(game.totalTeamB(), 1 ether);
        assertEq(game.teamBContributions(user1), 1 ether);
    }

    function testMultipleBetsSameTeam() public {
        game.startGame(GAME_DURATION);

        vm.startPrank(user1);
        game.betTeamA{value: 1 ether}();
        game.betTeamA{value: 0.5 ether}();
        vm.stopPrank();

        assertEq(game.totalTeamA(), 1.5 ether);
        assertEq(game.teamAContributions(user1), 1.5 ether);
    }

    function testCannotBetOnBothTeams() public {
        game.startGame(GAME_DURATION);

        vm.startPrank(user1);
        game.betTeamA{value: 1 ether}();

        vm.expectRevert("Already bet on Team A");
        game.betTeamB{value: 1 ether}();
        vm.stopPrank();
    }

    function testCannotBetAfterDeadline() public {
        game.startGame(GAME_DURATION);

        vm.warp(block.timestamp + GAME_DURATION + 1);

        vm.prank(user1);
        vm.expectRevert("Game deadline has passed");
        game.betTeamA{value: 1 ether}();
    }

    function testCannotBetZeroAmount() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        vm.expectRevert("Bet amount must be greater than 0");
        game.betTeamA{value: 0}();
    }

    // ============ Test Game Finalization ============

    function testFinalizeGame() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 2 ether}();

        vm.prank(user2);
        game.betTeamB{value: 1 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);

        game.finalizeGame();

        assertTrue(game.gameFinalized());
        assertFalse(game.gameActive());
        assertEq(uint256(game.result()), uint256(TarikTambang.GameResult.TEAM_A_WINS));
    }

    function testCannotFinalizeBeforeDeadline() public {
        game.startGame(GAME_DURATION);

        vm.expectRevert("Game has not ended yet");
        game.finalizeGame();
    }

    function testCannotFinalizeGameTwice() public {
        game.startGame(GAME_DURATION);

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        vm.expectRevert("Game already finalized");
        game.finalizeGame();
    }

    // ============ Test Team A Wins Scenario ============

    function testTeamAWinsRewardCalculation() public {
        game.startGame(GAME_DURATION);

        // Team A bets: user1 = 3 ETH, user2 = 2 ETH (Total: 5 ETH)
        vm.prank(user1);
        game.betTeamA{value: 3 ether}();

        vm.prank(user2);
        game.betTeamA{value: 2 ether}();

        // Team B bets: user3 = 2 ETH (Total: 2 ETH)
        vm.prank(user3);
        game.betTeamB{value: 2 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        // Total pot = 7 ETH
        // User1 reward = (3/5) * 7 = 4.2 ETH
        // User2 reward = (2/5) * 7 = 2.8 ETH
        // User3 (loser) = 0 ETH

        assertEq(game.calculateReward(user1), 4.2 ether);
        assertEq(game.calculateReward(user2), 2.8 ether);
        assertEq(game.calculateReward(user3), 0);
    }

    function testTeamAWinsClaim() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 3 ether}();

        vm.prank(user2);
        game.betTeamB{value: 1 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        game.claimReward();

        uint256 balanceAfter = user1.balance;

        // User1 should receive entire pot (4 ETH)
        assertEq(balanceAfter - balanceBefore, 4 ether);
        assertTrue(game.hasClaimed(user1));
    }

    function testLoserCannotClaim() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 3 ether}();

        vm.prank(user2);
        game.betTeamB{value: 1 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        vm.prank(user2);
        vm.expectRevert("No reward to claim");
        game.claimReward();
    }

    // ============ Test Draw Scenario ============

    function testDrawRefund() public {
        game.startGame(GAME_DURATION);

        // Both teams bet equal amounts
        vm.prank(user1);
        game.betTeamA{value: 2 ether}();

        vm.prank(user2);
        game.betTeamB{value: 2 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        assertEq(uint256(game.result()), uint256(TarikTambang.GameResult.DRAW));

        // Both should get their money back
        assertEq(game.calculateReward(user1), 2 ether);
        assertEq(game.calculateReward(user2), 2 ether);
    }

    function testDrawClaimRefund() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 2 ether}();

        vm.prank(user2);
        game.betTeamB{value: 2 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        uint256 balance1Before = user1.balance;
        uint256 balance2Before = user2.balance;

        vm.prank(user1);
        game.claimReward();

        vm.prank(user2);
        game.claimReward();

        // Both should receive their original bets back
        assertEq(user1.balance - balance1Before, 2 ether);
        assertEq(user2.balance - balance2Before, 2 ether);
    }

    // ============ Test Withdraw Restrictions ============

    function testCannotClaimBeforeFinalize() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 1 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);

        vm.prank(user1);
        vm.expectRevert("Game is not finalized yet");
        game.claimReward();
    }

    function testCannotClaimTwice() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 2 ether}();

        vm.prank(user2);
        game.betTeamB{value: 1 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        vm.startPrank(user1);
        game.claimReward();

        vm.expectRevert("Already claimed");
        game.claimReward();
        vm.stopPrank();
    }

    // ============ Test Complex Scenarios ============

    function testMultipleUsersTeamAWins() public {
        game.startGame(GAME_DURATION);

        // Team A: user1 = 2 ETH, user2 = 3 ETH (Total: 5 ETH)
        vm.prank(user1);
        game.betTeamA{value: 2 ether}();

        vm.prank(user2);
        game.betTeamA{value: 3 ether}();

        // Team B: user3 = 1 ETH, user4 = 1 ETH (Total: 2 ETH)
        vm.prank(user3);
        game.betTeamB{value: 1 ether}();

        vm.prank(user4);
        game.betTeamB{value: 1 ether}();

        vm.warp(block.timestamp + GAME_DURATION + 1);
        game.finalizeGame();

        // Total pot = 7 ETH
        // user1: (2/5) * 7 = 2.8 ETH
        // user2: (3/5) * 7 = 4.2 ETH

        assertEq(game.calculateReward(user1), 2.8 ether);
        assertEq(game.calculateReward(user2), 4.2 ether);
        assertEq(game.calculateReward(user3), 0);
        assertEq(game.calculateReward(user4), 0);

        // Verify claims work
        vm.prank(user1);
        game.claimReward();

        vm.prank(user2);
        game.claimReward();

        assertTrue(game.hasClaimed(user1));
        assertTrue(game.hasClaimed(user2));
    }

    function testGetGameInfo() public {
        game.startGame(GAME_DURATION);

        (
            bool active,
            bool finalized,
            uint256 deadline,
            uint256 teamATotal,
            uint256 teamBTotal,
            TarikTambang.GameResult gameResult
        ) = game.getGameInfo();

        assertTrue(active);
        assertFalse(finalized);
        assertEq(deadline, block.timestamp + GAME_DURATION);
        assertEq(teamATotal, 0);
        assertEq(teamBTotal, 0);
        assertEq(uint256(gameResult), uint256(TarikTambang.GameResult.PENDING));
    }

    function testGetUserContributions() public {
        game.startGame(GAME_DURATION);

        vm.prank(user1);
        game.betTeamA{value: 1.5 ether}();

        (uint256 teamA, uint256 teamB) = game.getUserContributions(user1);

        assertEq(teamA, 1.5 ether);
        assertEq(teamB, 0);
    }
}
