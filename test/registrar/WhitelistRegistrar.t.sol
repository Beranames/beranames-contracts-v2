// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SystemTest} from "../System.t.sol";
import {RegistrarController} from "src/registrar/Registrar.sol";

/// @notice this contract tests the RegistrarController, but only whitelisting tests
/// separated for clarity and organisation
contract WhitelistRegistrarTest is SystemTest {
    function setUp() public virtual override {
        super.setUp();
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
        uint8 round_id = 1;
        uint8 round_total_mint = 1;

        bytes memory payload = abi.encode(
            request.name,
            request.owner,
            request.duration,
            request.resolver,
            request.data,
            request.reverseRecord,
            request.referrer,
            round_id,
            round_total_mint
        );
        bytes32 payloadHash = generatePersonalPayloadHash(payload);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistSignerPk, payloadHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        RegistrarController.WhitelistRegisterRequest memory whitelistRequest = RegistrarController
            .WhitelistRegisterRequest({registerRequest: request, round_id: round_id, round_total_mint: round_total_mint});
        registrar.whitelistRegister{value: 500 ether}(whitelistRequest, signature);
    }

    function test_whitelist_mint__limit_reached() public {
        // alice mints one name in the first round and it passes, but not the second, because the round total mint is 1

        test_whitelist_mint__success();

        // mint with success
        vm.startPrank(alice);
        deal(address(alice), 1000 ether);

        string memory nameToMint = unicode"alice🐻‍❄️-whitelisted-2";
        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: nameToMint,
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
        uint8 round_id = 1;
        uint8 round_total_mint = 1;

        bytes memory payload = abi.encode(
            request.name,
            request.owner,
            request.duration,
            request.resolver,
            request.data,
            request.reverseRecord,
            request.referrer,
            round_id,
            round_total_mint
        );
        bytes32 payloadHash = generatePersonalPayloadHash(payload);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistSignerPk, payloadHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        RegistrarController.WhitelistRegisterRequest memory whitelistRequest = RegistrarController
            .WhitelistRegisterRequest({registerRequest: request, round_id: round_id, round_total_mint: round_total_mint});

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.MintLimitForRoundReached.selector));
        registrar.whitelistRegister{value: 500 ether}(whitelistRequest, signature);
    }
}
