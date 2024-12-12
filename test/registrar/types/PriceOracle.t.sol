// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {PriceOracle} from "src/registrar/types/PriceOracle.sol";
import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythErrors} from "@pythnetwork/pyth-sdk-solidity/PythErrors.sol";

import {MockPyth} from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";

contract PriceOracleTest is Test {
    MockPyth pyth;
    bytes32 BERA_USD_PYTH_PRICE_FEED_ID = bytes32(uint256(0x1));

    PriceOracle priceOracle;

    function setUp() public {
        pyth = new MockPyth(60, 1);
        priceOracle = new PriceOracle(address(pyth), BERA_USD_PYTH_PRICE_FEED_ID);
    }

    // STABLE
    function test_priceStable_oneCharOneYear() public view {
        IPriceOracle.Price memory price = priceOracle.price("a", 0, 365 days, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 420_000_000);
        assertEq(price.discount, 0);
    }

    function test_priceStable_oneCharTwoYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("a", 0, 365 days * 2, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 420_000_000 * 2);
        assertEq(price.discount, price.base * 5 / 100);
    }

    function test_priceStable_oneCharThreeYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("a", 0, 365 days * 3, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 420_000_000 * 3);
        assertEq(price.discount, price.base * 15 / 100);
    }

    function test_priceStable_oneCharFourYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("a", 0, 365 days * 4, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 420_000_000 * 4);
        assertEq(price.discount, price.base * 30 / 100);
    }

    function test_priceStable_oneCharFiveYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("a", 0, 365 days * 5, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 420_000_000 * 5);
        assertEq(price.discount, price.base * 40 / 100);
    }

    function test_priceStable_twoCharOneYear() public view {
        IPriceOracle.Price memory price = priceOracle.price("ab", 0, 365 days, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 269_000_000);
        assertEq(price.discount, 0);
    }

    function test_priceStable_twoCharTwoYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("ab", 0, 365 days * 2, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 269_000_000 * 2);
        assertEq(price.discount, price.base * 5 / 100);
    }

    function test_priceStable_twoCharThreeYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("ab", 0, 365 days * 3, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 269_000_000 * 3);
        assertEq(price.discount, price.base * 15 / 100);
    }

    function test_priceStable_twoCharFourYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("ab", 0, 365 days * 4, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 269_000_000 * 4);
        assertEq(price.discount, price.base * 30 / 100);
    }

    function test_priceStable_twoCharFiveYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("ab", 0, 365 days * 5, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 269_000_000 * 5);
        assertEq(price.discount, price.base * 40 / 100);
    }

    function test_priceStable_threeCharOneYear() public view {
        IPriceOracle.Price memory price = priceOracle.price("abc", 0, 365 days, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 169_000_000);
        assertEq(price.discount, 0);
    }

    function test_priceStable_threeCharTwoYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abc", 0, 365 days * 2, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 169_000_000 * 2);
        assertEq(price.discount, price.base * 5 / 100);
    }

    function test_priceStable_threeCharThreeYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abc", 0, 365 days * 3, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 169_000_000 * 3);
        assertEq(price.discount, price.base * 15 / 100);
    }

    function test_priceStable_threeCharFourYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abc", 0, 365 days * 4, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 169_000_000 * 4);
        assertEq(price.discount, price.base * 30 / 100);
    }

    function test_priceStable_threeCharFiveYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abc", 0, 365 days * 5, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 169_000_000 * 5);
        assertEq(price.discount, price.base * 40 / 100);
    }

    function test_priceStable_fourCharOneYear() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcd", 0, 365 days, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 69_000_000);
        assertEq(price.discount, 0);
    }

    function test_priceStable_fourCharTwoYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcd", 0, 365 days * 2, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 69_000_000 * 2);
        assertEq(price.discount, price.base * 5 / 100);
    }

    function test_priceStable_fourCharThreeYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcd", 0, 365 days * 3, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 69_000_000 * 3);
        assertEq(price.discount, price.base * 15 / 100);
    }

    function test_priceStable_fourCharFourYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcd", 0, 365 days * 4, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 69_000_000 * 4);
        assertEq(price.discount, price.base * 30 / 100);
    }

    function test_priceStable_fourCharFiveYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcd", 0, 365 days * 5, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 69_000_000 * 5);
        assertEq(price.discount, price.base * 40 / 100);
    }

    function test_priceStable_fiveCharOneYear() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcde", 0, 365 days, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 25_000_000);
        assertEq(price.discount, 0);
    }

    function test_priceStable_fiveCharTwoYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcde", 0, 365 days * 2, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 25_000_000 * 2);
        assertEq(price.discount, price.base * 5 / 100);
    }

    function test_priceStable_fiveCharThreeYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcde", 0, 365 days * 3, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 25_000_000 * 3);
        assertEq(price.discount, price.base * 15 / 100);
    }

    function test_priceStable_fiveCharFourYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcde", 0, 365 days * 4, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 25_000_000 * 4);
        assertEq(price.discount, price.base * 30 / 100);
    }

    function test_priceStable_fiveCharFiveYears() public view {
        IPriceOracle.Price memory price = priceOracle.price("abcde", 0, 365 days * 5, IPriceOracle.Payment.STABLE);

        assertEq(price.base, 25_000_000 * 5);
        assertEq(price.discount, price.base * 40 / 100);
    }

    // BERA
    // https://docs.pyth.network/price-feeds/create-your-first-pyth-app/evm/part-1
    function createBeraUpdate(int64 beraPrice) private view returns (bytes[] memory) {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createPriceFeedUpdateData(
            BERA_USD_PYTH_PRICE_FEED_ID,
            beraPrice * 100_000, // price
            10 * 100_000, // confidence
            -5, // exponent
            beraPrice * 100_000, // emaPrice
            10 * 100_000, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        return updateData;
    }

    function setBeraPrice(int64 beraPrice) private {
        bytes[] memory updateData = createBeraUpdate(beraPrice);
        uint256 value = pyth.getUpdateFee(updateData);
        vm.deal(address(this), value);
        pyth.updatePriceFeeds{value: value}(updateData);
    }

    function test_priceBera_oneCharOneYear() public {
        setBeraPrice(1);

        IPriceOracle.Price memory price = priceOracle.price("a", 0, 365 days, IPriceOracle.Payment.BERA);

        assertEq(price.base, 420 * 10 ** 18);
        assertEq(price.discount, 0);
    }

    function test_priceBera_oneCharTwoYears() public {
        setBeraPrice(1);

        IPriceOracle.Price memory price = priceOracle.price("a", 0, 365 days * 2, IPriceOracle.Payment.BERA);

        assertEq(price.base, 420 * 2 * 10 ** 18);
        assertEq(price.discount, 420 * 2 * 10 ** 18 * 5 / 100);
    }

    function test_priceBera_oneCharStale() public {
        setBeraPrice(1);

        skip(120);
        vm.expectRevert(abi.encodeWithSelector(PythErrors.StalePrice.selector));
        priceOracle.price("a", 0, 365 days * 2, IPriceOracle.Payment.BERA);
    }

    function test_priceBera_oneCharLessThanThreshold() public {
        priceOracle.setMinPriceInWei(10 ** 18);
        setBeraPrice(1);

        vm.expectRevert(abi.encodeWithSelector(PriceOracle.PriceTooLow.selector));
        priceOracle.price("a", 0, 365 days * 2, IPriceOracle.Payment.BERA);
    }

    function test_register_price_for_2_years_minus_1_day() public {
        setBeraPrice(1);

        uint256 duration = 365 days * 2 - 1 days;

        IPriceOracle.Price memory price = priceOracle.price("more_than_5_chars", 0, duration, IPriceOracle.Payment.BERA);

        uint256 expectedBase = (25_00_0000 * duration / 365 days);
        uint256 expectedDiscount = (expectedBase * 5) / 100;
        assertEq(price.base, expectedBase * 10 ** 12);
        assertEq(price.discount, expectedDiscount * 10 ** 12);
    }
}
