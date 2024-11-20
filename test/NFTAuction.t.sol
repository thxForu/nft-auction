// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {NFTAuction} from "../src/NFTAuction.sol";
import {IAuction} from "../src/interfaces/IAuction.sol";
import {MockNFT} from "../src/mockNFT.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTAuctionTest is Test {
    NFTAuction public auction;
    MockNFT public mockNFT;
    address public seller;
    uint256 public tokenId;

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
        uint256 auctionId = createTestAuction();
        vm.stopPrank();

        (
            address _seller,
            address _nftContract,
            uint256 _tokenId,
            uint256 _startPrice,
            uint256 _minBidIncrement,
            ,
            ,
            uint256 _startTime,
            uint256 _endTime,
            bool _ended,
            bool _claimed
        ) = auction.auctions(auctionId);

        assertEq(_seller, seller);
        assertEq(_nftContract, address(mockNFT));
        assertEq(_tokenId, tokenId);
        assertEq(_startPrice, 1 ether);
        assertEq(_minBidIncrement, 0.1 ether);
        assertEq(_startTime, block.timestamp);
        assertEq(_endTime, block.timestamp + 1 days);
        assertEq(_ended, false);
        assertEq(_claimed, false);
        assertEq(mockNFT.ownerOf(tokenId), address(auction));
    }

    function test_CreateAuctionNotOwner() public {
        address notOwner = makeAddr("notOwner");
        uint256 startPrice = 1 ether;
        uint256 minBidIncrement = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        vm.prank(notOwner);
        vm.expectRevert(NotNFTOwner.selector);
        auction.createAuction(address(mockNFT), tokenId, startPrice, minBidIncrement, startTime, duration);
        vm.stopPrank();
    }

    function test_CreateAuctionZeroPrice() public {
        uint256 startPrice = 0;
        uint256 minBidIncrement = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 duration = 1 days;

        vm.prank(seller);
        vm.expectRevert(InvalidStartPrice.selector);
        auction.createAuction(address(mockNFT), tokenId, startPrice, minBidIncrement, startTime, duration);
        vm.stopPrank();
    }

    // place bid
    function test_PlaceBid() public {
        uint256 auctionId = createTestAuction();
        vm.stopPrank();

        address bidder = makeAddr("bidder");
        vm.deal(bidder, 2 ether);

        vm.prank(bidder);
        auction.placeBid{value: 1.5 ether}(auctionId);

        (,,,,, address highestBidder, uint256 highestBid,,,,) = auction.auctions(auctionId);
        assertEq(highestBidder, bidder);
        assertEq(highestBid, 1.5 ether);
    }

    function test_PlaceBidReturnsPreviousBid() public {
        uint256 auctionId = createTestAuction();
        vm.stopPrank();

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

    function test_AuctionNotExists() public {
        address bidder = makeAddr("bidder");
        vm.deal(bidder, 1 ether);

        vm.prank(bidder);
        vm.expectRevert(AuctionNotFound.selector);
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

    function test_EndAuctionTooEarly() public {
        uint256 auctionId = createTestAuction();

        vm.expectRevert(AuctionNotEnded.selector);
        auction.endAuction(auctionId);
    }

    function test_EndNonExistentAuction() public {
        vm.expectRevert(AuctionNotFound.selector);
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

    function test_CancelAuctionWithBids() public {
        uint256 auctionId = createTestAuction();

        address bidder = makeAddr("bidder");
        vm.deal(bidder, 2 ether);
        vm.prank(bidder);
        auction.placeBid{value: 1.5 ether}(auctionId);

        // try cancel auction with bids
        vm.prank(seller);
        vm.expectRevert(AuctionHasBids.selector);
        auction.cancelAuction(auctionId);
    }

    function test_CancelAuctionNotSeller() public {
        uint256 auctionId = createTestAuction();

        address notSeller = makeAddr("notSeller");
        vm.prank(notSeller);
        vm.expectRevert(NotSeller.selector);
        auction.cancelAuction(auctionId);
    }

    function test_CancelEndedAuction() public {
        uint256 auctionId = createTestAuction();

        vm.warp(block.timestamp + 1 days + 1);
        auction.endAuction(auctionId);

        // try to cancel ended auction
        vm.prank(seller);
        vm.expectRevert(AuctionEndedError.selector);
        auction.cancelAuction(auctionId);
    }

    function createTestAuction() internal returns (uint256) {
        vm.prank(seller);
        return auction.createAuction(address(mockNFT), tokenId, 1 ether, 0.1 ether, block.timestamp, 1 days);
    }
}
