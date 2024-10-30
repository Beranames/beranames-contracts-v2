// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RegistrarController} from "src/registrar/Registrar.sol";

import {SystemTest} from "./System.t.sol";
import {Test} from "forge-std/Test.sol";

contract RegistrarTest is SystemTest {
    function test_public_sale_mint__success() public {
        vm.startPrank(alice);
        deal(address(alice), 1000 ether);

        string memory nameToMint = unicode"alice🐻‍❄️";
        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: nameToMint,
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
        registrar.register{value: 500 ether}(request);

        vm.stopPrank();
    }

    function test_whitelist_mint__success() public {
        // set launch time in 10 days
        vm.prank(registrarAdmin);
        registrar.setLaunchTime(block.timestamp + 10 days);
        vm.stopPrank();

        // mint with success
        vm.startPrank(alice);
        deal(address(alice), 1000 ether);

        string memory nameToMint = unicode"alice🐻‍❄️-whitelisted";
        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: nameToMint,
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });

        bytes memory payload = abi.encode(request.owner, request.referrer, request.duration, request.name);
        bytes32 payloadHash = keccak256(payload);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, payloadHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, prefixedHash);

        bytes memory signature = abi.encodePacked(r, s, v);
        registrar.whitelistRegister{value: 500 ether}(request, signature);
    }
}
