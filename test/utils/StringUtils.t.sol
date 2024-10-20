// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StringUtils} from "src/utils/StringUtils.sol";

contract StringUtilsTest is Test {
    using StringUtils for string;

    function setUp() public {}

    function test_asciiString() public {
        string memory s = "foobar";
        uint256 expectedCount = 6;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "ASCII string character count mismatch");
    }

    function test_basicEmojis() public {
        string memory s = unicode"😀😃😄😁";
        uint256 expectedCount = 4;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Basic emoji character count mismatch");
    }

    function test_complexEmoji_single() public {
        // Family emoji: 👨‍👩‍👧‍👦
        string memory s = unicode"👨‍👩‍👧‍👦";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Complex emoji (family) character count mismatch");
    }

    function test_mixedString() public {
        // Mixed string with ASCII, basic emojis, and complex emojis
        string memory s = unicode"foob👋👨‍👩‍👧‍👦";
        uint256 expectedCount = 6;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Mixed string character count mismatch");
    }

    function test_emptyString() public {
        string memory s = "";
        uint256 expectedCount = 0;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Empty string character count should be zero");
    }

    function test_invalidUTF8() public {
        // Malformed UTF-8 sequence (invalid start byte)
        bytes memory invalidBytes = hex"FF";
        string memory s = string(invalidBytes);
        uint256 expectedCount = 1; // Counts invalid byte as a character
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Invalid UTF-8 character count mismatch");
    }

    function test_flagEmoji() public {
        // Flag emoji: 🇺🇳 (United Nations)
        string memory s = unicode"🇺🇳";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Flag emoji character count mismatch");
    }

    function test_skinToneModifier() public {
        // Emoji with skin tone modifier: 👍🏽
        string memory s = unicode"👍🏽";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Emoji with skin tone modifier character count mismatch");
    }

    function test_genderModifier() public {
        // Emoji with gender modifier: 🧑‍🚀
        string memory s = unicode"🧑‍🚀";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Emoji with gender modifier character count mismatch");
    }
}
