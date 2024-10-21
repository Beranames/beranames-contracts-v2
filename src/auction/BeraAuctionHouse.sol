// SPDX-License-Identifier: GPL-3.0

/// @title The Bera names auction house

// LICENSE
// BeraAuctionHouse.sol is a modified version of Zora's AuctionHouse.sol:
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
//
// BeraAuctionHouse.sol source code Copyright Zora licensed under the GPL-3.0 license.
// With modifications by Beranames.
pragma solidity ^0.8.13;

import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {BaseRegistrar} from "src/registrar/types/BaseRegistrar.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/auction/interfaces/IWETH.sol";

import {IBeraAuctionHouse} from "src/auction/interfaces/IBeraAcutionHouse.sol";

import {BeraDefaultResolver} from "src/resolver/Resolver.sol";

contract BeraAuctionHouse is IBeraAuctionHouse, Pausable, ReentrancyGuard, Ownable {
    /// @notice A hard-coded cap on time buffer to prevent accidental auction disabling if set with a very high value.
    uint56 public constant MAX_TIME_BUFFER = 1 days;

    /// @notice The Registrar Controller that the auction uses to mint the names
    BaseRegistrar public immutable base;

    BeraDefaultResolver public immutable resolver;

    /// @notice The address of the honey contract
    IERC20 public immutable honey;

    /// @notice The address of the WETH contract
    IWETH public immutable weth;

    /// @notice The auctionDuration of a single auction
    uint256 public immutable auctionDuration;
    uint256 public immutable registrationDuration;

    /// @notice The minimum price accepted in an auction
    uint192 public reservePrice;

    /// @notice The minimum amount of time left in an auction after a new bid is created
    uint56 public timeBuffer;

    /// @notice The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    /// @notice The active auction
    IBeraAuctionHouse.Auction public auctionStorage;

    /// @notice Past auction settlements
    mapping(uint256 => SettlementState) settlementHistory;

    constructor(
        BaseRegistrar base_,
        BeraDefaultResolver resolver_,
        IERC20 honey_,
        IWETH weth_,
        uint256 auctionDuration_,
        uint256 registrationDuration_,
        uint192 reservePrice_,
        uint56 timeBuffer_,
        uint8 minBidIncrementPercentage_
    ) Ownable(msg.sender) {
        base = base_;
        resolver = resolver_;

        honey = honey_;
        weth = weth_;

        auctionDuration = auctionDuration_;
        registrationDuration = registrationDuration_;

        _pause();

        reservePrice = reservePrice_;
        timeBuffer = timeBuffer_;
        minBidIncrementPercentage = minBidIncrementPercentage_;
    }

    /**
     * @notice Settle the current auction, mint a new name, and put it up for auction.
     */
    function settleCurrentAndCreateNewAuction(string memory label_) external override whenNotPaused {
        _settleAuction();
        _createAuction(label_);
    }

    /**
     * @notice Settle the current auction.
     * @dev This function can only be called when the contract is paused.
     */
    function settleAuction() external override whenPaused {
        _settleAuction();
    }

    /**
     * @notice Create a bid for a token, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */
    function createBid(uint256 tokenId) external payable override {
        IBeraAuctionHouse.Auction memory _auction = auctionStorage;

        (uint192 _reservePrice, uint56 _timeBuffer, uint8 _minBidIncrementPercentage) =
            (reservePrice, timeBuffer, minBidIncrementPercentage);

        require(_auction.tokenId == tokenId, "tokenId not up for auction");
        require(block.timestamp < _auction.endTime, "Auction expired");
        require(msg.value >= _reservePrice, "Must send at least reservePrice");
        require(
            msg.value >= _auction.amount + ((_auction.amount * _minBidIncrementPercentage) / 100),
            "Must send more than last bid by minBidIncrementPercentage amount"
        );

        auctionStorage.amount = uint128(msg.value);
        auctionStorage.bidder = payable(msg.sender);

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < _timeBuffer;

        emit AuctionBid(_auction.tokenId, msg.sender, msg.value, extended);

        if (extended) {
            auctionStorage.endTime = _auction.endTime = uint40(block.timestamp + _timeBuffer);
            emit AuctionExtended(_auction.tokenId, _auction.endTime);
        }

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
        }
    }

    /**
     * @notice Get the current auction.
     */
    function auction() external view returns (AuctionView memory) {
        return AuctionView({
            tokenId: auctionStorage.tokenId,
            amount: auctionStorage.amount,
            startTime: auctionStorage.startTime,
            endTime: auctionStorage.endTime,
            bidder: auctionStorage.bidder,
            settled: auctionStorage.settled
        });
    }

    /**
     * @notice Pause the auction house.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the auction house.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause(string memory label_) external override onlyOwner {
        _unpause();

        if (auctionStorage.startTime == 0 || auctionStorage.settled) {
            _createAuction(label_);
        }
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(uint56 _timeBuffer) external override onlyOwner {
        require(_timeBuffer <= MAX_TIME_BUFFER, "timeBuffer too large");

        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(uint192 _reservePrice) external override onlyOwner {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the owner.
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage) external override onlyOwner {
        require(_minBidIncrementPercentage > 0, "must be greater than zero");

        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the mint reverts, the minter was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
    function _createAuction(string memory label_) internal {
        try base.registerWithRecord(
            uint256(keccak256(abi.encodePacked(label_))), address(this), registrationDuration, address(resolver), 0
        ) returns (uint256 tokenId, uint256) {
            uint40 startTime = uint40(block.timestamp);
            uint40 endTime = startTime + uint40(auctionDuration);

            auctionStorage = Auction({
                tokenId: uint96(tokenId),
                amount: 0,
                startTime: startTime,
                endTime: endTime,
                bidder: payable(0),
                settled: false
            });

            emit AuctionCreated(tokenId, startTime, endTime);
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the tokenId is burned.
     */
    function _settleAuction() internal {
        IBeraAuctionHouse.Auction memory _auction = auctionStorage;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(block.timestamp >= _auction.endTime, "Auction hasn't completed");

        auctionStorage.settled = true;

        if (_auction.bidder == address(0)) {
            base.transferFrom(address(this), address(0xdead), _auction.tokenId);
        } else {
            base.transferFrom(address(this), _auction.bidder, _auction.tokenId);
        }

        if (_auction.amount > 0) {
            _safeTransferETHWithFallback(owner(), _auction.amount);
        }

        SettlementState storage settlementState = settlementHistory[_auction.tokenId];
        settlementState.blockTimestamp = uint32(block.timestamp);
        settlementState.amount = ethPriceToUint64(_auction.amount);
        settlementState.winner = _auction.bidder;

        emit AuctionSettled(_auction.tokenId, _auction.bidder, _auction.amount);
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            weth.deposit{value: amount}();
            weth.transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        bool success;
        assembly {
            success := call(30000, to, value, 0, 0, 0, 0)
        }
        return success;
    }

    /**
     * @notice Get past auction settlements.
     * @dev Returns up to `auctionCount` settlements in reverse order, meaning settlements[0] will be the most recent auction price.
     * Includes auctions with no bids (blockTimestamp will be > 1)
     * @param auctionCount The number of price observations to get.
     * @return settlements An array of type `Settlement`, where each Settlement includes a timestamp,
     * the tokenId of that auction, the winning bid amount, and the winner's address.
     */
    function getSettlements(uint256 auctionCount) external view returns (Settlement[] memory settlements) {
        uint256 latestTokenId = auctionStorage.tokenId;
        if (!auctionStorage.settled && latestTokenId > 0) {
            latestTokenId -= 1;
        }

        settlements = new Settlement[](auctionCount);
        uint256 actualCount = 0;

        SettlementState memory settlementState;
        for (uint256 id = latestTokenId; actualCount < auctionCount; --id) {
            settlementState = settlementHistory[id];

            settlements[actualCount] = Settlement({
                blockTimestamp: settlementState.blockTimestamp,
                amount: uint64PriceToUint256(settlementState.amount),
                winner: settlementState.winner,
                tokenId: id
            });
            ++actualCount;

            if (id == 0) break;
        }

        if (auctionCount > actualCount) {
            // this assembly trims the observations array, getting rid of unused cells
            assembly {
                mstore(settlements, actualCount)
            }
        }
    }

    /**
     * @notice Get past auction prices.
     * @dev Returns prices in reverse order, meaning prices[0] will be the most recent auction price.
     * Skips auctions where there was no winner, i.e. no bids.
     * Reverts if getting a empty data for an auction that happened, e.g. historic data not filled
     * Reverts if there's not enough auction data, i.e. reached token id 0
     * @param auctionCount The number of price observations to get.
     * @return prices An array of uint256 prices.
     */
    function getPrices(uint256 auctionCount) external view returns (uint256[] memory prices) {
        uint256 latestTokenId = auctionStorage.tokenId;
        if (!auctionStorage.settled && latestTokenId > 0) {
            latestTokenId -= 1;
        }

        prices = new uint256[](auctionCount);
        uint256 actualCount = 0;

        SettlementState memory settlementState;
        for (uint256 id = latestTokenId; id > 0 && actualCount < auctionCount; --id) {
            settlementState = settlementHistory[id];
            require(settlementState.blockTimestamp > 1, "Missing data");
            if (settlementState.winner == address(0)) continue; // Skip auctions with no bids

            prices[actualCount] = uint64PriceToUint256(settlementState.amount);
            ++actualCount;
        }

        require(auctionCount == actualCount, "Not enough history");
    }

    /**
     * @notice Get all past auction settlements starting at `startId` and settled before or at `endTimestamp`.
     * @param startId the first tokenId to get prices for.
     * @param endTimestamp the latest timestamp for auctions
     * @return settlements An array of type `Settlement`, where each Settlement includes a timestamp,
     * the tokenId of that auction, the winning bid amount, and the winner's address.
     */
    function getSettlementsFromIdtoTimestamp(uint256 startId, uint256 endTimestamp)
        public
        view
        returns (Settlement[] memory settlements)
    {
        uint256 maxId = auctionStorage.tokenId;
        require(startId <= maxId, "startId too large");
        settlements = new Settlement[](maxId - startId + 1);
        uint256 actualCount = 0;
        SettlementState memory settlementState;
        for (uint256 id = startId; id <= maxId; ++id) {
            settlementState = settlementHistory[id];

            // don't include the currently auctioned token if it hasn't settled
            if ((id == maxId) && (settlementState.blockTimestamp <= 1)) {
                continue;
            }

            if (settlementState.blockTimestamp > endTimestamp) break;

            settlements[actualCount] = Settlement({
                blockTimestamp: settlementState.blockTimestamp,
                amount: uint64PriceToUint256(settlementState.amount),
                winner: settlementState.winner,
                tokenId: id
            });
            ++actualCount;
        }

        if (settlements.length > actualCount) {
            // this assembly trims the settlements array, getting rid of unused cells
            assembly {
                mstore(settlements, actualCount)
            }
        }
    }

    /**
     * @notice Get a range of past auction settlements.
     * @dev Returns prices in chronological order, as opposed to `getSettlements(count)` which returns prices in reverse order.
     * Includes auctions with no bids (blockTimestamp will be > 1)
     * @param startId the first tokenId to get prices for.
     * @param endId end tokenId (up to, but not including).
     * @return settlements An array of type `Settlement`, where each Settlement includes a timestamp,
     * the tokenId of that auction, the winning bid amount, and the winner's address.
     */
    function getSettlements(uint256 startId, uint256 endId) external view returns (Settlement[] memory settlements) {
        settlements = new Settlement[](endId - startId);
        uint256 actualCount = 0;

        SettlementState memory settlementState;
        for (uint256 id = startId; id < endId; ++id) {
            settlementState = settlementHistory[id];

            settlements[actualCount] = Settlement({
                blockTimestamp: settlementState.blockTimestamp,
                amount: uint64PriceToUint256(settlementState.amount),
                winner: settlementState.winner,
                tokenId: id
            });
            ++actualCount;
        }

        if (settlements.length > actualCount) {
            // this assembly trims the settlements array, getting rid of unused cells
            assembly {
                mstore(settlements, actualCount)
            }
        }
    }

    /**
     * @dev Convert an ETH price of 256 bits with 18 decimals, to 64 bits with 10 decimals.
     * Max supported value is 1844674407.3709551615 ETH.
     *
     */
    function ethPriceToUint64(uint256 ethPrice) internal pure returns (uint64) {
        return uint64(ethPrice / 1e8);
    }

    /**
     * @dev Convert a 64 bit 10 decimal price to a 256 bit 18 decimal price.
     */
    function uint64PriceToUint256(uint64 price) internal pure returns (uint256) {
        return uint256(price) * 1e8;
    }
}