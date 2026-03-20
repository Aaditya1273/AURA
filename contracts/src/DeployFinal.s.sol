// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "./AuraCommander.sol";
import "./TestStrategy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DeployFinal is Script {
    address constant TOKEN = 0x6b542A9361A7dd16c0b6396202A192326154a1e2;
    address constant VERIFIER = 0xf2Fe48C0E2669D6e8664C1747CE87fBb232Cd557;

    function run() external {
        vm.startBroadcast();

        AuraCommander commander = new AuraCommander(
            IERC20Metadata(TOKEN),
            "AURA Vault",
            "vAURA"
        );

        commander.setVerifier(VERIFIER);

        TestStrategy strategy = new TestStrategy(address(commander));

        commander.addStrategy(address(strategy), 1000, 0, type(uint256).max, 1000);

        console.log("Commander deployed at:", address(commander));
        console.log("Strategy deployed at:", address(strategy));

        vm.stopBroadcast();
    }
}
