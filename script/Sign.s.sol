// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {WhitelistValidator} from "src/registrar/types/WhitelistValidator.sol";

contract Sign is Script {
    function run() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        console.log("alice", alice);
        console.log("alicePk", alicePk);

        address bob = makeAddr("bob");
        console.log("bob", bob);

        bytes memory payload = abi.encode(bob, bob, 365 days, "whitelist");
        bytes32 hash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", abi.encodePacked(keccak256(payload))));
        console.log("hash");
        console.logBytes32(hash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, hash);
        console.log("v", v);
        console.log("r");
        console.logBytes32(r);
        console.log("s");
        console.logBytes32(s);

        address signer = ecrecover(hash, v, r, s);
        console.log("signer from ecrecover", signer);

        WhitelistValidator whitelistValidator = new WhitelistValidator(alice, alice);
        whitelistValidator.validateSignature(abi.encode(bob, bob, 365 days, "whitelist"), v, r, s);
    }
}
