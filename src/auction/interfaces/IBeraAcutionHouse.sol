// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

/// @title Interface for Bera Names Auction House
interface IBeraAuctionHouse {
    struct Auction {
        bytes32 labelHash;

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
        bytes32 labelHash;
        
        // Slug 2
        uint128 amount;
        uint64 startTime;
        uint64 endTime;
        
        // Slug 3
        address payable bidder;
        bool settled;
    }

    struct SettlementState {
        // The block.timestamp when the auction was settled.
        uint32 blockTimestamp;
        // The winning bid amount, with 10 decimal places (reducing accuracy to save bits).
        uint64 amount;
        // The address of the auction winner.
        address winner;
        // ID of the client that facilitated the winning bid, used for client rewards.
        uint32 clientId;
        // Used only to warm up the storage slot for clientId without setting the clientId value.
        bool slotWarmedUp;
    }

    struct Settlement {
        // The block.timestamp when the auction was settled.
        uint32 blockTimestamp;
        // The winning bid amount, converted from 10 decimal places to 18, for better client UX.
        uint256 amount;
        // The address of the auction winner.
        address winner;
        // ID for the Noun (ERC721 token ID).
        uint256 nounId;
        // ID of the client that facilitated the winning bid, used for client rewards
        uint32 clientId;
    }

    /// @dev Using this struct when setting historic prices, and excluding clientId to save gas.
    struct SettlementNoClientId {
        // The block.timestamp when the auction was settled.
        uint32 blockTimestamp;
        // The winning bid amount, converted from 10 decimal places to 18, for better client UX.
        uint256 amount;
        // The address of the auction winner.
        address winner;
        // ID for the Noun (ERC721 token ID).
        uint256 nounId;
    }

    event AuctionCreated(uint256 indexed nounId, uint256 startTime, uint256 endTime);

    event AuctionBid(uint256 indexed nounId, address sender, uint256 value, bool extended);

    event AuctionBidWithClientId(uint256 indexed nounId, uint256 value, uint32 indexed clientId);

    event AuctionExtended(uint256 indexed nounId, uint256 endTime);

    event AuctionSettled(uint256 indexed nounId, address winner, uint256 amount);

    event AuctionSettledWithClientId(uint256 indexed nounId, uint32 indexed clientId);

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionMinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    function settleAuction() external;

    function settleCurrentAndCreateNewAuction() external;

    function createBid(bytes32 labelHash) external payable;

    // Management functions

    function pause() external;
    function unpause() external;

    function setTimeBuffer(uint56 timeBuffer) external;
    function setReservePrice(uint192 reservePrice) external;
    function setMinBidIncrementPercentage(uint8 minBidIncrementPercentage) external;

    function auction() external view returns (AuctionView memory);

    function getSettlements(
        uint256 auctionCount,
        bool skipEmptyValues
    ) external view returns (Settlement[] memory settlements);

    function getPrices(uint256 auctionCount) external view returns (uint256[] memory prices);

    function getSettlements(
        uint256 startId,
        uint256 endId,
        bool skipEmptyValues
    ) external view returns (Settlement[] memory settlements);

    function getSettlementsFromIdtoTimestamp(
        uint256 startId,
        uint256 endTimestamp,
        bool skipEmptyValues
    ) external view returns (Settlement[] memory settlements);

    function warmUpSettlementState(uint256 startId, uint256 endId) external;

    function duration() external view returns (uint256);

    function biddingClient(uint256 nounId) external view returns (uint32 clientId);
}