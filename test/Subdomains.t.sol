// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RegistrarController} from "src/registrar/Registrar.sol";
import {BERA_NODE} from "src/utils/Constants.sol";
import {IAddrResolver} from "src/resolver/interfaces/IAddrResolver.sol";

import {SystemTest} from "./System.t.sol";

contract SubdomainsTest is SystemTest {
    function test_subdomain_mint__success() public {
        alice = 0x0000000000000000000000000000000000000001;

        vm.startPrank(alice);
        vm.deal(alice, 10 ether);

        RegistrarController.RegisterRequest memory request = RegistrarController.RegisterRequest({
            name: "alice",
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
        registrar.register{value: 1 ether}(request);

        bytes32 node_ = _calculateNode(keccak256(bytes("alice")), BERA_NODE);
        resolver.setAddr(node_, alice);

        // check NFT
        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes("alice")))), alice, "NFT owner does not match alice");

        // from alice.bera to alice
        bytes memory dnsEncName_ = bytes("\x05alice\x04bera\x00");
        (bytes memory resp_, address resolvedAddress) =
            universalResolver.resolve(dnsEncName_, abi.encodeWithSelector(IAddrResolver.addr.selector, node_));
        assertEq(abi.decode(resp_, (address)), alice, "Resolved address does not match alice");
        assertEq(resolvedAddress, address(resolver), "resolver not matching");

        // from alice to alice.bera
        bytes memory dnsEncodedReverseName =
            bytes("\x280000000000000000000000000000000000000001\x04addr\x07reverse\x00");

        (
            string memory returnedName,
            address secondResolvedAddress,
            address reverseResolvedAddress,
            address resolverAddress
        ) = universalResolver.reverse(dnsEncodedReverseName);
        assertEq(returnedName, "alice.bera", "returned name does not match alice.bera");
        assertEq(secondResolvedAddress, alice, "resolved address does not match alice");
        assertEq(reverseResolvedAddress, address(resolver), "reverse resolved address does not match 0");
        assertEq(resolverAddress, address(resolver), "resolver address does not match resolver");

        // mint subdomain.alice.bera
        RegistrarController.RegisterRequest memory subdomainRequest = RegistrarController.RegisterRequest({
            name: "subdomain.alice",
            owner: alice,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: true,
            referrer: address(0)
        });
        registrar.register{value: 1 ether}(subdomainRequest);

        bytes32 subdomainNode_ = _calculateNode(keccak256(bytes("subdomain.alice")), BERA_NODE);
        resolver.setAddr(subdomainNode_, alice);

        // check NFT
        assertEq(
            baseRegistrar.ownerOf(uint256(keccak256(bytes("subdomain.alice")))),
            alice,
            "NFT subdomain owner does not match alice"
        );

        // from subdomain.alice.bera to alice
        bytes memory subdmainDnsEncName_ = bytes("\x09subdomain\x05alice\x04bera\x00");
        (bytes memory subdomainResp_, address subdomainResolvedAddress) = universalResolver.resolve(
            subdmainDnsEncName_, abi.encodeWithSelector(IAddrResolver.addr.selector, subdomainNode_)
        );
        assertEq(abi.decode(subdomainResp_, (address)), alice, "Subdomain Resolved address does not match alice");
        assertEq(subdomainResolvedAddress, address(resolver), "Subdomain resolver not matching");

        vm.stopPrank();
    }
}
