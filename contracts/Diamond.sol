//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Diamond is ERC20("Diamond", "DIAMOND"), Ownable{

    // Setting contract addresses

    address minerAddress;
    address mineAddress;
    address vaultAddress;
    address eventAddress;

    constructor(address _vaultAddress){
        vaultAddress = _vaultAddress;
    }

    //  Admin

    //  Setters

    function setEventAddress(address _eventAddress) external onlyOwner {
        eventAddress = _eventAddress;
    }

    function setMineAddress(address _mineAddress) external onlyOwner {
        mineAddress = _mineAddress;
    }

    function setMinerAddress(address _minerAddress) external onlyOwner {
        minerAddress = _minerAddress;
    }

    function setVaultAddress(address _vaultAddress) external onlyOwner {
        vaultAddress = _vaultAddress;
    }

    function mint(address _to, uint256 _amount) external {
        require(_msgSender() == mineAddress || _msgSender() == eventAddress, "Only the Mine or event contract can mint");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(_msgSender() == minerAddress || _msgSender() == eventAddress, "Only the Miner or event contract can burn");
        _burn(_from, _amount);
    }

    function transferToVault(address _from, uint256 _amount) external {
        require(_msgSender() == vaultAddress, "Only the Vault contract can call transferToVault");
        _transfer(_from, vaultAddress, _amount);
    }

}
