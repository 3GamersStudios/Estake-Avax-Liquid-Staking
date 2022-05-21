pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./esAvax.sol";
import "./unstructured-storage.sol";

contract esAvax is ERC20, Pausable {

    using SafeMath for uint256;
    using UnstructuredStorage for bytes32;

    mapping (address => uint256) private shares;

    bytes32 internal constant TOTAL_AVAX_SHARES = keccak256("estake.esAvax.totalShares");

    //returns name when queried
    function name() public pure returns (string) {
        return "EstakedAvax";
    }
    //returns decimal count to caculate shares to avax
    function decimals() public pure returns (uint8) {
        return 18;
    }
    //returns shortened name used on cexs and the web
    function symbol() public pure returns (string) {
        return "esAvax";
    }


    function getTotalShares() public view returns (uint256){
        return _getTotalShares();
    }

    function getTotalSupply() public view returns (uint256){
        return _getTotalAvaxPooled();
    }

    function getTotalAvaxPooled() public view returns (uint256){
        return _getTotalAvaxPooled();

    }

    function _getTotalAvaxPooled() public override returns (uint256){
        
    }

    function getSharesFromStakedAvax(uint256 _amountAvax) public view returns (uint256){

        uint256 totalAvaxPool = getTotalAvaxPooled();
        if(totalAvaxPool =0){
            return 0;
        }
        else{
            return _amountAvax.mul(getTotalShares()).div(totalAvaxPool);
        }

    }

    function _mintStakeShares(address receiver, uint256 amount) internal whenNotPaused returns (uint256 newTotalShares){
        require(receiver != address(0), "Will NOT MINT TO THE NULL ADDRESS");
        
        newTotalShares = getTotalShares().add(amount);
        TOTAL_AVAX_SHARES.setStorageUint256(newTotalShares);

    }

    function _getTotalShares() internal view returns (uint256){
        return TOTAL_AVAX_SHARES.getStorageUint256();
    }

}