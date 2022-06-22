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
    bool public eventPlayable = true;

    uint256 public EVENT_DURATION = 1 days;

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

//Switch between events 
    function switchEvents(uint256 _id, uint256 _price) public onlyOwner {
        require(block.timestamp >= events[activeEvent()].startTimestamp + EVENT_DURATION, "Event is still ongoing");
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

    function pauseUnpauseEvent() public onlyOwner{
        eventPlayable = !eventPlayable;
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

    function isPastMinerUsed(address _player) public view returns (bool) {
        if (lastPlayers[_player] > 0) {
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

//Burn a lock to protect yourself from an attack
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

//Event duration setter
    function setEVENT_DURATION(uint256 _duration) public onlyOwner{
        EVENT_DURATION = _duration;
    }

//Event price setter
    function setEventPrice(uint256 _id, uint256 _price) public onlyOwner {
        events[_id].price = _price;
    }

//Returns what event is currently active
    function activeEvent() public view returns (uint256) {
        for (uint256 i = 0; i < eventSize; i++) {
            if (events[i].available) {
                return i;
            }
        }
    }

//Send out miner to participate in event 
    function setMinerOut() internal{
        require(mine.ownedStakesBalance(msg.sender) > 0, 'You must have a miner staked');
        players[msg.sender] = 1;
        playersAddresses.push(msg.sender);
    }

//Send out miners to participate in event 
    function setMinerOut(uint256 _amount) internal {
        require(mine.ownedStakesBalance(msg.sender) >= _amount, 'You must have miners staked');
        players[msg.sender] = players[msg.sender] + _amount;
        playersAddresses.push(msg.sender);
    }

//Remove player from event
    function cleanPlayers() internal {
        for (uint256 i = 0; i < playersAddresses.length; i++) {
            players[playersAddresses[i]] = 0;
        }
        address[] memory emptyArray;
        playersAddresses = emptyArray;
    }

//Play the gem event
    function gemPlay(uint256 _amount) public returns (bool) {
        require(eventPlayable, "Events are currently paused");
        require(activeEvent() == 0, "Event isn't ongoing");
        require(!isMinerUsed(), 'A miner has already performed an action during this event');
        require(diamond.balanceOf(msg.sender) >= _amount, 'Insufficient DIAMOND balance');
        //FIX HERE
        //random chance
        if (block.timestamp % 4 == 0) {
            diamond.mint(msg.sender, _amount*2);
            setMinerOut();
            return true;
        } else {
            diamond.burn(msg.sender, _amount / 2);
            setMinerOut();
            return false;
        }
    }

//Play the dealer event
    function dealerStart(uint256 _amount) public returns (bool) {
        require(eventPlayable, "Events are currently paused");
        require(activeEvent() == 1, "Event isn't ongoing");
        require(_amount > 0, 'Amount must be above zero');
        require(!isMinerUsed(_amount), "You don't have available miners");
        require(diamond.balanceOf(msg.sender) >= events[activeEvent()].price, 'Insufficient DIAMOND balance');
        //FIX HERE
        diamond.burn(msg.sender, events[activeEvent()].price);
        if (block.timestamp % 4 == 0) {
            diamond.mint(msg.sender, events[activeEvent()].price * 10);
            setMinerOut(_amount);
            return true;
        } else {
            setMinerOut(_amount);
            return false;
        }
    }

    //Send out an attack during an event
    function specialEventStart(uint256 _amount) public {
        require(eventPlayable, "Events are currently paused");
        require(activeEvent() == 3 || activeEvent() == 4, "Event isn't ongoing");
        require(!isMinerUsed(_amount), "This miner has already performed an action during this event");
        setMinerOut(_amount);
    }

    //Reward attackers with diamonds
    function attackMinersReward() public onlyOwner{
        require(pastEvent == 3 || pastEvent == 4, "Past event has to be an attackable event");

        for (uint256 i = 0; i < playersAddresses.length; i++) {
            if (isPastMinerUsed(playersAddresses[i])) {   
                diamond.mint(playersAddresses[i], (vault.balanceOf(playersAddresses[i]) / 99) * lastPlayers[playersAddresses[i]]);
            }
        }
    }

//Checks if player is already set out to be attacked
    function playerExist(address _player) internal view returns (bool result) {
        result = false;    
        for (uint256 i = 0; i < playersAttacked.length; i++) {
            if (_player == playersAttacked[i]) {
                result = true;
            }
        }
    }

 //Attcking miners after special events
    function attackedMiners() public onlyOwner {
        for (uint256 i = 0; i < miner.totalSupply(); i++) {

            try miner.ownerOf(i) returns (address a) {
                // Implement random feature 
                if (!playerExist(a)) {
                    playersAttacked.push(a);
                }
            } catch (bytes memory /*lowLevelData*/) {
               
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

//Buy a lock from the locksmith
    function mintLock(uint16 _numTokens) public {
        require(activeEvent() == 2, "Locks can only be minted during the Locksmith event");
        miner.mintLock(_numTokens, msg.sender);
    }
}