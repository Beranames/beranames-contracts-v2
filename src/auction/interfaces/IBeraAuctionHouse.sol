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

    /// @notice Thrown when there are no auctions.
    error NoAuctions();

    /// @notice Thrown when the provided range is invalid.
    error InvalidRange();

    /// @notice Thrown when the start ID is too large.
    error StartIdTooLarge(uint256 startId);

    /// @notice Thrown when the payment receiver is being set to address(0).
    error InvalidPaymentReceiver();

    /// @notice Thrown when the reserve price is being set to 0.
    error InvalidReservePrice();

    /// @notice Thrown when the max auction count is being set to 0.
    error MaxAuctionCountIsZero();

    /// @notice Thrown when the max auction count is exceeded.
    error MaxAuctionCountExceeded(uint256 auctionCount);

    /// @notice Thrown when the price exceeds the uint64 range.
    error PriceExceedsUint64Range(uint256 price);

    struct Auction {
        uint256 tokenId;
        uint256 amount;
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
        uint256 amount;
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

    event AuctionCreationError(string reason);

    event MaxAuctionCountUpdated(uint256 maxAuctionCount);

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
