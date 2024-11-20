// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {NFTAuction} from "../src/NFTAuction.sol";
import {MockNFT} from "../src/mockNFT.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTAuctionTest is Test {
    NFTAuction public auction;
    MockNFT public mockNFT;
    address public seller;
    uint256 public tokenId;

    function setUp() public {
        auction = new NFTAuction();
        mockNFT = new MockNFT();
        seller = makeAddr("seller");

        // Mint NFT to seller
        vm.startPrank(seller);
        tokenId = mockNFT.mint(seller);
        mockNFT.approve(address(auction), tokenId);
        vm.stopPrank();
    }

    function test_CreateAuction() public {
        uint256 startPrice = 1 ether;
        uint256 minBidIncrement = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        vm.startPrank(seller);
        uint256 auctionId =
            auction.createAuction(address(mockNFT), tokenId, startPrice, minBidIncrement, startTime, duration);
        vm.stopPrank();

        (
            address _seller,
            address _nftContract,
            uint256 _tokenId,
            uint256 _startPrice,
            uint256 _minBidIncrement,
            address _highestBidder,
            uint256 _highestBid,
            uint256 _startTime,
            uint256 _endTime,
            bool _ended,
            bool _claimed
        ) = auction.auctions(auctionId);

        assertEq(_seller, seller);
        assertEq(_nftContract, address(mockNFT));
        assertEq(_tokenId, tokenId);
        assertEq(_startPrice, startPrice);
        assertEq(_minBidIncrement, minBidIncrement);
        assertEq(_startTime, startTime);
        assertEq(_endTime, startTime + duration);
        assertEq(_ended, false);
        assertEq(_claimed, false);

        assertEq(mockNFT.ownerOf(tokenId), address(auction));
    }

    function testFail_CreateAuctionNotOwner() public {
        address notOwner = makeAddr("notOwner");
        uint256 startPrice = 1 ether;
        uint256 minBidIncrement = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        vm.prank(notOwner);
        auction.createAuction(address(mockNFT), tokenId, startPrice, minBidIncrement, startTime, duration);
    }

    function testFail_CreateAuctionZeroPrice() public {
        uint256 startPrice = 0;
        uint256 minBidIncrement = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        vm.prank(seller);
        auction.createAuction(address(mockNFT), tokenId, startPrice, minBidIncrement, startTime, duration);
    }

    // place bid
    function test_PlaceBid() public {
        uint256 startPrice = 1 ether;
        uint256 minBidIncrement = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        vm.prank(seller);
        uint256 auctionId =
            auction.createAuction(address(mockNFT), tokenId, startPrice, minBidIncrement, startTime, duration);

        address bidder = makeAddr("bidder");
        vm.deal(bidder, 2 ether);

        vm.prank(bidder);
        auction.placeBid{value: 1.5 ether}(auctionId);

        (,,,,, address highestBidder, uint256 highestBid,,,,) = auction.auctions(auctionId);
        assertEq(highestBidder, bidder);
        assertEq(highestBid, 1.5 ether);
    }

    function test_PlaceBidReturnsPreviousBid() public {
        uint256 startPrice = 1 ether;
        uint256 minBidIncrement = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        vm.prank(seller);
        uint256 auctionId =
            auction.createAuction(address(mockNFT), tokenId, startPrice, minBidIncrement, startTime, duration);

        address bidder = makeAddr("bidder");
        vm.deal(bidder, 2 ether);

        vm.prank(bidder);
        auction.placeBid{value: 1.5 ether}(auctionId);

        address secondBidder = makeAddr("secondBidder");
        vm.deal(secondBidder, 3 ether);

        uint256 firstBidderBalanceBefore = bidder.balance;

        vm.prank(secondBidder);
        auction.placeBid{value: 2 ether}(auctionId);

        // first bidder got refund
        assertEq(bidder.balance, firstBidderBalanceBefore + 1.5 ether);

        (,,,,, address highestBidder, uint256 highestBid,,,,) = auction.auctions(auctionId);
        assertEq(highestBidder, secondBidder);
        assertEq(highestBid, 2 ether);
    }

    function testFail_AuctionNotExists() public {
        address bidder = makeAddr("bidder");
        vm.deal(bidder, 1 ether);

        vm.prank(bidder);
        // non-existent auction id
        auction.placeBid{value: 1 ether}(999);
    }

    // end auction
    function test_EndAuction() public {
        uint256 auctionId = createTestAuction();

        address bidder = makeAddr("bidder");
        vm.deal(bidder, 2 ether);
        vm.prank(bidder);
        auction.placeBid{value: 1.5 ether}(auctionId);

        vm.warp(block.timestamp + 1 days + 1);

        uint256 sellerBalanceBefore = seller.balance;

        auction.endAuction(auctionId);

        assertEq(mockNFT.ownerOf(tokenId), bidder);

        // seller got paid
        assertEq(seller.balance, sellerBalanceBefore + 1.5 ether);

        (,,,,,,,,, bool ended,) = auction.auctions(auctionId);
        assertTrue(ended);
    }

    function test_EndAuctionWithNoBids() public {
        uint256 auctionId = createTestAuction();
        vm.warp(block.timestamp + 1 days + 1);

        auction.endAuction(auctionId);

        // NFT should return to seller
        assertEq(mockNFT.ownerOf(tokenId), seller);

        (,,,,,,,,, bool ended,) = auction.auctions(auctionId);
        assertTrue(ended);
    }

    function testFail_EndAuctionTooEarly() public {
        uint256 auctionId = createTestAuction();
        auction.endAuction(auctionId);
    }

    function testFail_EndNonExistentAuction() public {
        auction.endAuction(999);
    }

    function test_CancelAuction() public {
        uint256 auctionId = createTestAuction();

        vm.prank(seller);
        auction.cancelAuction(auctionId);

        // NFT should return to seller
        assertEq(mockNFT.ownerOf(tokenId), seller);

        (,,,,,,,,, bool ended,) = auction.auctions(auctionId);
        assertTrue(ended);
    }

    function testFail_CancelAuctionWithBids() public {
        uint256 auctionId = createTestAuction();

        address bidder = makeAddr("bidder");
        vm.deal(bidder, 2 ether);
        vm.prank(bidder);
        auction.placeBid{value: 1.5 ether}(auctionId);

        // try cancel auction with bids
        vm.prank(seller);
        auction.cancelAuction(auctionId);
    }

    function testFail_CancelAuctionNotSeller() public {
        uint256 auctionId = createTestAuction();

        address notSeller = makeAddr("notSeller");
        vm.prank(notSeller);
        auction.cancelAuction(auctionId);
    }

    function testFail_CancelEndedAuction() public {
        uint256 auctionId = createTestAuction();

        vm.warp(block.timestamp + 1 days + 1);
        auction.endAuction(auctionId);

        // try to cancel ended auction
        vm.prank(seller);
        auction.cancelAuction(auctionId);
    }

    function createTestAuction() internal returns (uint256) {
        vm.prank(seller);
        return auction.createAuction(address(mockNFT), tokenId, 1 ether, 0.1 ether, block.timestamp, 1 days);
    }
}
