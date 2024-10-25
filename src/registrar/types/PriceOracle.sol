// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {StringUtils} from "src/utils/StringUtils.sol";
import {console} from "forge-std/console.sol";

contract PriceOracle is IPriceOracle, Ownable {
    using StringUtils for string;

    IPyth pyth;
    bytes32 beraUsdPythPriceFeedId;

    /// @notice The minimum price in wei. If conversion is less than this, revert. Editable by admin
    uint256 minPriceInWei;

    /// @notice Thrown when the price is too low.
    error PriceTooLow();

    /// @notice Emitted when the minimum price in wei is set.
    event MinPriceInWeiSet(uint256 minPriceInWei_);

    /// @notice Emitted when the Pyth price feed id is set.
    event BeraUsdPythPriceFeedIdSet(bytes32 beraUsdPythPriceFeedId_);

    /// @notice Emitted when the Pyth contract is set.
    event PythSet(address pyth_);

    constructor(address pyth_, bytes32 beraUsdPythPriceFeedId_) Ownable(msg.sender) {
        pyth = IPyth(pyth_);
        beraUsdPythPriceFeedId = beraUsdPythPriceFeedId_;
    }

    function setMinPriceInWei(uint256 minPriceInWei_) external onlyOwner {
        minPriceInWei = minPriceInWei_;
        emit MinPriceInWeiSet(minPriceInWei_);
    }

    function setBeraUsdPythPriceFeedId(bytes32 beraUsdPythPriceFeedId_) external onlyOwner {
        beraUsdPythPriceFeedId = beraUsdPythPriceFeedId_;
        emit BeraUsdPythPriceFeedIdSet(beraUsdPythPriceFeedId_);
    }

    function setPyth(address pyth_) external onlyOwner {
        pyth = IPyth(pyth_);
        emit PythSet(pyth_);
    }

    /// @notice Calculates the price for a given label with a default payment method of ETH.
    /// @param label The label to query.
    /// @param expires The expiry of the label.
    /// @param duration The duration of the registration in seconds.
    /// @return The price of the label.
    function price(string calldata label, uint256 expires, uint256 duration) external view returns (Price memory) {
        return price(label, expires, duration, Payment.BERA);
    }

    /// @notice Calculates the price for a given label with a specified payment method.
    /// @param label The label to query.
    /// param expiry The expiry of the label. Not used atm
    /// @param duration The duration of the registration in seconds.
    /// @param payment The payment method.
    /// @return The price of the label.
    function price(string calldata label, uint256, uint256 duration, Payment payment)
        public
        view
        returns (Price memory)
    {
        // Implement your logic to calculate the base and premium price
        (uint256 basePrice, uint256 discount) = calculateBasePrice(label, duration);

        // Adjust the price based on the payment method if necessary
        if (payment == Payment.BERA) {
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
        // notation is $_cents_4zeros => $*10^6
        if (nameLength == 1) {
            pricePerYear = 420_00_0000; // 1 character 420$
        } else if (nameLength == 2) {
            pricePerYear = 269_00_0000; // 2 characters 269$
        } else if (nameLength == 3) {
            pricePerYear = 169_00_0000; // 3 characters 169$
        } else if (nameLength == 4) {
            pricePerYear = 69_00_0000; // 4 characters 69$
        } else {
            pricePerYear = 25_00_0000; // 5+ characters 25$
        }

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

    /// @notice Converts a price from a stablecoin equivalent to ETH.
    /// @dev This function can revert with StalePrice
    /// @param price_ The price in stablecoin.
    /// @return The price in BERA.
    function convertToToken(uint256 price_) internal view returns (uint256) {
        PythStructs.Price memory conversionRate = pyth.getPriceNoOlderThan(beraUsdPythPriceFeedId, 30);

        uint256 beraPrice18Decimals =
            (uint256(uint64(conversionRate.price)) * (10 ** 18)) / (10 ** uint8(uint32(-1 * conversionRate.expo)));
        // 6 is the number of decimals in USD prices, so 18-6=12
        uint256 oneDollarInWei = ((10 ** 12) * (10 ** 18)) / beraPrice18Decimals;

        // if the price of 1 dollar is less than the minimum price, revert
        // prevent the price from being too low if price feed is down
        if (oneDollarInWei <= minPriceInWei) revert PriceTooLow();

        return price_ * oneDollarInWei;
    }
}
