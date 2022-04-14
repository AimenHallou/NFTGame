//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Diamond.sol";

contract Vault is ERC20("Staked Diamond", "sDIAMOND"), Ownable {
    using SafeMath for uint256;
    Diamond public diamond;

    uint256 public constant DELAYED_UNSTAKE_LOCKUP_PERIOD = 2 days;
    uint256 public constant QUICK_UNSTAKE_PENALTY_PERCENT = 50;

    uint256 public storedDiamond; // $Diamond pending withdraw

    mapping(address => uint256) public unlockAmounts;
    mapping(address => uint256) public unlockTimestamps;

    function setDiamond(Diamond _diamond) external onlyOwner {
        require(address(diamond) == address(0), "Diamond contract already set");

        diamond = _diamond;
    }

    function stake(uint256 _amount) public {
        uint256 totalShares = totalSupply();
        // If no sDIAMOND exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || diamondBalance() == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(diamondBalance());
            _mint(msg.sender, what);
        }

        diamond.transferToVault(msg.sender, _amount);
    }

    function quickUnstake(uint256 _share) public {
        uint256 output = _unstakeOutput(_share).mul(100 - QUICK_UNSTAKE_PENALTY_PERCENT).div(100);
        _burn(msg.sender, _share);
        diamond.transfer(msg.sender, output);
    }

    // argument specified in sDIAMOND
    function prepareDelayedUnstake(uint256 _share) public {
        uint256 output = _unstakeOutput(_share);
        _burn(msg.sender, _share);

        unlockAmounts[msg.sender] += output;
        unlockTimestamps[msg.sender] = block.timestamp + DELAYED_UNSTAKE_LOCKUP_PERIOD;
        storedDiamond += output;
    }

    // argument specified in DIAMOND, not sDIAMOND
    function claimDelayedUnstake(uint256 _amount) public {
        require(block.timestamp >= unlockTimestamps[msg.sender], "DIAMOND not yet unlocked");
        require(_amount <= unlockAmounts[msg.sender], "Insufficient locked balance");

        unlockAmounts[msg.sender] -= _amount;
        diamond.transfer(msg.sender, _amount);
        storedDiamond -= _amount;
    }

    function diamondBalance() public view returns (uint256 balance) {
        balance = diamond.balanceOf(address(this)) - storedDiamond;
    }

    function _unstakeOutput(uint256 _share) internal view returns (uint256 output) {
        uint256 totalShares = totalSupply();
        output = _share.mul(
            diamondBalance()
        ).div(totalShares);
    }
}