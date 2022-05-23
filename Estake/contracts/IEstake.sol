pragma solidity ^0.8.0;

interface IEstake {
    
    
    function stake() external payable returns(uint256 esAvax);

    event Submitted(address indexed sender, uint256 amount);

}