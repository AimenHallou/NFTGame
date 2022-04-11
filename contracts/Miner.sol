//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract Miner is ERC721Enumerable, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    struct MinerInfo{
        uint256 tokenId;
        uint256 minerType;
    }

    uint256 public constant MINER_PRICE_AVAX = 1.5 ether;
    uint256 public constant WHITELIST_MINER = 1000;
    uint256 public constant MAXIMUM_MINTS_PER_WHITELIST_ADDRESS = 10;



}
