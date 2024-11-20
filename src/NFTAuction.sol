// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IAuction} from "./interfaces/IAuction.sol";

contract NFTAuction is IAuction {
    mapping(uint256 => Auction) public auctions;
    uint256 public auctionIdCounter;

    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _minBidIncrement,
        uint256 _startTime,
        uint256 _duration
    ) public returns (uint256) {
        if (_startPrice == 0) revert InvalidStartPrice();
        if (_duration == 0) revert InvalidDuration();

        IERC721 nft = IERC721(_nftContract);

        if (nft.ownerOf(_tokenId) != msg.sender) revert NotNFTOwner();

        uint256 auctionId = auctionIdCounter++;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            startPrice: _startPrice,
            minBidIncrement: _minBidIncrement,
            highestBidder: address(0),
            startTime: _startTime,
            highestBid: 0,
            endTime: _startTime + _duration,
            ended: false,
            claimed: false
        });

        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
        emit AuctionCreated(
            auctionId, msg.sender, _nftContract, _tokenId, _startTime, _startTime, _startTime + _duration
        );

        return auctionId;
    }

    function placeBid(uint256 _auctionId) public payable {
        Auction storage auction = auctions[_auctionId];

        if (auction.seller == address(0)) revert AuctionNotFound();
        if (auction.ended) revert AuctionEndedError();
        if (msg.value <= auction.highestBid) revert BidTooLow();

        address previousBidder = auction.highestBidder;
        uint256 previousBid = auction.highestBid;

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        emit BidPlaced(_auctionId, msg.sender, msg.value);

        if (previousBidder != address(0)) {
            (bool sent,) = previousBidder.call{value: previousBid}("");
            if (!sent) revert EthTransferFailed();
        }
    }

    function endAuction(uint256 auctionId) external {
        // add nonReentrant
        Auction storage auction = auctions[auctionId];

        if (auction.seller == address(0)) revert AuctionNotFound();
        if (block.timestamp <= auction.endTime) revert AuctionNotEnded();
        if (auction.ended && auction.claimed) revert AuctionAlreadyEnded();

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            IERC721(auction.nftContract).transferFrom(address(this), auction.highestBidder, auction.tokenId);

            (bool sent,) = auction.seller.call{value: auction.highestBid}("");
            if (!sent) revert EthTransferFailed();
        } else {
            IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
        }

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
    }

    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        if (auction.ended) revert AuctionEndedError();
        if (msg.sender != auction.seller) revert NotSeller();
        if (auction.highestBidder != address(0)) revert AuctionHasBids(); // cannot cancel auction with bids

        auction.ended = true;

        IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);

        emit AuctionCancelled(auctionId);
    }
}
