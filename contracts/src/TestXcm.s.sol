// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./IXcm.sol";

contract TestXcm is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // Dummy XCM message (V5 prefix = 05, followed by empty instruction list 00)
        bytes memory message = hex"0500"; 
        
        console.log("Testing address:", XCM_PRECOMPILE_ADDRESS);
        try IXcm(XCM_PRECOMPILE_ADDRESS).weighMessage(message) returns (IXcm.Weight memory weight) {

            console.log("XCM Precompile found!");
            console.log("Estimated RefTime:", weight.refTime);
            console.log("Estimated ProofSize:", weight.proofSize);
        } catch {
            console.log("XCM Precompile NOT found or Reverted");
        }

        vm.stopBroadcast();
    }
}
