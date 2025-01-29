// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

import {ReservedRegistry} from "src/registrar/types/ReservedRegistry.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";

// call this contract with registradAdmin pkey
contract ContractScript2 is Script {
    address public reservedRegistryAddress = 0x2873D5DEb061f2f261543ef7b9e61f47C58306ef; // TODO: SET
    ReservedRegistry public reservedRegistry = new ReservedRegistry(reservedRegistryAddress);

    function run() public {
        vm.startBroadcast();

        reservedRegistry.setReservedName("beranames");
        reservedRegistry.setReservedName("berakin");
        reservedRegistry.setReservedName("kin");

        vm.stopBroadcast();
    }
}
