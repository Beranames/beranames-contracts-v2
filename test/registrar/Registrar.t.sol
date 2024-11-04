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
import {EmojiList} from "../utils/EmojiList.t.sol";

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

        bytes memory payload =
            abi.encode(request.owner, request.referrer, request.duration, request.name, round_id, round_total_mint);
        bytes32 payloadHash = keccak256(payload);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, payloadHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, prefixedHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        RegistrarController.WhitelistRegisterRequest memory whitelistRequest = RegistrarController
            .WhitelistRegisterRequest({registerRequest: request, round_id: round_id, round_total_mint: round_total_mint});
        registrar.whitelistRegister{value: 500 ether}(whitelistRequest, signature);
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

        bytes memory payload =
            abi.encode(request.owner, request.referrer, request.duration, request.name, round_id, round_total_mint);
        bytes32 payloadHash = keccak256(payload);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, payloadHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, prefixedHash);

        bytes memory signature = abi.encodePacked(r, s, v);

        RegistrarController.WhitelistRegisterRequest memory whitelistRequest = RegistrarController
            .WhitelistRegisterRequest({registerRequest: request, round_id: round_id, round_total_mint: round_total_mint});

        vm.expectRevert(abi.encodeWithSelector(RegistrarController.MintLimitForRoundReached.selector));
        registrar.whitelistRegister{value: 500 ether}(whitelistRequest, signature);
    }

    //// TESTING VALID() ////
    function test__valid__success_random_string() public view {
        string memory name = "foo";
        bool isValid = registrar.valid(name);
        // utfLen 3
        // strlen 3
        assertTrue(isValid, "foo should be valid");
    }

    function test__valid__success_one_char_no_emoji() public view {
        string memory name = "a";
        bool isValid = registrar.valid(name);
        // utfLen 1
        // strlen 1
        assertTrue(isValid, "a should be valid");
    }

    function test__valid__success_one_char_one_emoji() public view {
        string memory name = unicode"a💩";
        bool isValid = registrar.valid(name);
        // utfLen 2
        // strlen 2
        assertTrue(isValid, unicode"a💩 should be valid");
    }

    function test__valid__failure_one_unicode_emoji() public view {
        string memory name = unicode"⌛";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"⌛ should be invalid");
    }

    function test__valid__failure_two_unicode_emojis() public view {
        string memory name = unicode"ℹ️";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"ℹ️ should be invalid");
    }

    function test__valid__failure_three_unicode_emojis() public view {
        string memory name = unicode"1️⃣";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"1️⃣ should be invalid");
    }

    function test__valid__failure_four_unicode_emojis() public view {
        string memory name = unicode"👨‍⚕️";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"👨‍⚕️ should be invalid");
    }

    function test__valid__failure_five_unicode_emojis() public view {
        string memory name = unicode"👨🏻‍⚕️";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"👨🏻‍⚕️ should be invalid");
    }

    function test__valid__failure_six_unicode_emojis() public view {
        string memory name = unicode"👩‍🦯‍➡️";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"👩‍🦯‍➡️ should be invalid");
    }

    function test__valid__failure_seven_unicode_emojis() public view {
        string memory name = unicode"🏃🏻‍♀️‍➡️";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"🏃🏻‍♀️‍➡️ should be invalid");
    }

    function test__valid__failure_ten_unicode_emojis() public view {
        string memory name = unicode"👨🏻‍❤️‍💋‍👨🏻";
        bool isValid = registrar.valid(name);
        assertFalse(isValid, unicode"👨🏻‍❤️‍💋‍👨🏻 should be invalid");
    }

    function test__valid__failure_all_emojis() public {
        EmojiList emojiList = new EmojiList();
        for (uint256 i = 0; i < emojiList.emojisLength(); i++) {
            string memory emoji = emojiList.emojis(i);
            bool isValid = registrar.valid(emoji);
            assertFalse(isValid, string(abi.encodePacked("Emoji: ", emoji, " should be invalid")));
        }
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
