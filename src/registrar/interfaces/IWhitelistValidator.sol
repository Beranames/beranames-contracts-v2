// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IWhitelistValidator {
    function validateSignature(
        bytes memory message,
        uint8 v, bytes32 r, bytes32 s
    ) external view;
}
