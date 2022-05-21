pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./esAvax.sol";

contract esAvax is ERC20, Pausable, Ownable {

    using SafeMath for uint256;

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

    function getSharesFromStakedAvax(uint256 _amountAvax) public view returns (uint256){

        uint256 totalAvaxPool = getTotalPooledAvax();
        if(totalAvaxPool =0){
            return 0;
        }
        else{
            return _amountAvax.mul(getTotalShares()).div(totalAvaxPool);
        }

    }

    function _mintStakeShares(address receiver, uint256 amount) internal whenNotPaused returns (uint256 newTotalShares){
        require(receiver != address(0), "Will NOT MINT TO THE NULL ADDRESS");
        
        newTotalShares = getTotalShares().add(_amount);
        TOTAL_AVAX_SHARES.setStorageUint256(newTotalShares);

    }

}