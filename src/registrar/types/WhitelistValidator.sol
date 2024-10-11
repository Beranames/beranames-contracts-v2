// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {IWhitelistValidator} from "src/registrar/interfaces/IWhitelistValidator.sol";

import {console} from "forge-std/console.sol";

contract WhitelistValidator is Ownable, IWhitelistValidator {
    /// Errors -----------------------------------------------------------

    error InvalidPayload();
    error InvalidSignature();

    /// State ------------------------------------------------------------

    address private _whitelistAuthorizer;

    /// Constructor ------------------------------------------------------

    constructor(address owner_, address whitelistAuthorizer_) Ownable(owner_) {
        _transferOwnership(owner_);
        _whitelistAuthorizer = whitelistAuthorizer_;
    }

    /// Admin Functions  ---------------------------------------------------

    function setWhitelistAuthorizer(address whitelistAuthorizer_) public onlyOwner {
        _whitelistAuthorizer = whitelistAuthorizer_;
    }

    /// Validation -------------------------------------------------------

    function validateSignature(bytes memory message, uint8 v, bytes32 r, bytes32 s) public view {
        // Recover the signer from the signature
        console.log("message");
        console.logBytes(message);
        console.log("v", v);
        console.log("r");
        console.logBytes32(r);
        console.log("s");
        console.logBytes32(s);
        address signer_ = ecrecover(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", abi.encodePacked(keccak256(message)))),
            v,
            r,
            s
        );
        console.log("signer from WhitelistValidator.sol", signer_);

        // Validate the recovered signer
        if (signer_ == address(0) || signer_ != _whitelistAuthorizer) revert InvalidSignature();
    }
}
