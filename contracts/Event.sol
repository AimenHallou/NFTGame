//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Diamond.sol";
import "./Miner.sol";
import "./Mine.sol";
import "./Vault.sol";


contract Event is Ownable {
    using SafeMath for uint256;

    Miner public miner;
    Diamond public diamond;
    Vault public vault;
    Mine public mine;
    uint256 pastEvent;
    uint256 eventSize = 5;
    uint256 lockLV = 2;

    uint256 public constant EVENT_DURATION = 5 minutes;  //Change back to 1 day

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
    
    uint256[] miners;
    uint256[] pastMiners;

    constructor(Miner _miner, Diamond _diamond, Vault _vault, Mine _mine) {
        miner = _miner;
        diamond = _diamond;
        vault = _vault;
        mine = _mine;

        events[0] = eventHold({
            name: "GEM",
            available: true,
            startTimestamp: 0,
            price: 0
        });

        events[1] = eventHold({
            name: "Dealer",
            available: false,
            startTimestamp: 0,
            price: 0
        });

        events[2] = eventHold({
            name: "Locksmith",
            available: false,
            startTimestamp: 0,
            price: 0
        });

        events[3] = eventHold({
            name: "Miners Miracle",
            available: false,
            startTimestamp: 0,
            price: 0
        });

        events[4] = eventHold({
            name: "Diamond Apocalypse",
            available: false,
            startTimestamp: 0,
            price: 0
        });
    }

    function switchEvents(uint256 _id, uint256 _price) public onlyOwner {
        require(block.timestamp >= events[activeEvent()].startTimestamp + EVENT_DURATION, "Event is still ongoing");
        pastEvent = activeEvent();
        for (uint256 i = 0; i < eventSize-1; i++){
            events[i].available = false;
        }

        //empty array

        uint256[] memory emptyMiners;
        pastMiners = miners;
        miners = emptyMiners;
        events[_id].available = true;
        events[_id].startTimestamp = block.timestamp;
        if (_id == lockLV){
            miner.updateUpgradePrice(lockLV, _price);
        }
        events[_id].price = _price;
    } 

//Function to check if a miner has already been used

    function isMinerUsed(uint256 _id, uint256[] memory _miners) public view returns(bool) {
        for (uint256 i = 0; i < _miners.length; i++){
            if (_miners[i]== _id)
             return true;
        }
        return false;
    }

    function isMinerUsed(uint256[] memory _miners) public view returns(bool){
        uint256 totalStaked = mine.ownedStakesBalance(msg.sender);
        Mine.OwnedStakeInfo[] memory temp;
        for (uint256 i = 0; i < totalStaked; i++){
            for (uint256 j = 0; j < _miners.length; j++){
                temp = mine.batchedStakesOfOwner(msg.sender,i,1);
                if (temp[0].tokenId == _miners[j]){
                    return true;
                }
        }
        return false;
        }
    }

//Check if a miner owns a lock
    function isMinerProtected(address _player) public view returns(bool){
        uint256 totalStaked = mine.ownedStakesBalance(_player);
        Mine.OwnedStakeInfo[] memory temp;
        for (uint256 i = 0; i < totalStaked-1; i++){
            temp = mine.batchedStakesOfOwner(_player,i,1);
                if (temp[0].level == lockLV){
                    return true;
            }
        }
        return false;
    }

    function burnLock(address _player) internal{
        uint256 totalStaked = mine.ownedStakesBalance(_player);
        Mine.OwnedStakeInfo[] memory temp;
        for (uint256 i = 0; i < totalStaked-1; i++){
            temp = mine.batchedStakesOfOwner(_player,i,1);
                if (temp[0].level == lockLV){
                    miner.burnLock(temp[0].tokenId);
                    break;
            }
        }
    }

//How many miners are used
    function countMinersUsed(uint256[] memory _miners) public view returns(uint256){
        uint256 totalStaked = mine.ownedStakesBalance(msg.sender);
        Mine.OwnedStakeInfo[] memory temp;
        uint256 tempTotal = 0;
        for (uint256 i = 0; i < totalStaked; i++){
            for (uint256 j = 0; j < _miners.length; j++){
                temp = mine.batchedStakesOfOwner(msg.sender,i,1);
                if (temp[0].tokenId == _miners[j]){
                    tempTotal++;
                }
        }
        return tempTotal;
        }
    }

    function setEventPrice(uint256 _id, uint256 _price) public onlyOwner{
        events[_id].price = _price;
    }
    
    function activeEvent() public view returns(uint256 _id) {
        uint256 id;
        for (uint256 i = 0; i < eventSize-1; i++){
            if(events[i].available){
                return id = i;
            }
        }
    }

//Function to send miners
    function setMinerOut() public{
        miners[miners.length+1] = mine.batchedStakesOfOwner(msg.sender,0,1)[0].tokenId;
    }

    function setMinerOut(uint256 _id) public{
        miners[miners.length+1] = _id;
    }


    // Event function
    // Check if you even own a miner
    function gemPlay(uint256 _amount) public returns(bool){
        require(activeEvent() == 0, "Event isn't ongoing");
        require(!isMinerUsed(miners), "A miner has already performed an action during this event");
        require(diamond.balanceOf(msg.sender) >= _amount, "Insufficient DIAMOND balance");
        //random chance
        if (block.timestamp%4 == 0){
            diamond.mint(msg.sender, _amount);
            setMinerOut();
            return true;
        } else {
            diamond.burn(msg.sender, _amount/2);
            setMinerOut();
            return false;
        }
    }

    function dealerStart(uint256 _id) public returns(bool){
        require(activeEvent() == 1, "Event isn't ongoing");
        require(!isMinerUsed(_id, miners), "This miner has already performed an action during this event");
        require(diamond.balanceOf(msg.sender) >= events[activeEvent()].price, "Insufficient DIAMOND balance");
        //Small % of wining
        diamond.burn(msg.sender, events[activeEvent()].price);
        if (block.timestamp%4 == 0){
            diamond.mint(msg.sender, events[activeEvent()].price*10);
            return true;
        } else {
            diamond.burn(msg.sender, events[activeEvent()].price);
            return false;
        }
    }

    function minersMiracleStart(uint256 _id) public{
        require(activeEvent() == 3, "Event isn't ongoing");
        require(!isMinerUsed(_id, pastMiners), "This miner has already performed an action during this event");
        setMinerOut(_id);
    }

    function attackMinersReward() public{
        require(pastEvent == 3 || pastEvent == 4,"Past event has to be an attackable event");
        require(!isMinerUsed(pastMiners), "You haven't sent anyone out to attack");
//Reward attacker with diamonds
        diamond.mint(msg.sender, (vault.storedDiamond()/99)*countMinersUsed(pastMiners));
    }

    function playerExist(address _player) internal returns(bool){
        for (uint256 i = 0; i<miners.length; i++){
            if (_player == miner.ownerOf(miners[i])){
                return true;
            }
        }
        return false;
    }


    function attackedMiners() public onlyOwner returns(bool) {
        address[] memory players;

        for (uint256 i = 0; i < miners.length; i++){
            // change
            if (!playerExist(miner.ownerOf(miners[i]))){
            address temp = miner.ownerOf(miners[i]);
            players[players.length+1] = temp;
                }
            }
        for (uint256 i = 0; i < players.length; i++){
        if (isMinerProtected(players[i])){
            burnLock(players[i]);
            return false;
        } else {
            vault.burn(players[i], 200000);
            return true;
        }
        }
    }

}
