// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ReducedPriceOracle} from "src/registrar/types/ReducedPriceOracle.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";

contract ReducedPriceOracleScript is Script {
    // this script should be called from registrar owner

    function run() public {
        vm.startBroadcast();

        address pythAddress = 0x2880aB155794e7179c9eE2e38200202908C17B43;
        bytes32 beraUsdPythPriceFeedId = hex"962088abcfdbdb6e30db2e340c8cf887d9efb311b1f2f17b155a63dbb6d40265";
        ReducedPriceOracle priceOracle = new ReducedPriceOracle(pythAddress, beraUsdPythPriceFeedId);

        RegistrarController registrar = RegistrarController(0x3b872E5DEE3cD8186E1F304514D1dc6Ac34d5d54);

        registrar.setPriceOracle(priceOracle);

        vm.stopBroadcast();
    }
}
