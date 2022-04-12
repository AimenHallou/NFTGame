//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./Diamond.sol";


contract Miner is ERC721Enumerable, Ownable, Pausable {
   using Strings for uint256;

    struct Level {
        uint256 supply;
        uint256 maxSupply;
        uint256 price;
        uint256 yield;
    }

    struct MinerInfo {
        uint256 tokenId;
        uint256 level;
        bool revealed;
    }

    Diamond public diamond;
    address public mineAddress;

    uint256 public constant MAX_PER_MINT = 30;
    uint256 public constant MAX_BASE_SUPPLY = 10000;
    uint256 public constant MAX_PRESALE_SUPPLY = 500;
    uint256 public constant BASE_MINT_PRICE = 1.5 ether; // 1.5 AVAX
    uint256 public constant PRESALE_MINT_PRICE = 1.25 ether; // 1.25 AVAX
    uint256 public constant BASE_ROBOT_PERCENTAGE = 5;
    uint256 public constant UPGRADE_SALES_OFFSET = 2 days;

    uint256 public baseSupply;
    uint256 public presaleSupply;
    uint256 public upgradeSupply;
    uint256 public presaleStartTime;
    uint256 public salesStartTime;

}
