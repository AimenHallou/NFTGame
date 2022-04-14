//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Diamond is ERC20("Diamond", "DIAMOND"), Ownable{

    // Setting contract addresses

    address minerAddress;
    address mineAddress;
    address vaultAddress;

    constructor(address _vaultAddress){
        vaultAddress = _vaultAddress;
    }

    //  Admin

    //  Setters

    function setMineAddress(address _mineAddress) external onlyOwner {
        require(address(mineAddress) == address(0), "Mine address already set");
        mineAddress = _mineAddress;
    }

    function setMinerAddress(address _minerAddress) external onlyOwner {
        require(address(minerAddress) == address(0), "Miner address already set");
        minerAddress = _minerAddress;
    }

    function mint(address _to, uint256 _amount) external {
        require(_msgSender() == minerAddress, "Only the Mine contract can mint");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(_msgSender() == minerAddress, "Only the Miner contract can burn");
        _burn(_from, _amount);
    }

    function transferToVault(address _from, uint256 _amount) external {
        require(_msgSender() == vaultAddress, "Only the Vault contract can call transferToVault");
        _transfer(_from, vaultAddress, _amount);
    }

}
