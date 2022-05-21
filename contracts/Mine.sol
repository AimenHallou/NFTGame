//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Diamond.sol";
import "./Miner.sol";

contract Mine is Ownable {
    using SafeMath for uint256;

    Miner public miner;
    Diamond public diamond;
    address public vaultAddress;

    uint256 public constant YIELD_CPS = 16666666666666667; // diamonds mined per second per unit of yield
    uint256 public constant CLAIM_DIAMOND_TAX_PERCENTAGE = 20;
    uint256 public constant UNSTAKE_COOLDOWN_DURATION = 2 days;

    struct StakeDetails {
        address owner;
        uint256 tokenId;
        uint256 startTimestamp;
        bool staked;
    }

    struct OwnedStakeInfo {
        uint256 tokenId;
        uint256 level;
        uint256 accrual;
    }

    mapping(uint256 => StakeDetails) public stakes;

    struct UnstakeCooldown {
        address owner;
        uint256 tokenId;
        uint256 startTimestamp;
        bool present;
    }

    struct OwnedCooldownInfo {
        uint256 tokenId;
        uint256 level;
        uint256 startTimestamp;
    }

    mapping(uint256 => UnstakeCooldown) public unstakeCooldowns;

    mapping(address => mapping(uint256 => uint256)) private ownedStakes; // (user, index) => stake
    mapping(uint256 => uint256) private ownedStakesIndex; // token id => index in its owner's stake list
    mapping(address => uint256) public ownedStakesBalance; // user => stake count

    mapping(address => mapping(uint256 => uint256)) private ownedCooldowns; // (user, index) => cooldown
    mapping(uint256 => uint256) private ownedCooldownsIndex; // token id => index in its owner's cooldown list
    mapping(address => uint256) public ownedCooldownsBalance; // user => cooldown count

    constructor(Miner _miner, Diamond _diamond, address _vaultAddress) {
        miner = _miner;
        diamond = _diamond;
        vaultAddress = _vaultAddress;
    }

    // Views

    function getDiamondsAccruedForMany(uint256[] calldata _tokenIds) external view returns (uint256[] memory) {
        uint256[] memory diamondAmounts = new uint256[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            diamondAmounts[i] = _getDiamondsAccruedFor(_tokenIds[i], false);
        }
        return diamondAmounts;
    }

    function _getDiamondsAccruedFor(uint256 _tokenId, bool checkOwnership) internal view returns (uint256) {
        StakeDetails memory stake = stakes[_tokenId];
        require(stake.staked, "This token isn't staked");
        if (checkOwnership) {
            require(stake.owner == _msgSender(), "You don't own this token");
        }
        return (block.timestamp - stake.startTimestamp) * miner.tokenYield(_tokenId) * YIELD_CPS;
    }

    // Mutators

    function stakeMany(uint256[] calldata _tokenIds) external {
        require(miner.gameStarted(), "The game has not started");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(miner.ownerOf(tokenId) == _msgSender(), "You don't own this token");
            require(miner.tokenRevealed(tokenId), "Token not yet revealed");

            miner.transferFrom(_msgSender(), address(this), tokenId);
            _addMinerToMine(tokenId, _msgSender());
        }
    }

    function claimDiamondsAndMaybeUnstake(uint256[] calldata _tokenIds, bool unstake) external {
        uint256 totalClaimed = 0;
        uint256 totalTaxed = 0;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 diamonds = _getDiamondsAccruedFor(tokenId, true); // also checks that msg.sender owns this token
            uint256 taxAmount = (diamonds * CLAIM_DIAMOND_TAX_PERCENTAGE + 99) / 100; // +99 to round the division up

            totalClaimed += diamonds - taxAmount;
            totalTaxed += taxAmount;
            stakes[tokenId].startTimestamp = block.timestamp;

            if (unstake) {
                _moveMinerToCooldown(tokenId);
            }
        }

        diamond.mint(_msgSender(), totalClaimed);
        diamond.mint(vaultAddress, totalTaxed);
    }

    function withdrawMiner(uint256[] calldata _tokenIds) external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            UnstakeCooldown memory cooldown = unstakeCooldowns[tokenId];

            require(cooldown.present, "Token is not in cooldown");
            require(_msgSender() == cooldown.owner, "You don't own this token");
            require(block.timestamp >= cooldown.startTimestamp + UNSTAKE_COOLDOWN_DURATION, "Token is still in cooldown");

            miner.transferFrom(address(this), _msgSender(), tokenId);
            _removeMinerFromCooldown(tokenId);
        }
    }

    function editCooldown(uint[] calldata _tokenIds, uint256 value) public onlyOwner {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            unstakeCooldowns[i].startTimestamp = value;
        }
    }

    function _addMinerToMine(uint256 _tokenId, address _owner) internal {
        stakes[_tokenId] = StakeDetails({
            owner: _owner,
            tokenId: _tokenId,
            startTimestamp: block.timestamp,
            staked: true
        });
        _addStakeToOwnerEnumeration(_owner, _tokenId);
    }

    function _moveMinerToCooldown(uint256 _tokenId) internal {
        address owner = stakes[_tokenId].owner;
        unstakeCooldowns[_tokenId] = UnstakeCooldown({
            owner: stakes[_tokenId].owner,
            tokenId: _tokenId,
            startTimestamp: block.timestamp,
            present: true
        });

        delete stakes[_tokenId];
        _removeStakeFromOwnerEnumeration(owner, _tokenId);
        _addCooldownToOwnerEnumeration(owner, _tokenId);
    }

    function _removeMinerFromCooldown(uint256 _tokenId) internal {
        address owner = unstakeCooldowns[_tokenId].owner;
        delete unstakeCooldowns[_tokenId];
        _removeCooldownFromOwnerEnumeration(owner, _tokenId);
    }

    function stakeOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256) {
        require(_index < ownedStakesBalance[_owner], "owner index out of bounds");
        return ownedStakes[_owner][_index];
    }

    function batchedStakesOfOwner(address _owner, uint256 _offset, uint256 _maxSize) public view returns (OwnedStakeInfo[] memory) {
        if (_offset >= ownedStakesBalance[_owner]) {
            return new OwnedStakeInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedStakesBalance[_owner]) {
            outputSize = ownedStakesBalance[_owner] - _offset;
        }
        OwnedStakeInfo[] memory outputs = new OwnedStakeInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = stakeOfOwnerByIndex(_owner, _offset + i);

            outputs[i] = OwnedStakeInfo({
                tokenId: tokenId,
                level: miner.revealedTokenLevel(tokenId),
                accrual: _getDiamondsAccruedFor(tokenId, false)
            });
        }

        return outputs;
    }

    function _addStakeToOwnerEnumeration(address _owner, uint256 _tokenId) internal {
        uint256 length = ownedStakesBalance[_owner];
        ownedStakes[_owner][length] = _tokenId;
        ownedStakesIndex[_tokenId] = length;
        ownedStakesBalance[_owner]++;
    }

    function _removeStakeFromOwnerEnumeration(address _owner, uint256 _tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ownedStakesBalance[_owner] - 1;
        uint256 tokenIndex = ownedStakesIndex[_tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedStakes[_owner][lastTokenIndex];

            ownedStakes[_owner][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ownedStakesIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete ownedStakesIndex[_tokenId];
        delete ownedStakes[_owner][lastTokenIndex];
        ownedStakesBalance[_owner]--;
    }

    function cooldownOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256) {
        require(_index < ownedCooldownsBalance[_owner], "owner index out of bounds");
        return ownedCooldowns[_owner][_index];
    }

    function batchedCooldownsOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (OwnedCooldownInfo[] memory) {
        if (_offset >= ownedCooldownsBalance[_owner]) {
            return new OwnedCooldownInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedCooldownsBalance[_owner]) {
            outputSize = ownedCooldownsBalance[_owner] - _offset;
        }
        OwnedCooldownInfo[] memory outputs = new OwnedCooldownInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = cooldownOfOwnerByIndex(_owner, _offset + i);

            outputs[i] = OwnedCooldownInfo({
                tokenId: tokenId,
                level: miner.revealedTokenLevel(tokenId),
                startTimestamp: unstakeCooldowns[tokenId].startTimestamp
            });
        }

        return outputs;
    }

    function _addCooldownToOwnerEnumeration(address _owner, uint256 _tokenId) internal {
        uint256 length = ownedCooldownsBalance[_owner];
        ownedCooldowns[_owner][length] = _tokenId;
        ownedCooldownsIndex[_tokenId] = length;
        ownedCooldownsBalance[_owner]++;
    }

    function _removeCooldownFromOwnerEnumeration(address _owner, uint256 _tokenId) private {
        uint256 lastTokenIndex = ownedCooldownsBalance[_owner] - 1;
        uint256 tokenIndex = ownedCooldownsIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedCooldowns[_owner][lastTokenIndex];
            ownedCooldowns[_owner][tokenIndex] = lastTokenId;
            ownedCooldownsIndex[lastTokenId] = tokenIndex;
        }

        delete ownedCooldownsIndex[_tokenId];
        delete ownedCooldowns[_owner][lastTokenIndex];
        ownedCooldownsBalance[_owner]--;
    }

}
