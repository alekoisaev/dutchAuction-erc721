// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract dutchAuction is ERC721, Ownable {
    uint256 private DURATION;
    uint256 private DISCOUNT_INTERVAL;

    // maximum number of tokens ever gonna be minted on this contract
    uint16 public MAX_TOTAL_SUPPLY;

    uint256 public immutable startingPrice;
    uint256 public immutable discountRate;
    uint256 public immutable startAt;
    uint256 public immutable expiresAt;

    // for enumeration minted tokens count
    uint16 internal totalBid = 0;

    // bidder -> sent eth
    mapping(address => uint256) private userBids;

    // bidder's array
    address[] bidders;

    // last bidder sent price
    uint256 internal finishPrice;

    constructor(
        uint256 _duration,
        uint256 _discountInterval,
        uint256 _startingPrice,
        uint256 _discountRate,
        uint16 _maxTotalSupply,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        DURATION = _duration;
        DISCOUNT_INTERVAL = _discountInterval;
        startingPrice = _startingPrice;
        discountRate = _discountRate;
        MAX_TOTAL_SUPPLY = _maxTotalSupply;
        startAt = block.timestamp;
        expiresAt = block.timestamp + DURATION;
    }

    function getPrice() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startAt;
        uint256 discount = (timeElapsed / DISCOUNT_INTERVAL) * discountRate;
        return startingPrice - discount;
    }

    function bid() external payable {
        require(block.timestamp < expiresAt, "This auction has ended");
        require(totalBid < MAX_TOTAL_SUPPLY, "This auctions has ended");
        require(userBids[msg.sender] == 0, "Only one bid!");

        uint256 price = getPrice();
        require(
            msg.value >= price,
            "The amount of ETH sent is less than the price of token"
        );

        userBids[msg.sender] = msg.value;
        bidders.push(msg.sender);

        totalBid += 1;

        if (totalBid == MAX_TOTAL_SUPPLY - 1) {
            finishPrice = price;
        }
    }

    function mintnWithdraw() external {
        require(userBids[msg.sender] > 0, "You didn't bid");
        require(
            totalBid == MAX_TOTAL_SUPPLY || block.timestamp > expiresAt,
            "Auction is not ended yet"
        );

        uint256 refund;
        uint256 price;
        if (totalBid < MAX_TOTAL_SUPPLY) {
            price = (DURATION / DISCOUNT_INTERVAL) * discountRate;
            refund = userBids[msg.sender] - price;
        } else {
            price = finishPrice;
            refund = userBids[msg.sender] - price;
        }

        mintToken();
        payable(msg.sender).transfer(refund);
    }

    function mintToken() internal {
        for (uint256 i = 0; i < bidders.length; i++) {
            if (bidders[i] == msg.sender) {
                _safeMint(msg.sender, i + 1);
            }
        }
    }

    // ADMIN
    function shuffle() external onlyOwner {
        require(
            totalBid == MAX_TOTAL_SUPPLY || block.timestamp > expiresAt,
            "Auction is not ended yet"
        );

        for (uint256 i = 0; i < bidders.length; i++) {
            uint256 n = i +
                (uint256(keccak256(abi.encodePacked(block.timestamp))) %
                    (bidders.length - i));
            address temp = bidders[n];
            bidders[n] = bidders[i];
            bidders[i] = temp;
        }
    }

    function ownerWithdraw() external onlyOwner {
        uint256 price;
        uint256 sumFund;
        if (totalBid < MAX_TOTAL_SUPPLY) {
            price = (DURATION / DISCOUNT_INTERVAL) * discountRate;
        } else {
            price = finishPrice;
        }

        sumFund = totalBid * price;

        payable(owner()).transfer(sumFund);
    }
}
