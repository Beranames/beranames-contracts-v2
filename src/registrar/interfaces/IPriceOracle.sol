//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9.0;

interface IPriceOracle {
    /// @notice The payment method for registration.
    enum Payment {
        BERA,
        STABLE
    }

    /// @notice The price for a given label.
    struct Price {
        uint256 base;
        uint256 discount;
    }

    /// @notice The price for a given label.
    /// This assumes a default payment method of BERA.
    /// @param label The label to query.
    /// @param expires The expiry of the label.
    /// @param duration The duration of the registration.
    /// @return The price of the label.
    function price(string calldata label, uint256 expires, uint256 duration) external view returns (Price memory);

    /// @notice The price for a given label.
    /// @param label The label to query.
    /// @param expires The expiry of the label.
    /// @param duration The duration of the registration.
    /// @param payment The payment method.
    /// @return The price of the label.
    function price(string calldata label, uint256 expires, uint256 duration, Payment payment)
        external
        view
        returns (Price memory);
}
