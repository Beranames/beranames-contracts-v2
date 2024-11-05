// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FlowTest} from "./Flow.t.sol";
// contracts
import {RegistrarController} from "src/registrar/Registrar.sol";
import {IAddrResolver} from "src/resolver/interfaces/IAddrResolver.sol";
import {ITextResolver} from "src/resolver/interfaces/ITextResolver.sol";
// utils
import {BERA_NODE} from "src/utils/Constants.sol";

contract NFTTest is FlowTest {
    string constant NFT_NAME = "nftname";

    function test_mint_for_address() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        registrarController.register{value: 500 ether}(defaultRequestNoReverseRecord(bob));
        bytes32 node_ = _calculateNode(keccak256(bytes(NFT_NAME)), BERA_NODE);
        assertEq(baseRegistrar.balanceOf(bob), 1, "bob should have 1 nft");
        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes(NFT_NAME)))), bob, "bob should be the owner of the nft");
        vm.stopPrank();
    }

    function test_mint_for_address_with_data() public {
        vm.startPrank(alice);
        vm.deal(alice, 1000 ether);
        bytes32 node_ = _calculateNode(keccak256(bytes(NFT_NAME)), BERA_NODE);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSignature("setAddr(bytes32,address)", node_, bob);
        data[1] =
            abi.encodeWithSignature("setText(bytes32,string,string)", node_, "avatar", "https://example.com/avatar.png");

        registrarController.register{value: 500 ether}(defaultRequestWithData(data, bob));
        assertEq(baseRegistrar.balanceOf(bob), 1, "bob should have 1 nft");
        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes(NFT_NAME)))), bob, "bob should be the owner of the nft");
        assertEq(resolver.addr(node_), bob, "address set correctly");
        assertEq(resolver.text(node_, "avatar"), "https://example.com/avatar.png", "text set correctly");
        vm.stopPrank();
    }

    function test_mint_for_address_then_change_owner_and_finally_setAddr() public {
        vm.startPrank(alice);
        // alice pays the registration fee for bob
        vm.deal(alice, 1000 ether);
        registrarController.register{value: 500 ether}(defaultRequestNoReverseRecord(bob));
        bytes32 node_ = _calculateNode(keccak256(bytes(NFT_NAME)), BERA_NODE);
        assertEq(baseRegistrar.ownerOf(uint256(keccak256(bytes(NFT_NAME)))), bob, "bob should be the owner of the nft");
        assertEq(registry.owner(node_), bob, "bob should be the owner of the node in the registry");
        vm.stopPrank();

        vm.startPrank(bob);
        // bob transfers the nft to chris
        baseRegistrar.safeTransferFrom(bob, chris, uint256(keccak256(bytes(NFT_NAME))));
        assertEq(
            baseRegistrar.ownerOf(uint256(keccak256(bytes(NFT_NAME)))), chris, "chris should be the owner of the nft"
        );
        // chris can't set the address yet because he is not the owner of the node in the registry
        vm.startPrank(chris);
        vm.expectRevert("Unauthorized");
        resolver.setAddr(node_, chris);
        vm.stopPrank();
        // but bob can?
        vm.startPrank(bob);
        resolver.setAddr(node_, bob);
        assertEq(resolver.addr(node_), bob, "bob address set correctly");
        vm.stopPrank();
        // if chris wants to set the address, he needs to reclaim the ownership of the node in the registry
        vm.startPrank(chris);
        baseRegistrar.reclaim(uint256(keccak256(bytes(NFT_NAME))), chris);
        resolver.setAddr(node_, chris);
        assertEq(resolver.addr(node_), chris, "chris address set correctly");
        vm.stopPrank();
    }

    // UTILITIES ----------------------------------------------------------------------------------------------------------
    function defaultRequestNoReverseRecord(address owner_)
        internal
        view
        returns (RegistrarController.RegisterRequest memory)
    {
        return RegistrarController.RegisterRequest({
            name: NFT_NAME,
            owner: owner_,
            duration: 365 days,
            resolver: address(resolver),
            data: new bytes[](0),
            reverseRecord: false,
            referrer: address(0)
        });
    }

    function defaultRequestWithData(bytes[] memory data_, address owner_)
        internal
        view
        returns (RegistrarController.RegisterRequest memory)
    {
        RegistrarController.RegisterRequest memory req = defaultRequestNoReverseRecord(owner_);
        req.data = data_;
        return req;
    }
}
