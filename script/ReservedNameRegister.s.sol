// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {BERA_NODE} from "src/utils/Constants.sol";

contract ReservedNameRegister is Script {
    address public registrarAddress = 0xf0fb7ba7d6D18AdC32298d2Ff452f448F90255dC;
    address public defaultResolverAddress = 0xC23e819766cD5C5F5ec0E1B1764aFeba1dc2D03C;
    RegistrarController public registrar = RegistrarController(registrarAddress);
    BeraDefaultResolver public resolver = BeraDefaultResolver(defaultResolverAddress);

    // this script should be called with registrar's reservedNamesMinter
    function run() public {
        vm.startBroadcast();

        string memory name = "name";
        address owner = 0x0000000000000000000000000000000000000000;
        uint256 duration = 365 days;

        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: name,
            duration: duration,
            reverseRecord: false,
            owner: owner,
            resolver: defaultResolverAddress,
            data: new bytes[](0),
            referrer: address(0)
        });

        registrar.reservedRegister(request);

        vm.stopBroadcast();
    }
}
