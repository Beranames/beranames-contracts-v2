// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";

import {StringUtils} from "src/utils/StringUtils.sol";

contract PriceOracle is IPriceOracle {
    using StringUtils for string;

    /// @notice Calculates the price for a given label with a default payment method of ETH.
    /// @param label The label to query.
    /// @param expires The expiry of the label.
    /// @param duration The duration of the registration.
    /// @return The price of the label.
    function price(string calldata label, uint256 expires, uint256 duration)
        external
        pure
        override
        returns (Price memory)
    {
        return price(label, expires, duration, Payment.STABLE);
    }

    /// @notice Calculates the price for a given label with a specified payment method.
    /// @param label The label to query.
    /// param expiry The expiry of the label. Not used atm
    /// @param duration The duration of the registration.
    /// @param payment The payment method.
    /// @return The price of the label.
    function price(string calldata label, uint256, uint256 duration, Payment payment)
        public
        pure
        override
        returns (Price memory)
    {
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
    function calculateBasePrice(string calldata label, uint256 duration)
        internal
        pure
        returns (uint256 base, uint256 discount)
    {
        uint256 nameLength = label.strlen();

        uint256 pricePerYear;
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
        return (totalPrice, /*- discountAmount*/ discountAmount);
    }

    /// @notice Converts a price from a stablecoin equivalent to ETH.
    /// @param price_ The price in stablecoin.
    /// @return The price in ETH.
    function convertToToken(uint256 price_) internal pure returns (uint256) {
        return price_ * 2000; // Assuming 1 ETH = 2000 stablecoin units
            // TODO: This needs to plug into an oracle to get the conversion rate and calculate the price
            // revert("Not implemented");
    }
}
