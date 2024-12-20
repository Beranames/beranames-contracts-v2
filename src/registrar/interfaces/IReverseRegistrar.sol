// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IReverseRegistrar {
    /// @notice Thrown when the registry is invalid.
    error InvalidRegistry();

    function claim(address claimant) external returns (bytes32);

    function setNameForAddr(address addr, address owner, address resolver, string memory name)
        external
        returns (bytes32);
}
