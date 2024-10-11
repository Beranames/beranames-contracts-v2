// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IReservedRegistry {
    function isReservedName(string memory name) external view returns (bool);
}
