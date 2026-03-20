// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {AuraCommander} from "./AuraCommander.sol";
import {AuraVerifier} from "./AuraVerifier.sol";
import {console} from "forge-std/console.sol";

contract DeployVerifier is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address commanderAddr = vm.envAddress("COMMANDER_ADDR");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AuraVerifier
        AuraVerifier verifier = new AuraVerifier();
        
        // 2. Link to Commander
        AuraCommander commander = AuraCommander(commanderAddr);
        commander.setVerifier(address(verifier));

        vm.stopBroadcast();
        
        console.log("AuraVerifier deployed at:", address(verifier));
        console.log("Linked to Commander at:", commanderAddr);
    }
}
