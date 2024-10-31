// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console} from "forge-std/Test.sol";
import {SystemTest} from "../System.t.sol";

import {RegistrarController} from "src/registrar/Registrar.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {BeraNamesRegistry} from "src/registry/Registry.sol";
import {BERA_NODE} from "src/utils/Constants.sol";
import {ReverseRegistrar} from "src/registrar/ReverseRegistrar.sol";
import {PriceOracle} from "src/registrar/types/PriceOracle.sol";
import {WhitelistValidator} from "src/registrar/types/WhitelistValidator.sol";
import {ReservedRegistry} from "src/registrar/types/ReservedRegistry.sol";

contract RegistrarTest is SystemTest {
    function setUp() public virtual override {
        super.setUp();

        mintToAuctionHouse();
    }

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

        vm.prank(address(whitelistValidator));
        registrar.addValidSignature(keccak256(signature));

        // mint with success
        vm.startPrank(alice);
        deal(address(alice), 1000 ether);

        registrar.whitelistRegister{value: 500 ether}(request, signature);
    }

    function test_register_twoChars_success() public prankWithBalance(alice, 1000 ether) {
        string memory name = "ab";
        RegistrarController.RegisterRequest memory req = defaultRequest(name, alice);
        registrar.register{value: 500 ether}(req);

        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes(name)))), alice);
    }

    function test_register_oneChar_success() public prankWithBalance(alice, 1000 ether) {
        string memory name = "a";
        RegistrarController.RegisterRequest memory req = defaultRequest(name, alice);
        registrar.register{value: 500 ether}(req);

        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes(name)))), alice);
    }

    function test_register_oneCharPlusEmoji_success() public prankWithBalance(alice, 1000 ether) {
        string memory name = unicode"a💩";
        RegistrarController.RegisterRequest memory req = defaultRequest(name, alice);
        registrar.register{value: 500 ether}(req);

        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes(name)))), alice);
    }

    function test_register_oneEmoji_failure() public prankWithBalance(alice, 1000 ether) {
        string memory name = unicode"💩";
        RegistrarController.RegisterRequest memory req = defaultRequest(name, alice);

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.NameNotAvailable.selector, name));
        registrar.register{value: 500 ether}(req);
    }

    function test_whitelist_mint__failure_invalid_signature() public {
        // set launch time in 10 days
        vm.prank(registrarAdmin);
        registrar.setLaunchTime(block.timestamp + 10 days);
        vm.stopPrank();

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

        // signature is valid, but not in the validSignatures pool

        // mint reverts with InvalidSignature error
        vm.startPrank(alice);
        deal(address(alice), 1000 ether);

        vm.expectRevert(RegistrarController.InvalidSignature.selector);
        registrar.whitelistRegister{value: 500 ether}(request, signature);
    }

    function defaultRequest(string memory name_, address owner_)
        internal
        view
        returns (RegistrarController.RegisterRequest memory)
    {
        return RegistrarController.RegisterRequest({
            name: name_,
            owner: owner_,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
    }

    function mintToAuctionHouse() internal {
        uint256 id = uint256(keccak256(bytes(unicode"💩")));
        uint256 duration = 365 days;

        vm.prank(address(auctionHouse));
        baseRegistrar.registerWithRecord(id, address(auctionHouse), duration, address(resolver), 0);

        assertEq(baseRegistrar.ownerOf(id), address(auctionHouse), "Auction house should own the name");
    }
}
