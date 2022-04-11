//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Diamond is ERC20("Diamond", "DIAMOND"), Ownable{

    // Setting contract addresses

    address minerAddress;
    address controllerAddress;
    address vaultAddress;
    address upgradeAddress;

    //  Admin

    //  Setters

    function setMinerAddress(address _minerAddress) external onlyOwner{
        minerAddress = _minerAddress;
    }

    function setControllerAddress(address _controllerAddress) external onlyOwner{
        controllerAddress = _controllerAddress;
    }

    function setvaultAddress(address _vaultAddress) external onlyOwner{
        vaultAddress = _vaultAddress;
    }

    function setUpgradeAddress(address _upgradeAddress) external onlyOwner{
        upgradeAddress = _upgradeAddress;
    }

    function transferToVault(address _from, uint256 _amount) external{
        require(vaultAddress != address(0), "missing initial requirements");
        require(_msgSender() == vaultAddress, "only the vault contract can call transferToVault");
        _transfer(_from, vaultAddress, _amount);
    }

    function transferForUpgradeFees(address _from, uint256 _amount) external {
        require(upgradeAddress != address(0), "missing initial requirements");
        require(_msgSender() == upgradeAddress, "only the upgrade contract can call transferForUpgradeFees");
        _transfer(_from, upgradeAddress, _amount);
    }

}
