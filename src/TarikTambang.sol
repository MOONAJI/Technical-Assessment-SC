// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TarikTambang {
    // ============ State Variables ============
    
    address public admin;
    uint256 public gameDeadline;
    bool public gameActive;
    bool public gameFinalized;
    
    enum Team { NONE, A, B }
    enum GameResult { PENDING, TEAM_A_WINS, TEAM_B_WINS, DRAW }
    
    GameResult public result;
    
    uint256 public totalTeamA;
    uint256 public totalTeamB;
    
    // Mapping untuk menyimpan kontribusi setiap user
    mapping(address => uint256) public teamAContributions;
    mapping(address => uint256) public teamBContributions;
    
    // Mapping untuk tracking apakah user sudah claim
    mapping(address => bool) public hasClaimed;
    
    // Array untuk tracking semua participants (untuk keperluan tracking)
    address[] public teamAParticipants;
    address[] public teamBParticipants;
    mapping(address => bool) public isTeamAParticipant;
    mapping(address => bool) public isTeamBParticipant;
    
    // ============ Events ============
    
    event GameStarted(uint256 deadline);
    event BetPlaced(address indexed user, Team team, uint256 amount);
    event GameFinalized(GameResult result, uint256 totalPot);
    event RewardClaimed(address indexed user, uint256 amount);
    event RefundClaimed(address indexed user, uint256 amount);
    
    // ============ Modifiers ============
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }
    
    modifier gameIsActive() {
        require(gameActive, "Game is not active");
        require(block.timestamp < gameDeadline, "Game deadline has passed");
        _;
    }
    
    modifier gameHasEnded() {
        require(block.timestamp >= gameDeadline, "Game has not ended yet");
        _;
    }
    
    modifier gameIsFinalized() {
        require(gameFinalized, "Game is not finalized yet");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() {
        admin = msg.sender;
    }
    
    // ============ Admin Functions ============
    
    function startGame(uint256 duration) external onlyAdmin {
        require(!gameActive, "Game is already active");
        require(duration > 0, "Duration must be greater than 0");
        
        gameDeadline = block.timestamp + duration;
        gameActive = true;
        gameFinalized = false;
        result = GameResult.PENDING;
        
        emit GameStarted(gameDeadline);
    }
    
    function finalizeGame() external onlyAdmin gameHasEnded {
        require(!gameFinalized, "Game already finalized");
        
        gameActive = false;
        gameFinalized = true;
        
        // Tentukan pemenang
        if (totalTeamA > totalTeamB) {
            result = GameResult.TEAM_A_WINS;
        } else if (totalTeamB > totalTeamA) {
            result = GameResult.TEAM_B_WINS;
        } else {
            result = GameResult.DRAW;
        }
        
        uint256 totalPot = totalTeamA + totalTeamB;
        emit GameFinalized(result, totalPot);
    }
    
    // ============ User Functions ============
    
    function betTeamA() external payable gameIsActive {
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(teamBContributions[msg.sender] == 0, "Already bet on Team B");
        
        if (teamAContributions[msg.sender] == 0 && !isTeamAParticipant[msg.sender]) {
            teamAParticipants.push(msg.sender);
            isTeamAParticipant[msg.sender] = true;
        }
        
        teamAContributions[msg.sender] += msg.value;
        totalTeamA += msg.value;
        
        emit BetPlaced(msg.sender, Team.A, msg.value);
    }
    
    function betTeamB() external payable gameIsActive {
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(teamAContributions[msg.sender] == 0, "Already bet on Team A");
        
        if (teamBContributions[msg.sender] == 0 && !isTeamBParticipant[msg.sender]) {
            teamBParticipants.push(msg.sender);
            isTeamBParticipant[msg.sender] = true;
        }
        
        teamBContributions[msg.sender] += msg.value;
        totalTeamB += msg.value;
        
        emit BetPlaced(msg.sender, Team.B, msg.value);
    }
    
    function claimReward() external gameIsFinalized {
        require(!hasClaimed[msg.sender], "Already claimed");
        
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No reward to claim");
        
        hasClaimed[msg.sender] = true;
        
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Transfer failed");
        
        if (result == GameResult.DRAW) {
            emit RefundClaimed(msg.sender, reward);
        } else {
            emit RewardClaimed(msg.sender, reward);
        }
    }
    
    // ============ View Functions ============
    
    function calculateReward(address user) public view returns (uint256) {
        if (hasClaimed[user]) {
            return 0;
        }
        
        uint256 totalPot = totalTeamA + totalTeamB;
        
        // Jika draw, return kontribusi user
        if (result == GameResult.DRAW) {
            return teamAContributions[user] + teamBContributions[user];
        }
        
        // Jika Tim A menang
        if (result == GameResult.TEAM_A_WINS) {
            if (teamAContributions[user] == 0) {
                return 0; // User tidak di tim pemenang
            }
            // Rumus: (Kontribusi User / Total Dana Tim Pemenang) * Total Pot
            return (teamAContributions[user] * totalPot) / totalTeamA;
        }
        
        // Jika Tim B menang
        if (result == GameResult.TEAM_B_WINS) {
            if (teamBContributions[user] == 0) {
                return 0; // User tidak di tim pemenang
            }
            return (teamBContributions[user] * totalPot) / totalTeamB;
        }
        
        return 0;
    }
    
    function getGameInfo() external view returns (
        bool active,
        bool finalized,
        uint256 deadline,
        uint256 teamATotal,
        uint256 teamBTotal,
        GameResult gameResult
    ) {
        return (
            gameActive,
            gameFinalized,
            gameDeadline,
            totalTeamA,
            totalTeamB,
            result
        );
    }

    function getUserContributions(address user) external view returns (
        uint256 teamAContribution,
        uint256 teamBContribution
    ) {
        return (
            teamAContributions[user],
            teamBContributions[user]
        );
    }
    
    function getParticipantCounts() external view returns (
        uint256 teamACount,
        uint256 teamBCount
    ) {
        return (
            teamAParticipants.length,
            teamBParticipants.length
        );
    }
}