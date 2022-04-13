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
    uint256 public constant BASE_SUPER_PERCENTAGE = 5;
    uint256 public constant UPGRADE_SALES_OFFSET = 2 days;

    uint256 public baseSupply;
    uint256 public presaleSupply;
    uint256 public upgradeSupply;
    uint256 public presaleStartTime;
    uint256 public salesStartTime;

    mapping(uint256 => uint256) private tokenLevel;
    mapping(uint256 => uint256) public baseTokenMintBlock;
    Level[] public levels;

    string public constant BASE_URI = "unknown";

    constructor() ERC721("Diamond Miner", "DIAMOND-MINER") {
        // supply and price are ignored for the base levels of miners and super miners
        levels.push(Level({ supply: 0, maxSupply: 0, price: 0, yield: 1 }));
        levels.push(Level({ supply: 0, maxSupply: 0, price: 0, yield: 25 }));
    }

    /* Minting of base miners */

    function mintBase(uint16 _numTokens) external payable {
        require(msg.value == _numTokens * BASE_MINT_PRICE, "Incorrect amount sent");
        require(baseSalesOpen(), "The main sale period is not open");

        _mintBaseTokens(_numTokens, _msgSender());
    }

    function presaleMintBase(uint16 _numTokens) external payable {
        require(msg.value == _numTokens * PRESALE_MINT_PRICE, "Incorrect amount sent");
        require(presaleOpen(), "The presale is not open");
        require(presaleSupply + _numTokens <= MAX_PRESALE_SUPPLY, "Insufficient presale supply");

        _mintBaseTokens(_numTokens, _msgSender());
        presaleSupply += _numTokens;
    }

    function reserveBase(uint16 _numTokens, address _for) external onlyOwner {
        _mintBaseTokens(_numTokens, _for);
    }

    function setSalesStartTime(uint256 _startTime) external onlyOwner {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(!baseSalesOpen(), "Base sales already started");

        salesStartTime = _startTime;
    }

    function setPresaleStartTime(uint256 _startTime) external onlyOwner {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(!baseSalesOpen(), "Base sales already started");
        require(!presaleOpen(), "Presale already started");

        presaleStartTime = _startTime;
    }

    function baseSalesOpen() public view returns (bool) {
        return salesStartTime != 0 && block.timestamp >= salesStartTime;
    }

    function presaleOpen() public view returns (bool) {
        return presaleStartTime != 0 && block.timestamp >= presaleStartTime;
    }

    function _mintBaseTokens(uint16 _numTokens, address _for) internal {
        require(baseSupply + _numTokens <= MAX_BASE_SUPPLY, "Insufficient supply");
        require(_numTokens <= MAX_PER_MINT, "Too many purchases at once");

        for (uint i = 0; i < _numTokens; i++) {
            uint256 tokenId = baseSupply;
            _safeMint(_for, tokenId);
            baseSupply++;
            baseTokenMintBlock[tokenId] = block.number;

            if (_rand(totalSupply()) % 100 < BASE_SUPER_PERCENTAGE) {
                tokenLevel[tokenId] = 1; // super miner
            } else {
                tokenLevel[tokenId] = 0; // normal miner
            }
        }
    }

    /* Minting of upgrade miners */

    function addUpgrade(uint256 _maxSupply, uint256 _price, uint256 _yield) external onlyOwner {
        levels.push(Level({ supply: 0, maxSupply: _maxSupply, price: _price, yield: _yield }));
    }

    function mintUpgrade(uint256 _level, uint16 _numTokens) external {
        require(gameStarted(), "Upgrade sales are not open");
        require(_numTokens <= MAX_PER_MINT, "Too many purchases at once");
        require(_level < levels.length && _level > 1, "Invalid level");
        require(levels[_level].supply + _numTokens <= levels[_level].maxSupply, "Insufficient supply");

        uint256 totalCost = _numTokens * levels[_level].price;
        require(diamond.balanceOf(msg.sender) >= totalCost, "Insufficient DIAMOND balance");
        diamond.burn(msg.sender, totalCost);

        for (uint256 i = 0; i < _numTokens; i++) {
            uint256 tokenId = MAX_BASE_SUPPLY + upgradeSupply;
            _safeMint(msg.sender, tokenId);
            tokenLevel[tokenId] = _level;
            levels[_level].supply++;
            upgradeSupply++;
        }
    }

    //  Views

    function gameStarted() public view returns (bool) {
        return baseSalesOpen() && (
            block.timestamp >= salesStartTime + UPGRADE_SALES_OFFSET || baseSupply == MAX_BASE_SUPPLY
        );
    }

    function isUpgrade(uint256 _tokenId) public view returns (bool) {
        require(_exists(_tokenId), "Invalid token ID");

        return _tokenId >= MAX_BASE_SUPPLY;
    }

    function tokenRevealed(uint256 _tokenId) public view returns (bool) {
        return isUpgrade(_tokenId) || baseTokenMintBlock[_tokenId] < block.number - 1;
    }

    function revealedTokenLevel(uint256 _tokenId) public view returns (uint256) {
        require(tokenRevealed(_tokenId), "Token unrevealed");

        return tokenLevel[_tokenId];
    }

    function tokenYield(uint256 _tokenId) public view returns (uint256) {
        uint256 level = revealedTokenLevel(_tokenId);
        return levels[level].yield;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (isUpgrade(_tokenId)) {
            return string(abi.encodePacked(BASE_URI, "level/", revealedTokenLevel(_tokenId).toString(), ".json"));
        } else if (!tokenRevealed(_tokenId)) {
            return string(abi.encodePacked(BASE_URI, "base/unrevealed.json"));
        } else if (revealedTokenLevel(_tokenId) == 1) {
            return string(abi.encodePacked(BASE_URI, "base/", _tokenId.toString(), "-super.json"));
        } else {
            return string(abi.encodePacked(BASE_URI, "base/", _tokenId.toString(), "-miner.json"));
        }
    }

    function contractURI() public pure returns (string memory) {
        return string(abi.encodePacked(BASE_URI, "contract-meta.json"));
    }

    function batchedMinerOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (MinerInfo[] memory) {
        if (_offset >= balanceOf(_owner)) {
            return new MinerInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= balanceOf(_owner)) {
            outputSize = balanceOf(_owner) - _offset;
        }
        MinerInfo[] memory miners = new MinerInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, _offset + i);
            bool revealed = tokenRevealed(tokenId);
            uint256 level = 0;
            if (revealed) {
                level = revealedTokenLevel(tokenId);
            }

            miners[i] = MinerInfo({
                tokenId: tokenId,
                level: level,
                revealed: revealed
            });
        }

        return miners;
    }

    //  Extras

    function isApprovedForAll(address _owner, address _operator) public view override returns (bool) {
        if (_operator == mineAddress) {
            return true;
        }

        return super.isApprovedForAll(_owner, _operator);
    }

    function setMineAddress(address _mineAddress) external onlyOwner {
        require(mineAddress == address(0), "Mine address already set");
        mineAddress = _mineAddress;
    }

    function setDiamond(Diamond _diamond) external onlyOwner {
        diamond = _diamond;
    }

    function withdrawBalance(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance);
        payable(msg.sender).transfer(_amount);
    }

    // Adapted from Sheep Game
    function _rand(uint256 _seed) internal view returns (uint256) {
        require(tx.origin == _msgSender(), "Only EOA");

        return uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 4),
                    tx.origin,
                    blockhash(block.number - 2),
                    blockhash(block.number - 3),
                    blockhash(block.number - 1),
                    _seed,
                    block.timestamp
                )
            )
        );
    }
}
