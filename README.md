# Tarik Tambang - Smart Contract Game

Smart Contract berbasis Solidity yang mensimulasikan permainan "Tarik Tambang" dengan taruhan menggunakan native token (ETH/MATIC/BNB).

## 📋 Deskripsi

Tarik Tambang adalah permainan betting berbasis blockchain di mana:
- Dua tim (Tim A dan Tim B) bersaing untuk mengumpulkan dana terbanyak
- Pemain memasang taruhan dengan memilih salah satu tim
- Tim dengan total dana terbesar menang dan berbagi total pot secara proporsional
- Jika seri, semua pemain mendapat refund 100%

## 🎮 Fitur Utama

### Game Logic
- ✅ Admin-controlled game initialization dengan durasi yang dapat dikustomisasi
- ✅ Betting phase dengan dukungan untuk Tim A dan Tim B
- ✅ Perhitungan pemenang otomatis berdasarkan total kontribusi
- ✅ Distribusi hadiah proporsional berdasarkan kontribusi
- ✅ Mekanisme refund otomatis untuk kondisi seri

### Smart Contract Features
- ✅ Gas-efficient withdraw mechanism (user-initiated claims)
- ✅ Prevents double-claiming
- ✅ Prevents betting on both teams
- ✅ Comprehensive event logging
- ✅ Multiple security checks and validations

## 🏗️ Struktur Project

```
tarik-tambang/
├── src/
│   └── TarikTambang.sol          # Main contract
├── test/
│   └── TarikTambang.t.sol        # Comprehensive test suite
├── script/
│   └── Deploy.s.sol              # Deployment script
├── foundry.toml                  # Foundry configuration
└── README.md                     # Documentation
```

## 🚀 Instalasi & Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation Steps

1. **Clone Repository**
```bash
git clone <repository-url>
cd tarik-tambang
```

2. **Install Dependencies**
```bash
forge install
```

3. **Setup Environment Variables**
```bash
cp .env.example .env
# Edit .env dengan private key dan RPC URLs Anda
```

Example `.env`:
```env
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## 🧪 Testing

### Run All Tests
```bash
forge test
```

### Run Tests with Verbose Output
```bash
forge test -vvv
```

### Run Specific Test
```bash
forge test --match-test testTeamAWinsRewardCalculation -vvv
```

### Gas Report
```bash
forge test --gas-report
```

### Test Coverage
```bash
forge coverage
```

## 📊 Test Scenarios Covered

### ✅ Skenario Tim A Menang
- Kalkulasi hadiah proporsional
- Multiple winners dengan distribusi berbeda
- Winner dapat claim dengan sukses
- Loser tidak dapat claim

**Test:** `testTeamAWinsRewardCalculation`, `testTeamAWinsClaim`

### ✅ Skenario Seri (Draw)
- Refund 100% untuk semua participant
- Kedua tim mendapat dana mereka kembali
- Multiple users dapat claim refund

**Test:** `testDrawRefund`, `testDrawClaimRefund`

### ✅ Skenario Withdraw Sebelum Waktu Habis
- User tidak dapat withdraw sebelum game finalize
- Proper error handling

**Test:** `testCannotClaimBeforeFinalize`

### ✅ Skenario Tim Kalah Mencoba Withdraw
- Tim kalah tidak dapat claim reward
- Revert dengan pesan error yang tepat

**Test:** `testLoserCannotClaim`

### ✅ Additional Security Tests
- Cannot bet after deadline
- Cannot bet zero amount
- Cannot bet on both teams
- Cannot claim twice
- Cannot finalize game twice
- Only admin can start/finalize game

## 📝 Deployment

### Deploy to Testnet (Sepolia)
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast --verify
```

### Deploy to Other Networks
```bash
# Polygon Mumbai
forge script script/Deploy.s.sol:DeployScript --rpc-url polygon_mumbai --broadcast --verify

# BSC Testnet
forge script script/Deploy.s.sol:DeployScript --rpc-url bsc_testnet --broadcast --verify
```

## 🔗 Contract Information

### Deployed Contract
- **Network:** [Network Name - e.g., Sepolia Testnet]
- **Contract Address:** `[DEPLOYED_CONTRACT_ADDRESS]`
- **Block Explorer:** `[EXPLORER_LINK]`
- **Admin Address:** `[ADMIN_ADDRESS]`

> **Note:** Update informasi di atas setelah deployment

### Verify Contract
```bash
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --compiler-version v0.8.20 \
  <CONTRACT_ADDRESS> \
  src/TarikTambang.sol:TarikTambang \
  --etherscan-api-key <YOUR_API_KEY>
```

## 🔧 Cara Penggunaan

