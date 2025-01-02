// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {StringUtils} from "src/utils/StringUtils.sol";
import {EmojiList} from "./EmojiList.t.sol";

contract StringUtilsTest is Test {
    using StringUtils for string;

    function setUp() public {}

    function test_asciiString() public pure {
        string memory s = "foobar";
        uint256 expectedCount = 6;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "ASCII string character count mismatch");
    }

    function test_basicEmojis() public pure {
        string memory s = unicode"😀😃😄😁";
        uint256 expectedCount = 4;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Basic emoji character count mismatch");
    }

    function test_complexEmoji_single() public pure {
        // Family emoji: 👨‍👩‍👧‍👦
        string memory s = unicode"👨‍👩‍👧‍👦";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Complex emoji (family) character count mismatch");
    }

    function test_complexEmoji_two() public pure {
        string memory s = unicode"👁️‍🗨️";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Complex emoji (Eye in Speech Bubble) character count mismatch");
    }

    function test_mixedString() public pure {
        // Mixed string with ASCII, basic emojis, and complex emojis
        string memory s = unicode"foob👋👨‍👩‍👧‍👦";
        uint256 expectedCount = 6;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Mixed string character count mismatch");
    }

    function test_emptyString() public pure {
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
        vm.expectRevert(StringUtils.InvalidUTF8Byte.selector);
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Invalid UTF-8 character count mismatch");
    }

    function test_invalidContinuationByte() public {
        bytes memory invalidBytes = "\xE2\x28\xA1";
        string memory s = string(invalidBytes);
        uint256 expectedCount = 1; // Counts invalid byte as a character
        vm.expectRevert(StringUtils.InvalidUTF8Byte.selector);
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Invalid UTF-8 character count mismatch");
    }

    function test_flagEmoji() public pure {
        // Flag emoji: 🇺🇳 (United Nations)
        string memory s = unicode"🇺🇳";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Flag emoji character count mismatch");
    }

    function test_skinToneModifier() public pure {
        // Emoji with skin tone modifier: 👍🏽
        string memory s = unicode"👍🏽";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Emoji with skin tone modifier character count mismatch");
    }

    function test_genderModifier() public pure {
        // Emoji with gender modifier: 🧑‍🚀
        string memory s = unicode"🧑‍🚀";
        uint256 expectedCount = 1;
        uint256 actualCount = s.strlen();
        assertEq(actualCount, expectedCount, "Emoji with gender modifier character count mismatch");
    }

    ///// Testing one emoji for each unicode length from https://unicode.org/Public/emoji/latest /////
    // ⌛,U+231B,1
    function test_emoji_one_unicode_strlen() public pure {
        string memory emoji = unicode"⌛";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // ℹ️,U+2139 U+FE0F,2
    function test_emoji_two_unicode_strlen() public pure {
        string memory emoji = unicode"ℹ️";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // 1️⃣,U+0031 U+FE0F U+20E3,3
    function test_emoji_three_unicode_strlen() public pure {
        string memory emoji = unicode"1️⃣";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // 👨‍⚕️,U+1F468 U+200D U+2695 U+FE0F,4
    function test_emoji_four_unicode_strlen() public pure {
        string memory emoji = unicode"👨‍⚕️";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    //👨🏻‍⚕️,U+1F468 U+1F3FB U+200D U+2695 U+FE0F,5
    function test_emoji_five_unicode_strlen() public pure {
        string memory emoji = unicode"👨🏻‍⚕️";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // 👩‍🦯‍➡️,U+1F469 U+200D U+1F9AF U+200D U+27A1 U+FE0F,6
    function test_emoji_six_unicode_strlen() public pure {
        string memory emoji = unicode"👩‍🦯‍➡️";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // 👩🏻‍🦯‍➡️,U+1F469 U+1F3FB U+200D U+1F9AF U+200D U+27A1 U+FE0F,7
    function test_emoji_seven_unicode_strlen() public pure {
        string memory emoji = unicode"👩🏻‍🦯‍➡️";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // 🏃🏻‍♀️‍➡️,U+1F3C3 U+1F3FB U+200D U+2640 U+FE0F U+200D U+27A1 U+FE0F,8
    function test_emoji_eight_unicode_strlen() public pure {
        string memory emoji = unicode"🏃🏻‍♀️‍➡️";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // 👨🏻‍❤️‍💋‍👨🏻,U+1F468 U+1F3FB U+200D U+2764 U+FE0F U+200D U+1F48B U+200D U+1F468 U+1F3FB,10
    function test_emoji_ten_unicode_strlen() public pure {
        string memory emoji = unicode"👨🏻‍❤️‍💋‍👨🏻";
        assertEq(emoji.strlen(), 1, "Strlen shoud be 1");
    }

    // 🏴󠁧󠁢󠁥󠁮󠁧󠁿,U+1F3F4 U+E0067 U+E0062 U+E0065 U+E006E U+E0067 U+E007F,7
    function test_emoji_england() public pure {
        string memory emoji = unicode"🏴󠁧󠁢󠁥󠁮󠁧󠁿";
        assertEq(emoji.strlen(), 1, "England Strlen shoud be 1");
    }

    // 🏴󠁧󠁢󠁳󠁣󠁴󠁿,U+1F3F4 U+E0067 U+E0062 U+E0073 U+E0063 U+E0074 U+E007F,7
    function test_emoji_scotland() public pure {
        string memory emoji = unicode"🏴󠁧󠁢󠁳󠁣󠁴󠁿";
        assertEq(emoji.strlen(), 1, "Scotland Strlen shoud be 1");
    }

    // 🏴󠁧󠁢󠁷󠁬󠁳󠁿,U+1F3F4 U+E0067 U+E0062 U+E0077 U+E006C U+E0073 U+E007F,7
    function test_emoji_wales() public pure {
        string memory emoji = unicode"🏴󠁧󠁢󠁷󠁬󠁳󠁿";
        assertEq(emoji.strlen(), 1, "Wales Strlen shoud be 1");
    }

    function test_all_emojis() public {
        EmojiList emojiList = new EmojiList();

        for (uint256 i = 0; i < emojiList.emojisLength(); i++) {
            assertEq(
                emojiList.emojis(i).strlen(),
                1,
                string(abi.encodePacked("Strlen shoud be 1 for emoji: ", emojiList.emojis(i)))
            );
        }
    }
}
