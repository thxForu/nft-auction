// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAuction {
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

    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 minBidIncrement,
        uint256 startTime,
        uint256 duration
    ) external returns (uint256);
}
