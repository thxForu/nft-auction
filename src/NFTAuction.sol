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
        require(_startPrice > 0); // use error type
        require(_duration > 0); // use  error type

        IERC721 nft = IERC721(_nftContract);

        require(nft.ownerOf(_tokenId) == msg.sender);

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

        require(auction.seller != address(0)); // use error type
        require(!auction.ended); // use  error type
        require(msg.value > auction.highestBid); // use  error type

        address previousBidder = auction.highestBidder;
        uint256 previousBid = auction.highestBid;

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        emit BidPlaced(_auctionId, msg.sender, msg.value);

        if (previousBidder != address(0)) {
            (bool sent,) = previousBidder.call{value: previousBid}("");
            require(sent, "Failed to send Ether");
        }
    }

    function endAuction(uint256 auctionId) external {
        // add nonReentrant
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0));
        require(block.timestamp > auction.endTime);
        require(!auction.ended || !auction.claimed);

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            IERC721(auction.nftContract).transferFrom(address(this), auction.highestBidder, auction.tokenId);

            (bool sent,) = auction.seller.call{value: auction.highestBid}("");
            require(sent, "Failed to send Ether");
        } else {
            IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
        }

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
    }

    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(!auction.ended);
        require(msg.sender == auction.seller);
        require(auction.highestBidder != address(0)); // cannot cancel auction with bids

        auction.ended = true;

        IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);

        emit AuctionCancelled(auctionId);
    }
}
