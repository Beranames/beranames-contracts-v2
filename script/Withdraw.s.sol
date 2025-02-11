// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";

contract WithdrawScript is Script {
    function run() public {
        vm.startBroadcast();

        address registrarAddress = 0x0000000000000000000000000000000000000000;
        RegistrarController registrar = RegistrarController(registrarAddress);
        registrar.withdrawETH();

        vm.stopBroadcast();
    }
}
