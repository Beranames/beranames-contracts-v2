//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

interface IPriceOracle {
    /// @notice The payment method for registration.
    enum Payment {
        ETH,
        STABLE
    }

    /// @notice The price for a given name.
    struct Price {
        uint256 base;
        uint256 premium;
    }

    /// @notice The price for a given name.
    /// This assumes a default payment method of ETH.
    /// @param name The name to query.
    /// @param expires The expiry of the name.
    /// @param duration The duration of the registration.
    /// @return The price of the name.
    function price(
        string calldata name, 
        uint256 expires, 
        uint256 duration
    ) external view returns (Price calldata);

    /// @notice The price for a given name.
    /// @param name The name to query.
    /// @param expires The expiry of the name.
    /// @param duration The duration of the registration.
    /// @param payment The payment method.
    /// @return The price of the name.
    function price(
        string calldata name, 
        uint256 expires, 
        uint256 duration,
        Payment payment
    ) external view returns (Price calldata);
}
