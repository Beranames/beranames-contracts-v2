// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";

contract PriceOracle is IPriceOracle {
    /// @notice Calculates the price for a given label with a default payment method of ETH.
    /// @param label The label to query.
    /// @param expires The expiry of the label.
    /// @param duration The duration of the registration.
    /// @return The price of the label.
    function price(
        string calldata label, 
        uint256 expires, 
        uint256 duration
    ) external view override returns (Price memory) {
        return price(label, expires, duration, Payment.STABLE);
    }

    /// @notice Calculates the price for a given label with a specified payment method.
    /// @param label The label to query.
    /// @param expires The expiry of the label.
    /// @param duration The duration of the registration.
    /// @param payment The payment method.
    /// @return The price of the label.
    function price(
        string calldata label, 
        uint256 expires, 
        uint256 duration,
        Payment payment
    ) public view override returns (Price memory) {
        // TODO: Add logic for incorporating the expiry into the price calculation
        //   it could be used for grace periods, etc.

        // Implement your logic to calculate the base and premium price
        (uint256 basePrice, uint256 discount) = calculateBasePrice(label, duration);

        // Adjust the price based on the payment method if necessary
        if (payment == Payment.ETH) {
            basePrice = convertToToken(basePrice);
            discount = convertToToken(discount);
        }

        return Price(basePrice, discount);
    }

    /// @notice Calculates the base price for a given label and duration.
    /// @param label The label to query.
    /// @param duration The duration of the registration.
    /// @return base The base price before discount.
    /// @return discount The discount.
    function calculateBasePrice(string calldata label, uint256 duration) internal pure returns (uint256 base, uint256 discount) {
        uint256 pricePerYear;
        
        // Initialize emoji count
        uint256 emojiCount = 0;
        
        // Iterate over each character in the label
        for (uint256 i = 0; i < bytes(label).length; i++) {
            // Decode the character as a Unicode code point
            uint256 codePoint;
            bytes1 b = bytes(label)[i];
            
            if (b & 0x80 == 0) {
                // 1-byte character
                codePoint = uint256(uint8(b));
            } else if (b & 0xE0 == 0xC0) {
                // 2-byte character
                codePoint = (uint256(uint8(b & 0x1F)) << 6) | uint256(uint8(bytes(label)[i + 1] & 0x3F));
                i += 1;
            } else if (b & 0xF0 == 0xE0) {
                // 3-byte character
                codePoint = (uint256(uint8(b & 0x0F)) << 12) | (uint256(uint8(bytes(label)[i + 1] & 0x3F)) << 6) | uint256(uint8(bytes(label)[i + 2] & 0x3F));
                i += 2;
            } else if (b & 0xF8 == 0xF0) {
                // 4-byte character
                codePoint = (uint256(uint8(b & 0x07)) << 18) | (uint256(uint8(bytes(label)[i + 1] & 0x3F)) << 12) | (uint256(uint8(bytes(label)[i + 2] & 0x3F)) << 6) | uint256(uint8(bytes(label)[i + 3] & 0x3F));
                i += 3;
            }
            
            // Check if the code point is an emoji
            if ((codePoint >= 0x1F600 && codePoint <= 0x1F64F) || // Emoticons
                (codePoint >= 0x1F300 && codePoint <= 0x1F5FF) || // Miscellaneous Symbols and Pictographs
                (codePoint >= 0x1F680 && codePoint <= 0x1F6FF) || // Transport and Map Symbols
                (codePoint >= 0x1F700 && codePoint <= 0x1F77F) || // Alchemical Symbols
                (codePoint >= 0x1F780 && codePoint <= 0x1F7FF) || // Geometric Shapes Extended
                (codePoint >= 0x1F800 && codePoint <= 0x1F8FF) || // Supplemental Arrows-C
                (codePoint >= 0x1F900 && codePoint <= 0x1F9FF) || // Supplemental Symbols and Pictographs
                (codePoint >= 0x1FA00 && codePoint <= 0x1FA6F) || // Chess Symbols
                (codePoint >= 0x1FA70 && codePoint <= 0x1FAFF) || // Symbols and Pictographs Extended-A
                (codePoint >= 0x2600 && codePoint <= 0x26FF) ||   // Miscellaneous Symbols
                (codePoint >= 0x2700 && codePoint <= 0x27BF)) {   // Dingbats
                emojiCount++;
            }
        }
        
        uint256 nameLength = emojiCount;
        // uint256 nameLength = bytes(label).length;

        if (nameLength == 1) {
            pricePerYear = 420_000000; // 1 character
        } else if (nameLength == 2) {
            pricePerYear = 269_000000; // 2 characters
        } else if (nameLength == 3) {
            pricePerYear = 169_000000; // 3 characters
        } else if (nameLength == 4) {
            pricePerYear = 69_000000; // 4 characters
        } else {
            pricePerYear = 25_000000; // 5+ characters
        }

        uint256 discount_;
        if (duration == 1) {
            discount_ = 0;
        } else if (duration == 2) {
            discount_ = 5;
        } else if (duration == 3) {
            discount_ = 15;
        } else if (duration == 4) {
            discount_ = 30;
        } else {
            discount_ = 40;
        }

        uint256 totalPrice = pricePerYear * duration;
        uint256 discountAmount = (totalPrice * discount_) / 100;
        return (totalPrice /*- discountAmount*/, discountAmount);
    }

    /// @notice Converts a price from a stablecoin equivalent to ETH.
    /// @param price The price in stablecoin.
    /// @return The price in ETH.
    function convertToToken(uint256 price) internal pure returns (uint256) {
        return price * 2000; // Assuming 1 ETH = 2000 stablecoin units
        // TODO: This needs to plug into an oracle to get the conversion rate and calculate the price
        // revert("Not implemented");
    }
}