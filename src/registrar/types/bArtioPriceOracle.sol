// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";

import {StringUtils} from "src/utils/StringUtils.sol";

contract bArtioPriceOracle is IPriceOracle {
    using StringUtils for string;

    /// @notice Calculates the price for a given label with a default payment method of ETH.
    /// @param label The label to query.
    /// @param expires The expiry of the label.
    /// @param duration The duration of the registration in seconds.
    /// @return The price of the label.
    function price(string calldata label, uint256 expires, uint256 duration) external pure returns (Price memory) {
        return price(label, expires, duration, Payment.BERA);
    }

    /// @notice Calculates the price for a given label with a specified payment method.
    /// @param label The label to query.
    /// param expiry The expiry of the label. Not used atm
    /// @param duration The duration of the registration in seconds.
    /// @return The price of the label.
    function price(string calldata label, uint256, uint256 duration, Payment) public pure returns (Price memory) {
        (uint256 basePrice, uint256 discount) = calculateBasePrice(label, duration);

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
        // notation is $_cents_4zeros => $*10^6
        if (nameLength == 1) {
            pricePerYear = 16; // 1 character 16 BERA
        } else if (nameLength == 2) {
            pricePerYear = 8; // 2 characters 269$
        } else if (nameLength == 3) {
            pricePerYear = 4; // 3 characters 169$
        } else if (nameLength == 4) {
            pricePerYear = 2; // 4 characters 69$
        } else {
            pricePerYear = 1; // 5+ characters 25$
        }
        pricePerYear = pricePerYear * 10 ** 18;

        uint256 discount_;
        if (duration <= 365 days) {
            discount_ = 0;
        } else if (duration <= 2 * 365 days) {
            discount_ = 5;
        } else if (duration <= 3 * 365 days) {
            discount_ = 15;
        } else if (duration <= 4 * 365 days) {
            discount_ = 30;
        } else {
            discount_ = 40;
        }

        uint256 durationInYears = duration / 365 days;
        uint256 totalPrice = pricePerYear * durationInYears;
        uint256 discountAmount = (totalPrice * discount_) / 100;
        return (totalPrice, discountAmount);
    }
}
