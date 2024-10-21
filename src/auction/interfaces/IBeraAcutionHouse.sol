// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

/// @title Interface for Bera Names Auction House
interface IBeraAuctionHouse {
    struct Auction {
        uint256 tokenId;
        uint128 amount;
        uint64 startTime;
        uint64 endTime;
        // The address of the current highest bid
        address payable bidder;
        // Whether or not the auction has been settled
        bool settled;
    }

    /// @dev We use this struct as the return value of the `auction` function, to maintain backwards compatibility.
    /// @param labelHash The labelHash for the name (max X characters)
    /// @param amount The current highest bid amount
    /// @param startTime The auction period start time
    /// @param endTime The auction period end time
    /// @param bidder The address of the current highest bid
    /// @param settled Whether or not the auction has been settled
    struct AuctionView {
        // Slug 1
        uint256 tokenId;
        // Slug 2
        uint128 amount;
        uint64 startTime;
        uint64 endTime;
        // Slug 3
        address payable bidder;
        bool settled;
    }

    /// @param blockTimestamp The block.timestamp when the auction was settled.
    /// @param amount The winning bid amount, with 10 decimal places (reducing accuracy to save bits).
    /// @param winner The address of the auction winner.
    struct SettlementState {
        uint32 blockTimestamp;
        uint64 amount;
        address winner;
    }

    /// @param blockTimestamp The block.timestamp when the auction was settled.
    /// @param amount The winning bid amount, converted from 10 decimal places to 18, for better client UX.
    /// @param winner The address of the auction winner.
    /// @param tokenId ID for the label (label hash).
    struct Settlement {
        uint32 blockTimestamp;
        uint256 amount;
        address winner;
        uint256 tokenId;
    }

    event AuctionCreated(uint256 indexed tokenId, uint256 startTime, uint256 endTime);

    event AuctionBid(uint256 indexed tokenId, address sender, uint256 value, bool extended);

    event AuctionExtended(uint256 indexed tokenId, uint256 endTime);

    event AuctionSettled(uint256 indexed tokenId, address winner, uint256 amount);

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionMinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction(string memory label_) external;

    function createBid(uint256 tokenId) external payable;

    // Management functions

    function pause() external;
    function unpause(string memory label_) external;

    function setTimeBuffer(uint56 timeBuffer) external;
    function setReservePrice(uint192 reservePrice) external;
    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage) external;

    function auction() external view returns (AuctionView memory);

    function getSettlements(uint256 auctionCount) external view returns (Settlement[] memory settlements);

    function getPrices(uint256 auctionCount) external view returns (uint256[] memory prices);

    function getSettlements(uint256 startId, uint256 endId) external view returns (Settlement[] memory settlements);

    function getSettlementsFromIdtoTimestamp(uint256 startId, uint256 endTimestamp)
        external
        view
        returns (Settlement[] memory settlements);

    function auctionDuration() external view returns (uint256);
    function registrationDuration() external view returns (uint256);
}
