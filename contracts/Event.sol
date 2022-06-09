//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import './Diamond.sol';
import './Miner.sol';
import './Mine.sol';
import './Vault.sol';

contract Event is Ownable {
    using SafeMath for uint256;

    Miner public miner;
    Diamond public diamond;
    Vault public vault;
    Mine public mine;
    uint256 pastEvent;
    uint256 eventSize = 5;
    uint256 lockLV = 2;
    uint256 playerSize;

    uint256 public constant EVENT_DURATION = 5 minutes; //Change back to 1 day

    // GEM guy that doubles ur earnings
    // Lottery guy
    // Lock seller

    //rain diamonds
    //diamond drought

    // make owner only on some functions

    // make some functions private and local only

    struct eventHold {
        string name;
        bool available;
        uint256 startTimestamp;
        uint256 price;
    }

    mapping(uint256 => eventHold) public events;

    mapping(address => uint256) public players;
    mapping(address => uint256) public lastPlayers;


    address[] public playersAddresses;
    address[] public playersAttacked;


    constructor(
        Miner _miner,
        Diamond _diamond,
        Vault _vault,
        Mine _mine
    ) {
        miner = _miner;
        diamond = _diamond;
        vault = _vault;
        mine = _mine;

        events[0] = eventHold({name: 'GEM', available: true, startTimestamp: 0, price: 0});

        events[1] = eventHold({name: 'Dealer', available: false, startTimestamp: 0, price: 0});

        events[2] = eventHold({name: 'Locksmith', available: false, startTimestamp: 0, price: 0});

        events[3] = eventHold({name: 'Miners Miracle', available: false, startTimestamp: 0, price: 0});

        events[4] = eventHold({name: 'Diamond Apocalypse', available: false, startTimestamp: 0, price: 0});
    }

    function switchEvents(uint256 _id, uint256 _price) public onlyOwner {
        //require(block.timestamp >= events[activeEvent()].startTimestamp + EVENT_DURATION, "Event is still ongoing");
        pastEvent = activeEvent();

        if(_id == 3) {
            mine.setYieldDps(16666666666666667 * 2);
        } else if(_id == 4) {
            mine.setYieldDps(8333333333333333);
        } else {
            if(mine.YIELD_DPS() != 16666666666666667) {
                 mine.setYieldDps(16666666666666667);
            }
        }

        for (uint256 i = 0; i < eventSize - 1; i++) {
            events[i].available = false;
        }
        //empty array
        //same old array
        //mapping(address => uint256) storage emptyPlayers;
        for(uint256 i = 0; i < playersAddresses.length; i++) {
            lastPlayers[playersAddresses[i]] = players[playersAddresses[i]];
        }

        cleanPlayers();
        events[_id].available = true;
        events[_id].startTimestamp = block.timestamp;
        if (_id == lockLV) {
            miner.updateUpgradePrice(lockLV, _price);
        }
        events[_id].price = _price;
    }

    //Function to check if a miner has already been used
    function isMinerUsed() public view returns (bool) {
        if (players[msg.sender] > 0) {
            return true;
        }
        return false;
    }

    //Checks if an amount of miners are able to be used
    function isMinerUsed(uint256 _size) public view returns (bool) {
        uint256 totalStaked = mine.ownedStakesBalance(msg.sender);
        if (totalStaked < _size) {
            return true;
        }

        if (_size > totalStaked - players[msg.sender]) {
            return true;
        }
        return false;
    }

      //Function to check if a miner has already been used
    function isPastMinerUsed() public view returns (bool) {
        if (lastPlayers[msg.sender] > 0) {
            return true;
        }
        return false;
    }

    //Checks if an amount of miners are able to be used
    function isPastMinerUsed(uint256 _size) public view returns (bool) {
        uint256 totalStaked = mine.ownedStakesBalance(msg.sender);
        if (totalStaked < _size) {
            return true;
        }

        if (_size > totalStaked - lastPlayers[msg.sender]) {
            return true;
        }
        return false;
    }

    //Check if a miner owns a lock
    function isMinerProtected(address _player) public view returns (bool) {
        uint256 totalStaked = mine.ownedStakesBalance(_player);
        Mine.OwnedStakeInfo[] memory stakes = mine.batchedStakesOfOwner(_player, 0, totalStaked);

        for (uint256 i = 0; i < totalStaked; i++) {
            if (stakes[i].level == lockLV) {
                return true;
            }
        }
    
        return false;
    }

    function burnLock(address _player) internal {
        uint256 totalStaked = mine.ownedStakesBalance(_player);
        Mine.OwnedStakeInfo[] memory stakes = mine.batchedStakesOfOwner(_player, 0, totalStaked);

        for (uint256 i = 0; i < totalStaked; i++) {
            if (stakes[i].level == lockLV) {
                mine.burnLock(stakes[i].tokenId);
                break;
            }
        }
    }

    function setEventPrice(uint256 _id, uint256 _price) public onlyOwner {
        events[_id].price = _price;
    }

    function activeEvent() public view returns (uint256 _id) {
        uint256 id;
        for (uint256 i = 0; i < eventSize - 1; i++) {
            if (events[i].available) {
                return id = i;
            }
        }
    }

    //Function to send miners
    function setMinerOut() public {
        require(mine.ownedStakesBalance(msg.sender) > 0, 'You must have a miner staked');
        players[msg.sender] = 1;
        playersAddresses.push(msg.sender);

        //miners[miners.length+1] = mine.batchedStakesOfOwner(msg.sender,0,1)[0].tokenId;
    }

    function setMinerOut(uint256 _amount) public {
        require(mine.ownedStakesBalance(msg.sender) >= _amount, 'You must have miners staked');
        players[msg.sender] = players[msg.sender] + _amount;
        playersAddresses.push(msg.sender);
    }

    function cleanPlayers() public onlyOwner {
        for (uint256 i = 0; i < playersAddresses.length; i++) {
            players[playersAddresses[i]] = 0;
        }
        address[] memory emptyArray;
        playersAddresses = emptyArray;
    }

    // Event function
    // Check if you even own a miner
    function gemPlay(uint256 _amount) public returns (bool) {
        require(activeEvent() == 0, "Event isn't ongoing");
        require(!isMinerUsed(), 'A miner has already performed an action during this event');
        require(diamond.balanceOf(msg.sender) >= _amount, 'Insufficient DIAMOND balance');
        //random chance
        if (block.timestamp % 4 == 0) {
            diamond.mint(msg.sender, _amount);
            setMinerOut();
            return true;
        } else {
            diamond.burn(msg.sender, _amount / 2);
            setMinerOut();
            return false;
        }
    }

    function dealerStart(uint256 _amount) public returns (bool) {
        require(activeEvent() == 1, "Event isn't ongoing");
        require(_amount > 0, 'Amount must be above zero');
        require(!isMinerUsed(_amount), "You don't have available miners");
        require(diamond.balanceOf(msg.sender) >= events[activeEvent()].price, 'Insufficient DIAMOND balance');
        //Small % of wining
        diamond.burn(msg.sender, events[activeEvent()].price);
        if (block.timestamp % 4 == 0) {
            diamond.mint(msg.sender, events[activeEvent()].price * 10);
            setMinerOut(_amount);
            return true;
        } else {
            diamond.burn(msg.sender, events[activeEvent()].price);
            setMinerOut(_amount);
            return false;
        }
    }

    function minersMiracleStart(uint256 _amount) public {
        require(activeEvent() == 3 || activeEvent() == 4, "Event isn't ongoing");
        require(!isMinerUsed(_amount), "This miner has already performed an action during this event");
        setMinerOut(_amount);
    }

    function attackMinersReward() public {
        require(pastEvent == 3 || pastEvent == 4, "Past event has to be an attackable event");
        require(isPastMinerUsed(), "You haven't sent anyone out to attack");
        //Reward attacker with diamonds
        diamond.mint(msg.sender, (vault.storedDiamond() / 99) * lastPlayers[msg.sender]);
    }

    function playerExist(address _player) internal view returns (bool result) {
        result = false;    
        for (uint256 i = 0; i < playersAttacked.length; i++) {
            if (_player == playersAttacked[i]) {
                result = true;
            }
        }
    }

    function attackedMiners() public onlyOwner {
        for (uint256 i = 0; i < miner.totalSupply(); i++) {
            // change
            if (!playerExist(miner.ownerOf(i))) {
                address temp = miner.ownerOf(i);
                playersAttacked.push(temp);
            }
        }

        for (uint256 i = 0; i < playersAttacked.length; i++) {
            if (isMinerProtected(playersAttacked[i])) {
                burnLock(playersAttacked[i]);
            } 
            else {
                if(vault.balanceOf(playersAttacked[i]) >= 20000000000000000000) {
                    vault.burn(playersAttacked[i], 20000000000000000000);
                }  
            }
        }
    }

    function mintLock(uint16 _numTokens) external {
        require(activeEvent() == 2, "Locks can only be minted during the Locksmith event");
        miner.mintLock(_numTokens, msg.sender);
    }
}