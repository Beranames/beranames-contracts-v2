// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

import {ReservedRegistry} from "src/registrar/types/ReservedRegistry.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {console} from "forge-std/console.sol";

// call this contract with registradAdmin pkey
contract ReserveNames is Script {
    address public reservedRegistryAddress = 0x0000000000000000000000000000000000000000;
    ReservedRegistry public reservedRegistry = ReservedRegistry(reservedRegistryAddress);

    function run() public {
        vm.startBroadcast();

        string[2] memory names = ["a", "b"];

        for (uint256 i = 0; i < names.length; i++) {
            if (reservedRegistry.isReservedName(names[i])) {
                console.log("Name already reserved");
            } else {
                reservedRegistry.setReservedName(names[i]);
            }
        }

        vm.stopBroadcast();
    }
}
