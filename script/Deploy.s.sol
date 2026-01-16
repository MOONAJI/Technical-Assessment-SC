// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TarikTambang.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        TarikTambang game = new TarikTambang();

        console.log("TarikTambang deployed to:", address(game));
        console.log("Admin address:", game.admin());

        vm.stopBroadcast();
    }
}
