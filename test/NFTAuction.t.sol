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
}
