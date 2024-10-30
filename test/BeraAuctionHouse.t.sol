// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BeraAuctionHouse} from "src/auction/BeraAuctionHouse.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";
import {BeraDefaultResolver} from "src/resolver/Resolver.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/auction/interfaces/IWETH.sol";
import {IBeraAuctionHouse} from "src/auction/interfaces/IBeraAuctionHouse.sol";

import {SystemTest} from "./System.t.sol";

contract BeraAuctionHouseTest is SystemTest {
    string constant EMOJI = unicode"💩";
    string constant BEAR_EMOJI = unicode"🐻";

    function setUp() public virtual override {
        super.setUp();

        mintToAuctionHouse();
    }

    function test_owner() public view {
        assertEq(address(auctionHouse.owner()), address(registrarAdmin), "auctionHouse owner");
    }

    function test_unpause() public {
        vm.expectEmit(true, false, false, false);
        emit IBeraAuctionHouse.AuctionCreated(getTokenId(EMOJI), 1, 1);
        unpause(EMOJI);

        assertEq(auctionHouse.paused(), false, "auctionHouse paused");
        assertEq(auctionHouse.auction().tokenId, getTokenId(EMOJI), "auctionHouse tokenId");
        assertEq(auctionHouse.auction().amount, 0, "auctionHouse amount");
        assertEq(auctionHouse.auction().startTime, uint40(block.timestamp), "auctionHouse startTime");
        assertEq(auctionHouse.auction().endTime, uint40(block.timestamp + 1 days), "auctionHouse endTime");
        assertEq(auctionHouse.auction().bidder, address(0), "auctionHouse bidder");
        assertEq(auctionHouse.auction().settled, false, "auctionHouse settled");

        // check that auction house owns the nft
        assertEq(baseRegistrar.balanceOf(address(auctionHouse)), 2, "auctionHouse base balance");
        assertEq(baseRegistrar.isAvailable(getTokenId(EMOJI)), false, "auctionHouse base available");
        assertEq(baseRegistrar.ownerOf(getTokenId(EMOJI)), address(auctionHouse), "auctionHouse base owner");
    }

    function test_createBid_success() public {
        unpause(EMOJI);

        vm.prank(alice);
        vm.deal(alice, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit IBeraAuctionHouse.AuctionBid(getTokenId(EMOJI), address(alice), 1 ether, false);

        auctionHouse.createBid{value: 1 ether}(getTokenId(EMOJI));

        assertEq(auctionHouse.auction().amount, 1 ether, "auctionHouse amount");
        assertEq(auctionHouse.auction().bidder, address(alice), "auctionHouse bidder");
        vm.stopPrank();
    }

    function test_createBid_success_auctionExtended() public {}

    function test_createBid_success_refundLastBidder() public {
        test_createBid_success();

        vm.prank(bob);
        vm.deal(bob, 2 ether);

        vm.expectEmit(true, true, true, true);
        emit IBeraAuctionHouse.AuctionBid(getTokenId(EMOJI), address(bob), 2 ether, false);

        auctionHouse.createBid{value: 2 ether}(getTokenId(EMOJI));

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
        unpause(EMOJI);

        vm.prank(alice);
        vm.deal(alice, 1 ether);
        auctionHouse.createBid{value: 1 ether}(getTokenId(EMOJI));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);

        vm.prank(bob);
        vm.deal(bob, 2 ether);
        auctionHouse.createBid{value: 2 ether}(getTokenId(EMOJI));
        vm.stopPrank();

        vm.warp(block.timestamp + 24 hours);

        vm.prank(registrarAdmin);
        auctionHouse.pause();

        // this triggers ERC721NonexistentToken
        // because auction token Id !== nft id
        vm.prank(registrarAdmin);
        auctionHouse.settleAuction();
        vm.stopPrank();

        // check balances
        assertEq(address(auctionHouse).balance, 0 ether, "auctionHouse balance");
        assertEq(address(alice).balance, 1 ether, "alice balance");
        assertEq(address(bob).balance, 0 ether, "bob balance");

        // check nft ownership
        assertEq(baseRegistrar.ownerOf(getTokenId(EMOJI)), address(bob), "nft owner");
    }

    function test_settleAuction_failure_auctionNotBegun() public {}

    function test_settleAuction_failure_auctionAlreadySettled() public {}

    function test_settleAuction_failure_auctionNotCompleted() public {}

    function test_settleCurrentAndCreateNewAuction_success() public {
        unpause(EMOJI);

        vm.prank(alice);
        vm.deal(alice, 1 ether);
        auctionHouse.createBid{value: 1 ether}(getTokenId(EMOJI));
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);

        vm.prank(bob);
        vm.deal(bob, 2 ether);
        auctionHouse.createBid{value: 2 ether}(getTokenId(EMOJI));
        vm.stopPrank();

        vm.warp(block.timestamp + 24 hours);

        string memory newLabel = BEAR_EMOJI;
        vm.prank(registrarAdmin);
        auctionHouse.settleCurrentAndCreateNewAuction(newLabel);
        vm.stopPrank();

        // check balances
        assertEq(address(auctionHouse).balance, 0 ether, "auctionHouse balance");
        assertEq(address(alice).balance, 1 ether, "alice balance");
        assertEq(address(bob).balance, 0 ether, "bob balance");

        // check nft ownership
        assertEq(baseRegistrar.ownerOf(getTokenId(EMOJI)), address(bob), "nft owner");

        // check new auction
        assertEq(auctionHouse.paused(), false, "auctionHouse paused");
        assertEq(auctionHouse.auction().tokenId, getTokenId(newLabel), "auctionHouse tokenId");
        assertEq(auctionHouse.auction().amount, 0, "auctionHouse amount");
        assertEq(auctionHouse.auction().startTime, uint40(block.timestamp), "auctionHouse startTime");
        assertEq(auctionHouse.auction().endTime, uint40(block.timestamp + 1 days), "auctionHouse endTime");
        assertEq(auctionHouse.auction().bidder, address(0), "auctionHouse bidder");
        assertEq(auctionHouse.auction().settled, false, "auctionHouse settled");
    }

    ////// Internal functions //////

    function getTokenId(string memory label_) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(label_)));
    }

    function unpause(string memory label_) internal prank(registrarAdmin) {
        auctionHouse.unpause(label_);
    }

    function mintToAuctionHouse() internal prank(address(auctionHouse)) {
        baseRegistrar.registerWithRecord(getTokenId(EMOJI), address(auctionHouse), 365 days, address(resolver), 0);
        baseRegistrar.registerWithRecord(getTokenId(BEAR_EMOJI), address(auctionHouse), 365 days, address(resolver), 0);
    }
}
