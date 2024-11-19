// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTAuction {
    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 minBidIncrement;
        address hiestBidder;
        uint256 startTime;
        uint256 endTime;
        bool ended;
        bool claimed;
    }

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 startTime,
        uint256 endTime
    );

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
            hiestBidder: msg.sender,
            startTime: _startTime,
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
}