### 1. Start Game (Admin Only)
```solidity
// Duration dalam seconds (contoh: 1 hour = 3600)
tarikTambang.startGame(3600);
```

### 2. Place Bet
```solidity
// Bet untuk Tim A
tarikTambang.betTeamA{value: 1 ether}();

// Bet untuk Tim B
tarikTambang.betTeamB{value: 1 ether}();
```

### 3. Finalize Game (Admin Only - After Deadline)
```solidity
tarikTambang.finalizeGame();
```

### 4. Claim Reward (Winners/Draw Participants)
```solidity
// Check reward terlebih dahulu
uint256 reward = tarikTambang.calculateReward(userAddress);

// Claim reward
tarikTambang.claimReward();
```

### 5. Get Game Info
```solidity
(
    bool active,
    bool finalized,
    uint256 deadline,
    uint256 teamATotal,
    uint256 teamBTotal,
    GameResult result
) = tarikTambang.getGameInfo();
```

## 💡 Pendekatan Solusi

### Distribusi Hadiah (Gas-Efficient Approach)

Untuk menghindari masalah **Gas Limit** pada distribusi hadiah, contract ini mengimplementasikan **Pull Payment Pattern** (User-Initiated Withdrawal):

#### Mengapa Tidak Menggunakan Auto-Distribution?
```solidity
// ❌ BURUK: Auto-distribution (High Gas Cost)
function finalizeGame() {
    // ... determine winner ...
    for(uint i = 0; i < winners.length; i++) {
        winners[i].transfer(reward); // Bisa gagal jika banyak winners!
    }
}
```

**Masalah:**
- Gas cost meningkat linear dengan jumlah participants
- Bisa melebihi block gas limit jika participants banyak
- Jika satu transfer gagal, seluruh transaksi revert
- Admin menanggung semua gas cost

#### Solusi: Pull Payment Pattern
```solidity
// ✅ BAGUS: User-initiated claims
function claimReward() external {
    uint256 reward = calculateReward(msg.sender);
    require(reward > 0, "No reward to claim");
    require(!hasClaimed[msg.sender], "Already claimed");
    
    hasClaimed[msg.sender] = true;
    payable(msg.sender).transfer(reward);
}
```

**Keuntungan:**
- Gas cost terdistribusi ke setiap user (fairness)
- Tidak ada limit jumlah participants
- Setiap claim independent (satu gagal tidak mempengaruhi yang lain)
- User claim sesuai kebutuhan mereka

### Perhitungan Reward Proporsional

```solidity
// Rumus: (Kontribusi User / Total Dana Tim Pemenang) * Total Pot
reward = (userContribution * totalPot) / winningTeamTotal
```

**Contoh:**
- Tim A Total: 5 ETH (User1: 3 ETH, User2: 2 ETH)
- Tim B Total: 2 ETH
- Total Pot: 7 ETH

**Distribusi:**
- User1: (3/5) × 7 = 4.2 ETH (profit 1.2 ETH)
- User2: (2/5) × 7 = 2.8 ETH (profit 0.8 ETH)

### Security Considerations

1. **Reentrancy Protection**
   - State updates sebelum external calls
   - `hasClaimed` flag untuk prevent double-claiming

2. **Access Control**
   - `onlyAdmin` modifier untuk fungsi sensitif
   - Time-based validations (deadline checks)

3. **Input Validation**
   - Semua inputs divalidasi (non-zero amounts, valid states, dll)
   - Comprehensive require statements

4. **Precision Handling**
   - Solidity integer division dihandle dengan benar
   - Order operasi untuk meminimalkan rounding errors

## 📈 Gas Optimization

- Menggunakan `uint256` untuk menghindari implicit conversions
- Mapping untuk O(1) lookups
- Minimal array iterations
- Event emission untuk off-chain tracking
- Efficient storage layout

## 🔐 Security Audit Checklist

- ✅ No reentrancy vulnerabilities
- ✅ Access control properly implemented
- ✅ Integer overflow protection (Solidity 0.8+)
- ✅ No front-running risks
- ✅ Proper event logging
- ✅ Comprehensive input validation
- ✅ No unchecked external calls
- ✅ Gas limit considerations handled

## 🤝 Contributing

Contributions are welcome! Silakan buat pull request atau open issue untuk suggestions.

## 📄 License

MIT License

## 👥 Author

[Your Name/Team Name]

## 📞 Support

Jika ada pertanyaan atau issues:
- Open GitHub Issue
- Email: [your-email@example.com]
- Discord: [your-discord]

---

**Note:** Contract ini untuk educational purposes. Pastikan melakukan audit security yang komprehensif sebelum deployment ke production.