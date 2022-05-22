// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./esAvax.sol";
//add IEstake
contract Estake is IEstake, esAvax, Pausable{

    using SafeMath for uint256;

    constructor() ERC20("Oscar Avax", "oAvax") {}

    uint256 private _totalSupply;
    mapping(address => uint256) private _balanceStaked;

    function getSupply() public view returns (uint256){
        return _totalSupply;
    }

    function _getTotalAvaxPooled() internal override view returns(uint256){
        //to deploy make this actually run a caculation
        return 1;
    }

    function stake() internal whenNotPaused returns (uint256 esAvax) {
        address sender = msg.sender;
        uint256 deposit = msg.value;

        require(deposit != 0, "Deposit_is_null"); 

        uint256 sharesToMint = getSharesFromStakedAvax(deposit);
        if(sharesToMint == 0){
            //this only happens when staker is new as their is no slashing on avax
            sharesToMint = deposit;
        }
        _mintShares(sender, sharesToMint);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    
    function pause() public onlyOwner {
        _pause();
    }


    function unpause() public onlyOwner {
        _unpause();
    }
}