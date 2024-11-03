// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library StringUtils {
    function utf8Length(string memory s) internal pure returns (uint256) {
        return bytes(s).length;
    }

    /**
     * @dev Returns the length of a given string, accurately counting characters including complex emojis.
     * @param s The string to measure the length of.
     * @return The length of the input string.
     */
    function strlen(string memory s) internal pure returns (uint256) {
        bytes memory strBytes = bytes(s);
        uint256 len = 0;
        uint256 i = 0;
        uint256 strLen = strBytes.length;

        while (i < strLen) {
            uint256 charLen = _charLength(strBytes, i);
            uint256 nextI = i + charLen;

            // Include any combining marks or modifiers immediately following the base character
            while (nextI < strLen && _isCombiningMarkOrModifier(strBytes, nextI)) {
                nextI += _charLength(strBytes, nextI);
            }

            // Handle sequences involving ZWJs by looping until no more ZWJs are found
            while (nextI < strLen && _isZeroWidthJoiner(strBytes, nextI)) {
                // Move past the ZWJ
                nextI += _charLength(strBytes, nextI);

                // Include the next character after ZWJ
                if (nextI < strLen) {
                    uint256 nextCharLen = _charLength(strBytes, nextI);
                    nextI += nextCharLen;

                    // Include any combining marks or modifiers following the character
                    while (nextI < strLen && _isCombiningMarkOrModifier(strBytes, nextI)) {
                        nextI += _charLength(strBytes, nextI);
                    }
                } else {
                    break; // No character after ZWJ
                }
            }

            // Handle regional indicators (used in flags) - always count as pairs
            if (_isRegionalIndicator(strBytes, i) && nextI < strLen && _isRegionalIndicator(strBytes, nextI)) {
                nextI += _charLength(strBytes, nextI);
            }

            // Increment length for each complete character sequence
            len++;
            i = nextI;
        }

        return len;
    }

    // Determines the length of a UTF-8 encoded character in bytes
    function _charLength(bytes memory strBytes, uint256 index) private pure returns (uint256) {
        uint8 b = uint8(strBytes[index]);

        if (b < 0x80) {
            return 1; // 1-byte character (ASCII)
        } else if (b < 0xE0) {
            return 2; // 2-byte character
        } else if (b < 0xF0) {
            return 3; // 3-byte character
        } else if (b < 0xF8) {
            return 4; // 4-byte character (including emojis)
        } else {
            return 1; // Fallback for invalid UTF-8 byte
        }
    }

    // Checks if the sequence starting at index is a Zero-Width Joiner (ZWJ)
    function _isZeroWidthJoiner(bytes memory strBytes, uint256 index) private pure returns (bool) {
        return (
            strBytes[index] == 0xE2 && index + 2 < strBytes.length && strBytes[index + 1] == 0x80
                && strBytes[index + 2] == 0x8D
        );
    }

    // Checks if the character at index is a combining mark or modifier
    function _isCombiningMarkOrModifier(bytes memory strBytes, uint256 index) private pure returns (bool) {
        uint8 b = uint8(strBytes[index]);

        // Combining marks are in the range starting with 0xCC or 0xCD
        if (b == 0xCC || b == 0xCD) {
            return true;
        }

        // Emoji modifiers and variation selectors
        if (b == 0xE2 && index + 2 < strBytes.length) {
            uint8 b1 = uint8(strBytes[index + 1]);
            uint8 b2 = uint8(strBytes[index + 2]);
            // Check for variation selectors (e.g., U+FE0F)
            if (b1 == 0x80 && (b2 == 0x8F || b2 == 0x8E)) {
                return true;
            }
        }

        // Handle emojis with skin tone, gender modifiers, etc.
        if (b == 0xF0 && index + 3 < strBytes.length) {
            uint8 b1 = uint8(strBytes[index + 1]);
            uint8 b2 = uint8(strBytes[index + 2]);
            uint8 b3 = uint8(strBytes[index + 3]);
            // Check for specific sequences that are known modifiers
            if (
                (b1 == 0x9F && b2 == 0x8F && (b3 >= 0xBB && b3 <= 0xBF)) // Skin tone modifiers
                    || (b1 == 0x9F && b2 == 0xA4 && b3 == 0xB0)
            ) {
                // Gender modifiers
                return true;
            }
        }

        // Check for Variation Selector-16 (U+FE0F)
        if (b == 0xEF && index + 2 < strBytes.length) {
            uint8 b1 = uint8(strBytes[index + 1]);
            uint8 b2 = uint8(strBytes[index + 2]);
            if (b1 == 0xB8 && b2 == 0x8F) {
                return true;
            }
        }

        // Check for Combining Enclosing Keycap (U+20E3)
        if (b == 0xE2 && index + 2 < strBytes.length) {
            uint8 b1 = uint8(strBytes[index + 1]);
            uint8 b2 = uint8(strBytes[index + 2]);
            if (b1 == 0x83 && b2 == 0xA3) {
                return true;
            }
        }

        return false;
    }

    // Checks if the character at index is a Regional Indicator Symbol (used for flag emojis)
    function _isRegionalIndicator(bytes memory strBytes, uint256 index) private pure returns (bool) {
        return (
            strBytes[index] == 0xF0 && index + 3 < strBytes.length && strBytes[index + 1] == 0x9F
                && strBytes[index + 2] == 0x87
        );
    }
}
