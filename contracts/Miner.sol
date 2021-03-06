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
    address public eventAddress;
    address public mineAddress;
    address[] public whiteListAddresses;

    uint256 public constant lockLV = 2;

    uint256 public constant MAX_PER_MINT = 30;
    uint256 public MAX_BASE_SUPPLY = 9500;
    uint256 public MAX_PRESALE_SUPPLY = 500;
    uint256 public constant BASE_MINT_PRICE = 2 ether;
    uint256 public constant PRESALE_MINT_PRICE = 1.5 ether; 
    uint256 public constant NFT_TAX = 0.1 ether; 
    uint256 public constant BASE_SUPER_PERCENTAGE = 5;
    uint256 public constant UPGRADE_SALES_OFFSET = 2 days;

    uint256 public baseSupply;
    uint256 public presaleSupply;
    uint256 public upgradeSupply;
    uint256 public presaleStartTime;
    uint256 public salesStartTime;

    bool public skipWL = false;



    mapping(uint256 => uint256) private tokenLevel;

    Level[] public levels;

    string  BASE_URI = "";

    bool revealed = false;

    constructor(
    string memory _initBaseURI,
    string memory _name,
    string memory _symbol
    ) ERC721(_name, _symbol) {
        // supply and price are ignored for the base levels of miners and super miners
        setBaseURI(_initBaseURI);
        levels.push(Level({ supply: 0, maxSupply: 0, price: 0, yield: 1 }));
        levels.push(Level({ supply: 0, maxSupply: 0, price: 0, yield: 5 }));
        //_mintBaseTokens(5, msg.sender);
    }

    /* Minting of base miners */

    function mintBase(uint16 _numTokens) external payable {
        if (msg.sender != owner()){
        require(msg.value >= _numTokens * BASE_MINT_PRICE + NFT_TAX, "Incorrect amount sent");
        }
        require(baseSalesOpen(), "The main sale period is not open");
        _mintBaseTokens(_numTokens, _msgSender());
    }

    function presaleMintBase(uint16 _numTokens) external payable {
        if (msg.sender != owner()){
        require(msg.value >= _numTokens * PRESALE_MINT_PRICE + NFT_TAX, "Incorrect amount sent");
        }
        require(presaleOpen(), "The presale is not open");
        require(presaleSupply + _numTokens <= MAX_PRESALE_SUPPLY, "Insufficient presale supply");
        if (!skipWL) {
        require(isWhiteListed(_msgSender()), "The sender is not whitelisted");
        }
        _mintBaseTokens(_numTokens, _msgSender());
        presaleSupply += _numTokens;
    }

    function setSalesStartTime(uint256 _startTime) external onlyOwner {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(!baseSalesOpen(), "Base sales already started");
        salesStartTime = _startTime;
    }

    function setMAX_BASE_SUPPLY(uint256 _value) external onlyOwner {
        MAX_BASE_SUPPLY = _value;
    }

    function setMAX_PRESALE_SUPPLY(uint256 _value) external onlyOwner {
        MAX_PRESALE_SUPPLY = _value;
    }

    function setPresaleStartTime(uint256 _startTime) external onlyOwner {
        require(_startTime > block.timestamp, "Start time must be in the future");
        require(!baseSalesOpen(), "Base sales already started");
        require(!presaleOpen(), "Presale already started");

        presaleStartTime = _startTime;
    }

    function getCurrentBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
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

            if (_rand(totalSupply()) % 100 < BASE_SUPER_PERCENTAGE) {
                tokenLevel[tokenId] = 1; // super miner
            } else {
                tokenLevel[tokenId] = 0; // normal miner
            }
        }
    }

    function whiteListUsers (address[] calldata _users) public onlyOwner{
        //delete whiteListAddresses;
        for (uint256 i = 0; i<_users.length; i++){
            whiteListAddresses.push(_users[i]);
        }
    }

    function giveFreeNFTs (address[] calldata _users) public onlyOwner {
        for (uint i = 0; i< _users.length; i++){
            _mintBaseTokens(1,_users[i]);
        }
    }

    function burnLock(uint256 _id) public{
        require(msg.sender == mineAddress, "Only the mine address can burn a lock");
        _burn(_id);
    }

    function isWhiteListed (address _user) public view returns (bool) {
        for(uint256 i=0; i<whiteListAddresses.length; i++){
            if(whiteListAddresses[i] == _user){
                return true;
            }
        }
        return false;
    }

    /* Minting of upgrade miners */

    function addUpgrade(uint256 _maxSupply, uint256 _price, uint256 _yield) external onlyOwner {
        levels.push(Level({ supply: 0, maxSupply: _maxSupply, price: _price, yield: _yield }));
    }

    function updateUpgradePrice(uint256 _level, uint256 _price) public{
        require(msg.sender == eventAddress || msg.sender == owner(), "Must be the owner or event address to set prices");
        levels[_level].price = _price;
    }

    function mintUpgrade(uint256 _level, uint16 _numTokens) external {
        require(gameStarted(), "Upgrade sales are not open");
        require(_numTokens <= MAX_PER_MINT, "Too many purchases at once");
        require(_level < levels.length && _level > 1, "Invalid level");
        require(levels[_level].supply + _numTokens <= levels[_level].maxSupply, "Insufficient supply");
        require(_level != lockLV, "Locks can only be minted through the event contract"); 

        uint256 totalCost = _numTokens * levels[_level].price;

        if (msg.sender != owner()){
            require(diamond.balanceOf(msg.sender) >= totalCost, "Insufficient DIAMOND balance");
            diamond.burn(msg.sender, totalCost);
        }
        for (uint256 i = 0; i < _numTokens; i++) {
            uint256 tokenId = MAX_BASE_SUPPLY + upgradeSupply;
            _safeMint(msg.sender, tokenId);
            tokenLevel[tokenId] = _level;
            levels[_level].supply++;
            upgradeSupply++;
        }
    }

    function mintLock(uint16 _numTokens, address _to) external {
        require(gameStarted(), "Upgrade sales are not open");
        require(_numTokens <= MAX_PER_MINT, "Too many purchases at once");
        require(lockLV < levels.length && lockLV > 1, "Invalid level");
        require(levels[lockLV].supply + _numTokens <= levels[lockLV].maxSupply, "Insufficient supply");
        require(msg.sender == eventAddress, "Locks can only be minted through the event contract"); 

        uint256 totalCost = _numTokens * levels[lockLV].price;

        if (msg.sender != owner()){
            require(diamond.balanceOf(_to) >= totalCost, "Insufficient DIAMOND balance");
            diamond.burn(_to, totalCost);
        }

        for (uint256 i = 0; i < _numTokens; i++) {
            uint256 tokenId = MAX_BASE_SUPPLY + upgradeSupply;
            _safeMint(_to, tokenId);
            tokenLevel[tokenId] = lockLV;
            levels[lockLV].supply++;
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
        return isUpgrade(_tokenId) || revealed;
    }

    function revealedTokenLevel(uint256 _tokenId) public view returns (uint256) {
        require(tokenRevealed(_tokenId), "Token unrevealed");

        return tokenLevel[_tokenId];
    }

    function tokenYield(uint256 _tokenId) public view returns (uint256) {
        uint256 level = revealedTokenLevel(_tokenId);
        return levels[level].yield;
    }
    
    function setSkipWL() public onlyOwner{
        skipWL = !skipWL;
    }

    function getWhiteList() public view returns (address[] memory){
        return whiteListAddresses;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (isUpgrade(_tokenId)) {
            return string(abi.encodePacked(BASE_URI, "level/", revealedTokenLevel(_tokenId).toString(), ".json"));
        } else if (!tokenRevealed(_tokenId)) {
            return string(abi.encodePacked(BASE_URI, "unrevealed.json"));
        } else if (revealedTokenLevel(_tokenId) == 1) {
            return string(abi.encodePacked(BASE_URI, _tokenId.toString(), "-super.json"));
        } else {
            return string(abi.encodePacked(BASE_URI, _tokenId.toString(), "-miner.json"));
        }
    }

    function contractURI() public view returns (string memory) {
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


    function reveal() external onlyOwner{
        revealed = true;
    }

    function isApprovedForAll(address _owner, address _operator) public view override returns (bool) {
        if (_operator == mineAddress) {
            return true;
        }

        return super.isApprovedForAll(_owner, _operator);
    }

    function setMineAddress(address _mineAddress) public onlyOwner {
        mineAddress = _mineAddress;
    }

    function setEventAddress(address _eventAddress) public onlyOwner {
        eventAddress = _eventAddress;
    }

    function setDiamond(Diamond _diamond) public onlyOwner {
        diamond = _diamond;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        BASE_URI = _newBaseURI;
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