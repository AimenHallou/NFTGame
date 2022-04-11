//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Diamond.sol";

contract Vault is ERC20("Staked Diamond", "sDIAMOND"), Ownable, Pausable {
    using SafeERC20 for Diamond;
    using SafeMath for uint256;

    uint256 public constant DELAYED_UNSTAKE_LOCKUP_PERIOD = 2 days;
    uint256 public constant DELAYED_UNSTAKE_BURN_PERCENT = 20;
    uint256 public constant QUICK_UNSTAKE_CONTRIBUTION_PERCENT = 60;
    uint256 public constant QUICK_UNSTAKE_BURN_PERCENT = 25;

    Diamond public diamond;
    uint public storedDiamond;

    mapping(address => uint256) public unlockAmounts;
    mapping(address => uint256) public unlockTimestamps;

    uint256 public stakeTime;

    constructor(Diamond _diamond) {
        diamond = _diamond;
    }

    //  Views

    function diamondBalance() public view returns (uint256 balance) {
        return diamond.balanceOf(address(this)) - storedDiamond;
    }

    function _unstakeOutput(uint256 _share) internal view returns (uint256 output) {
        uint256 totalShares = totalSupply();
        return _share.mul(diamondBalance()).div(totalShares);
    }

    //  External

    function stake(uint256 _amount) external whenNotPaused {
        require(stakeStarted(), "You can't stake yet");
        uint256 totalShares = totalSupply();
        // If no sDIAMOND exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || diamondBalance() == 0) {
            _mint(_msgSender(), _amount);
        } else {
            uint256 share = _amount.mul(totalShares).div(diamondBalance());
            _mint(_msgSender(), share);
        }
        diamond.transferToVault(_msgSender(), _amount);
    }

    function quickUnstake(uint256 _share) external whenNotPaused {
        // QUICK_UNSTAKE_CONTRIBUTION_PERCENT of the claimable DIAMONDS will remain in the vault
        // the rest is transfered to the staker
        uint256 unstakeOutput = _unstakeOutput(_share);
        uint256 output = unstakeOutput.mul(100 - QUICK_UNSTAKE_CONTRIBUTION_PERCENT).div(100);
        // QUICK_UNSTAKE_BURN_PERCENT of the claimable PIZZA is burned
        uint256 amountSpoiled = unstakeOutput.mul(QUICK_UNSTAKE_BURN_PERCENT).div(100);

        // burn staker's share
        _burn(_msgSender(), _share);

        diamond.burn(address(this), amountSpoiled);
        diamond.safeTransfer(_msgSender(), output);
    }

    
}