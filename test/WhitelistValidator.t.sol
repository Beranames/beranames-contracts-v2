// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WhitelistValidator} from "src/registrar/types/WhitelistValidator.sol";

import {Test} from "forge-std/Test.sol";

contract WhitelistValidatorTest is Test {
    WhitelistValidator public whitelistValidator;
    address public whitelistAuthorizer;
    uint256 public whitelistAuthorizerPk;

    function setUp() public {
        (whitelistAuthorizer, whitelistAuthorizerPk) = makeAddrAndKey("whitelistAuthorizer");
        address owner = makeAddr("owner");

        whitelistValidator = new WhitelistValidator(owner, whitelistAuthorizer);
    }

    function test_validateSignature__valid() public view {
        bytes memory payload = abi.encode("This is a message to sign");
        bytes32 hash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", abi.encodePacked(keccak256(payload))));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistAuthorizerPk, hash);

        address signer = ecrecover(hash, v, r, s);
        assertEq(signer, whitelistAuthorizer, "signer");

        whitelistValidator.validateSignature(payload, v, r, s);
        // it doesn't raise InvalidSignature
    }

    function test_validateSignature__invalid_r_s_v() public {
        bytes memory payload = abi.encode("This is another message to sign");
        vm.expectRevert(abi.encodeWithSelector(WhitelistValidator.InvalidSignature.selector));

        whitelistValidator.validateSignature(payload, 0, bytes32(0), bytes32(0));
    }

    function test_validateSignature__invalid_signer() public {
        bytes memory payload = abi.encode("This is one more message to sign");
        vm.expectRevert(abi.encodeWithSelector(WhitelistValidator.InvalidSignature.selector));

        (, uint256 secondWhitelistAuthorizerPk) = makeAddrAndKey("secondWhitelistAuthorizer");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(secondWhitelistAuthorizerPk, keccak256(payload));
        whitelistValidator.validateSignature(payload, v, r, s);
    }
}
