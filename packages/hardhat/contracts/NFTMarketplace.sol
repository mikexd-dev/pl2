// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace is ERC721Holder {
    using SafeMath for uint256;

    struct Listing {
        address owner;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    address payable private owner;
    uint256 private feePercentage;
    uint256 private totalSales;
    mapping(uint256 => Listing) private listings;

    event ListingCreated(address indexed seller, uint256 indexed tokenId);
    event ListingPriceUpdated(uint256 indexed tokenId, uint256 price);
    event ListingRemoved(uint256 indexed tokenId);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor() {
        owner = payable(msg.sender);
        feePercentage = 1; // 1% fee initially
        totalSales = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function setFeePercentage(uint256 percentage) external onlyOwner {
        require(percentage <= 10, "Percentage should be between 0 and 10");
        feePercentage = percentage;
    }

    function createListing(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Caller must own the NFT");

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({
            owner: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        emit ListingCreated(msg.sender, tokenId);
    }

    function updateListingPrice(uint256 tokenId, uint256 price) external {
        require(listings[tokenId].owner == msg.sender, "Only owner can update listing price");
        require(price > 0, "Price must be greater than zero");

        listings[tokenId].price = price;

        emit ListingPriceUpdated(tokenId, price);
    }

    function removeListing(uint256 tokenId) external {
        require(listings[tokenId].owner == msg.sender, "Only owner can remove listing");

        IERC721 nft = IERC721(listings[tokenId].nftContract);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        delete listings[tokenId];

        emit ListingRemoved(tokenId);
    }

    function buyNFT(uint256 tokenId) external payable {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Listing is not active");
        require(msg.value >= listing.price, "Insufficient payment");

        address payable seller = payable(listing.owner);
        uint256 feeAmount = (listing.price.mul(feePercentage)).div(100);
        uint256 remainingBalance = listing.price.sub(feeAmount);

        (bool success, ) = seller.call{value: remainingBalance}("");
        require(success, "Transfer to seller failed");

        (success, ) = owner.call{value: feeAmount}("");
        require(success, "Transfer of fee to owner failed");

        IERC721 nft = IERC721(listing.nftContract);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        listing.active = false;

        totalSales = totalSales.add(1);

        emit NFTSold(seller, msg.sender, tokenId, listing.price);
    }

    function getListing(uint256 tokenId) external view returns (Listing memory) {
        return listings[tokenId];
    }

    function getFeePercentage() external view returns (uint256) {
        return feePercentage;
    }

    function getTotalSales() external view returns (uint256) {
        return totalSales;
    }
}