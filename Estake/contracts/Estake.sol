// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./esAvax.sol";
import "./IEstake.sol";
import "./unstructured-storage.sol";
//add IEstake
contract Estake is esAvax, IEstake{

    using SafeMath for uint256;
    using UnstructuredStorage for bytes32;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balanceStaked;

    bytes32 constant public DAOMULTISIG = keccak256("DAO_MULTI_SIG");

    receive() external payable {
       receiveWorkAround();
    }
    //unfortunatly this function is needed because sol throws a error when
    //getting msg.data through the receive function
    function receiveWorkAround() internal returns (bool){
        require(msg.data.length == 0, "NON_EMPTY_DATA");
        _stake();
        return true;
    }

    function stake() external override payable returns (uint256){
        return _stake();
    }

    function getSupply() public view returns (uint256){
        return _totalSupply;
    }

    function _getTotalAvaxPooled() internal override view returns(uint256){
        //to deploy make this actually run a caculation
        return 1;
    }

    function _stake() internal whenNotPaused returns (uint256) {
        address sender = msg.sender;
        uint256 deposit = msg.value;

        require(deposit != 0, "Deposit_is_null"); 

        uint256 sharesToMint = getSharesFromStakedAvax(deposit);
        if(sharesToMint == 0){
            //this only happens when staker is new
            sharesToMint = deposit;
        }
        _mintShares(sender, sharesToMint);

        _submitted(sender, deposit);

        return sharesToMint;
    }

    function _submitted(address sender, uint256 amount) internal {
        emit Submitted(sender, amount);
    }

}