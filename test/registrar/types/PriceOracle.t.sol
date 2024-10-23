// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {PriceOracle} from "src/registrar/types/PriceOracle.sol";
import {IPriceOracle} from "src/registrar/interfaces/IPriceOracle.sol";

contract PriceOracleTest is Test {
    PriceOracle priceOracle = new PriceOracle();

    function setUp() public {}

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
}
