// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SystemTest} from "../System.t.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";

/// @notice this contract tests the RegistrarController, but only whitelisting tests
/// separated for clarity and organisation
contract FreeWhitelistRegistrarTest is SystemTest {
    function test_whitelist_free_register() public {
        // set launch time in 10 days
        vm.prank(registrarAdmin);
        registrar.setLaunchTime(block.timestamp + 10 days);
        vm.stopPrank();

        // mint with success
        vm.startPrank(alice);
        deal(address(alice), 1000 ether);

        string memory nameToMint = "s"; // short name
        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: nameToMint,
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });

        bytes memory payload = abi.encode(request.owner);
        bytes32 payloadHash = keccak256(payload);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, payloadHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, prefixedHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.NameNotAvailable.selector, nameToMint));
        registrar.whitelistFreeRegister(request, signature);

        request.name = unicode"alice🐻‍❄️-free-whitelisted";
        registrar.whitelistFreeRegister(request, signature);
        assertEq(baseRegistrar.ownerOf(uint256(keccak256(abi.encodePacked(request.name)))), alice);

        // second time fails because the signature has already been used
        request.name = unicode"alice🐻‍❄️-free-whitelisted2";
        vm.expectRevert(abi.encodeWithSelector(RegistrarController.FreeMintSignatureAlreadyUsed.selector));
        registrar.whitelistFreeRegister(request, signature);

        // also if you change the name, it fails, because signature is used
        request.name = "foooooobar";
        vm.expectRevert(abi.encodeWithSelector(RegistrarController.FreeMintSignatureAlreadyUsed.selector));
        registrar.whitelistFreeRegister(request, signature);
    }
}
