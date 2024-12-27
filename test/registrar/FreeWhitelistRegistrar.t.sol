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

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.NameNotAvailable.selector, nameToMint));
        registrar.whitelistFreeRegister(request, sign(request));

        request.name = unicode"alice🐻‍❄️-free-whitelisted";
        registrar.whitelistFreeRegister(request, sign(request));
        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes(request.name)))), alice);

        // if you change the name, it fails, because you have already minted a name
        request.name = "foooooobar";
        vm.expectRevert(abi.encodeWithSelector(RegistrarController.FreeMintLimitReached.selector));
        registrar.whitelistFreeRegister(request, sign(request));
    }

    function sign(RegistrarController.RegisterRequest memory request) public view returns (bytes memory) {
        bytes memory payload = abi.encode(
            request.name,
            request.owner,
            request.duration,
            request.resolver,
            request.data,
            request.reverseRecord,
            request.referrer
        );
        bytes32 payloadHash = generatePersonalPayloadHash(payload);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(freeWhitelistSignerPk, payloadHash);

        bytes memory signature = abi.encodePacked(r, s, v);
        return signature;
    }
}
