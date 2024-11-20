// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAuction {
    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 minBidIncrement;
        address highestBidder;
        uint256 highestBid;
        uint256 startTime;
        uint256 endTime;
        bool ended;
        bool claimed;
    }

    error InvalidStartPrice();
    error InvalidDuration();
    error NotNFTOwner();
    error AuctionNotFound();
    error AuctionEndedError();
    error BidTooLow();
    error NotSeller();
    error AuctionHasBids();
    error AuctionNotEnded();
    error EthTransferFailed();
    error AuctionAlreadyEnded();

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 startTime,
        uint256 endTime
    );

    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed highestBidder, uint256 highestBid);
    event AuctionCancelled(uint256 indexed auctionId);

    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 minBidIncrement,
        uint256 startTime,
        uint256 duration
    ) external returns (uint256);

    function placeBid(uint256 auctionId) external payable;

    function endAuction(uint256 auctionId) external;

    function cancelAuction(uint256 auctionId) external;
}
