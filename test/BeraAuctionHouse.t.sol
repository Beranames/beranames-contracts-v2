// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BeraAuctionHouse} from "src/auction/BeraAuctionHouse.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/auction/interfaces/IWETH.sol";
import {BERA_NODE} from "script/System.s.sol";
import {IBeraAuctionHouse} from "src/auction/interfaces/IBeraAuctionHouse.sol";

import {SystemTest} from "./System.t.sol";

contract BeraAuctionHouseTest is SystemTest {
    function test_owner() public view {
        assertEq(address(auctionHouse.owner()), address(registrarAdmin), "auctionHouse owner");
    }

    function test_unpause() public {
        string memory label = unicode"😀";

        vm.expectEmit(true, false, false, false);
        emit IBeraAuctionHouse.AuctionCreated(getTokenId(label), 1, 1);
        unpause(label);

        assertEq(auctionHouse.paused(), false, "auctionHouse paused");
        assertEq(auctionHouse.auction().tokenId, getTokenId(label), "auctionHouse tokenId");
        assertEq(auctionHouse.auction().amount, 0, "auctionHouse amount");
        assertEq(auctionHouse.auction().startTime, uint40(block.timestamp), "auctionHouse startTime");
        assertEq(auctionHouse.auction().endTime, uint40(block.timestamp + 1 days), "auctionHouse endTime");
        assertEq(auctionHouse.auction().bidder, address(0), "auctionHouse bidder");
        assertEq(auctionHouse.auction().settled, false, "auctionHouse settled");

        // check that auction house owns the nft
        assertEq(baseRegistrar.balanceOf(address(auctionHouse)), 1, "auctionHouse base balance");
        assertEq(baseRegistrar.isAvailable(getNftId(label)), false, "auctionHouse base available");
        assertEq(baseRegistrar.ownerOf(getNftId(label)), address(auctionHouse), "auctionHouse base owner");
    }

    function test_createBid_success() public {
        string memory label = unicode"😀";
        unpause(label);

        vm.prank(alice);
        vm.deal(alice, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit IBeraAuctionHouse.AuctionBid(getTokenId(label), address(alice), 1 ether, false);

        auctionHouse.createBid{value: 1 ether}(getTokenId(label));

        assertEq(auctionHouse.auction().amount, 1 ether, "auctionHouse amount");
        assertEq(auctionHouse.auction().bidder, address(alice), "auctionHouse bidder");
        vm.stopPrank();
    }

    function test_createBid_success_auctionExtended() public {}

    function test_createBid_success_refundLastBidder() public {
        string memory label = unicode"😀";
        test_createBid_success();

        vm.prank(bob);
        vm.deal(bob, 2 ether);

        vm.expectEmit(true, true, true, true);
        emit IBeraAuctionHouse.AuctionBid(getTokenId(label), address(bob), 2 ether, false);

        auctionHouse.createBid{value: 2 ether}(getTokenId(label));

        assertEq(auctionHouse.auction().amount, 2 ether, "auctionHouse amount");
        assertEq(auctionHouse.auction().bidder, address(bob), "auctionHouse bidder");
        assertEq(address(bob).balance, 0 ether, "bob balance");
        assertEq(address(alice).balance, 1 ether, "alice balance");
    }

    function test_createBid_failure_invalidTokenId() public {}

    function test_createBid_failure_auctionExpired() public {}

    function test_createBid_failure_invalidBidAmount() public {}

    function test_createBid_failure_invalidBidIncrement() public {}

    function test_settleAuction_success() public {
        string memory label = unicode"😀";
        unpause(label);

        vm.prank(alice);
        vm.deal(alice, 1 ether);
        auctionHouse.createBid{value: 1 ether}(getTokenId(label));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);

        vm.prank(bob);
        vm.deal(bob, 2 ether);
        auctionHouse.createBid{value: 2 ether}(getTokenId(label));
        vm.stopPrank();

        vm.warp(block.timestamp + 24 hours);

        vm.prank(registrarAdmin);
        auctionHouse.pause();

        // this triggers ERC721NonexistentToken
        // because auction token Id !== nft id
        auctionHouse.settleAuction();
        vm.stopPrank();

        assertEq(address(auctionHouse).balance, 0 ether, "auctionHouse balance");
        assertEq(address(alice).balance, 1 ether, "alice balance");
        assertEq(address(bob).balance, 0 ether, "bob balance");
    }

    function test_settleAuction_failure_auctionNotBegun() public {}

    function test_settleAuction_failure_auctionAlreadySettled() public {}

    function test_settleAuction_failure_auctionNotCompleted() public {}

    function getNftId(string memory label_) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(label_)));
    }

    function getTokenId(string memory label_) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(BERA_NODE, bytes32(getNftId(label_)))));
    }

    function unpause(string memory label_) internal prank(registrarAdmin) {
        auctionHouse.unpause(label_);
    }
}
