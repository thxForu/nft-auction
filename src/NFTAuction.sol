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
        Auction memory auction = auctions[_auctionId];

        require(auction.seller != address(0)); // use error type
        require(!auction.ended); // use  error type
        require(msg.value > auction.highestBid); // use  error type

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }
}
