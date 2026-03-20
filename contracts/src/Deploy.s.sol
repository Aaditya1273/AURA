// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {AuraCommander} from "./AuraCommander.sol";
import {TestStrategy} from "./TestStrategy.sol";
import {Token} from "./Token.sol";
import {AuraVerifier} from "./AuraVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AURA Deployment Script - ZK Enabled
 * @dev Run with: forge script src/Deploy.s.sol:DeployAura --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
 */
contract DeployAura is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Test AURA Token
        Token token = new Token(18);
        
        // 2. Deploy AuraVerifier (Phase 3 ZK Logic)
        AuraVerifier verifier = new AuraVerifier();
        
        // 3. Deploy AuraCommander
        AuraCommander commander = new AuraCommander(
            IERC20(address(token)),
            "AURA Vault",
            "vAURA"
        );
        
        // 4. Link Verifier to Commander
        commander.setVerifier(address(verifier));

        // 5. Deploy TestStrategy
        TestStrategy strategy = new TestStrategy(address(commander));

        // 6. Register Strategy with 10% debt ratio
        commander.addStrategy(
            address(strategy),
            1000,   // debtRatio
            0,      // minDebt
            type(uint256).max, // maxDebt
            1000    // performanceFee (10%)
        );

        vm.stopBroadcast();
    }
}
