// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

/// @title Interface for Bera Names Auction House
interface IBeraAuctionHouse {
    /// Errors -----------------------------------------------------------
    /// @notice Thrown when the token is not up for auction.
    /// @param tokenId The token ID that is not up for auction.
    error TokenNotForUpAuction(uint256 tokenId);

    /// @notice Thrown when the auction has expired.
    error AuctionExpired();

    /// @notice Thrown when the bid is less than the reserve price.
    error MustSendAtLeastReservePrice();

    /// @notice Thrown when the bid is less than the minimum bid increment percentage amount.
    error MustSendMoreThanLastBidByMinBidIncrementPercentageAmount();

    /// @notice Thrown when the time buffer is too large.
    error TimeBufferTooLarge(uint256 timeBuffer);

    /// @notice Thrown when the min bid increment percentage is zero.
    error MinBidIncrementPercentageIsZero();

    /// @notice Thrown when the auction has not begun.
    error AuctionNotBegun();

    /// @notice Thrown when the auction has already been settled.
    error AuctionAlreadySettled();

    /// @notice Thrown when the auction has not completed.
    error AuctionNotCompleted();

    /// @notice Thrown when there is missing data.
    error MissingSettlementsData();

    /// @notice Thrown when there is not enough history.
    error NotEnoughHistory();

    /// @notice Thrown when the start ID is too large.
    error StartIdTooLarge(uint256 startId);

    /// @notice Thrown when the payment receiver is being set to address(0).
    error InvalidPaymentReceiver();

    /// @notice Thrown when the reserve price is being set to 0.
    error InvalidReservePrice();

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

    /// @notice Emitted when an auction is created.
    /// @param tokenId The token ID of the auction.
    /// @param startTime The start time of the auction.
    /// @param endTime The end time of the auction.
    event AuctionCreated(uint256 indexed tokenId, uint256 startTime, uint256 endTime);

    /// @notice Emitted when a bid is placed.
    /// @param tokenId The token ID of the auction.
    /// @param sender The address of the sender.
    /// @param value The amount of the bid.
    /// @param extended Whether the auction was extended.
    event AuctionBid(uint256 indexed tokenId, address sender, uint256 value, bool extended);

    /// @notice Emitted when the auction is extended.
    /// @param tokenId The token ID of the auction.
    /// @param endTime The new end time.
    event AuctionExtended(uint256 indexed tokenId, uint256 endTime);

    /// @notice Emitted when the auction is settled.
    /// @param tokenId The token ID of the auction.
    /// @param winner The address of the winner.
    /// @param amount The amount of the winning bid.
    event AuctionSettled(uint256 indexed tokenId, address winner, uint256 amount);

    /// @notice Emitted when the time buffer is updated.
    /// @param timeBuffer The new time buffer.
    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    /// @notice Emitted when the reserve price is updated.
    /// @param reservePrice The new reserve price.
    event AuctionReservePriceUpdated(uint256 reservePrice);

    /// @notice Emitted when the minimum bid increment percentage is updated.
    /// @param minBidIncrementPercentage The new minimum bid increment percentage.
    event AuctionMinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    /// @notice Emitted when the auction creation fails.
    /// @param reason The reason why the auction creation failed.
    event AuctionCreationError(string reason);

    /// @notice Emitted when ETH is processed.
    /// @param sender The address of the sender.
    /// @param to The address of the receiver.
    /// @param amount The amount of ETH processed.
    event ETHPaymentProcessed(address sender, address to, uint256 amount);

    /// @notice Emitted when the payment receiver is updated.
    ///
    /// @param newPaymentReceiver The address of the new payment receiver.
    event PaymentReceiverUpdated(address newPaymentReceiver);

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
