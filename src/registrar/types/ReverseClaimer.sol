//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BNS} from "src/registry/interfaces/BNS.sol";
import {IReverseRegistrar} from "src/registrar/interfaces/IReverseRegistrar.sol";
import {ADDR_REVERSE_NODE} from "src/utils/Constants.sol";

contract ReverseClaimer {
    constructor(BNS bns, address claimant) {
        IReverseRegistrar reverseRegistrar = IReverseRegistrar(bns.owner(ADDR_REVERSE_NODE));
        reverseRegistrar.claim(claimant);
    }
}
