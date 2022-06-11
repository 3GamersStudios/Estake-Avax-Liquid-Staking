// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./unstructured-storage.sol";


//@dev all functions to be inheirited will be marked my a "_"
//helps with clarity for devs and community
abstract contract esAvax is Initializable, ERC20Upgradeable, PausableUpgradeable { 
    using SafeMath for uint256;
    using UnstructuredStorage for bytes32;

    mapping(address => uint256) private shares;

    mapping(address => mapping(address => uint256)) private allowances;

    //wallets staked
    uint256 stakeAccts;

    bytes32 internal constant TOTAL_AVAX_SHARES =
        keccak256("estake.esAvax.totalShares");


    function getCurrStakeAccts() public view returns (uint256){
        return stakeAccts;
    }

    function totalSupply() public view override returns (uint256) {
        return _getTotalAvaxPooled();
    }

    function getTotalShares() public view returns (uint256) {
        return _getTotalShares();
    }

    function getTotalSupply() public view returns (uint256) {
        return _getTotalAvaxPooled();
    }

    function getTotalAvaxPooled() public view returns (uint256) {
        return _getTotalAvaxPooled();
    }

    function sharesOf(address account) public view returns (uint256) {
        return _sharesOf(account);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return getPooledAvaxfromShares(_sharesOf(account));
    }

    function transfer(address reciver, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(msg.sender, reciver, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    //underscore is used to differentiate between spender and sender
    function increaseAllowance(address _spender, uint256 addedAmount)
        public
        override
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            allowances[msg.sender][_spender].add(addedAmount)
        );
        return true;
    }

    //underscore is used to differentiate between spender and sender
    function decreaseAllowance(address _spender, uint256 subtractedAmount)
        public
        override
        returns (bool)
    {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(
            currentAllowance >= subtractedAmount,
            "CANNOT DECREASE BELOW ZERO"
        );
        _approve(msg.sender, _spender, currentAllowance.sub(subtractedAmount));
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return allowances[owner][spender];
    }

    //underscore is used to differientiate sender vs msg.sender
    function transferFrom(
        address _sender,
        address reciver,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(
            currentAllowance >= amount,
            "Transfer Amount Exceeds Wallet Ballance"
        );

        _transfer(_sender, reciver, amount);
        _approve(_sender, msg.sender, currentAllowance.sub(amount));
        return true;
    }

    function getSharesFromStakedAvax(uint256 _amountAvax)
        public
        view
        returns (uint256)
    {
        uint256 totalAvaxPool = getTotalAvaxPooled();
        if (totalAvaxPool == 0) {
            return 0;
        } else {
            return _amountAvax.mul(getTotalShares()).div(totalAvaxPool);
        }
    }

    function getPooledAvaxfromShares(uint256 sharesAmount)
        public
        view
        returns (uint256)
    {
        uint256 totalShares = _getTotalShares();
        if (totalShares == 0) {
            return 0;
        } else {
            return sharesAmount.mul(_getTotalAvaxPooled()).div(totalShares);
        }
    }

    //mints new shares and adds them to the wallet adress without a transfer event
    //contract cannot be paused/address to mintTo cannot be the zero address
    function _mintShares(address mintTo, uint256 amount)
        internal
        whenNotPaused
        returns (uint256 newTotalShares)
    {
        require(mintTo != address(0), "NO MINT TO THE ZERO ADDRESS");

        newTotalShares = getTotalShares().add(amount);
        TOTAL_AVAX_SHARES.setStorageUint256(newTotalShares);

        shares[mintTo] = shares[mintTo].add(newTotalShares);

        //as esAvax is rebasable so there is no implicit transfer event
        //these conditions could result in a infinite amount of events
    }

    //only used when dealing with exploits/withdrawls
    //tokens will be minted to the victims address
    //and then burned from the perpatrators address
    function _burnShares(address burnFrom, uint256 amount)
        internal
        returns (bool burnSuccessful)
    {
        require(burnFrom != address(0), "Will NO BURN  THE ZERO ADDRESS");

        uint256 addressShares = shares[burnFrom];
        require(amount <= addressShares, "BURN MORE THAN WALLET HOLDS");

        uint256 newTotalShares = _getTotalShares().sub(amount);
        TOTAL_AVAX_SHARES.setStorageUint256(newTotalShares);

        shares[burnFrom] = addressShares.sub(amount);
        return burnSuccessful = true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal override whenNotPaused {
        require(owner != address(0), "NO APPROVAL FROM ZERO ADDRESS");
        require(spender != address(0), "NO APPROVAL FROM ZERO ADDRESS");

        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _sharesOf(address account) internal view returns (uint256) {
        return shares[account];
    }

    function _transfer(
        address sender,
        address reciver,
        uint256 amount
    ) internal override {
        uint256 sharesToTransfer = getSharesFromStakedAvax(amount);
        _transferShares(sender, reciver, sharesToTransfer);
        emit Transfer(sender, reciver, amount);
    }

    function _transferShares(
        address sender,
        address receiver,
        uint256 amountShares
    ) internal whenNotPaused {
        require(sender != address(0), "NO TRANSFER FROM THE ZERO ADDRESS");
        require(receiver != address(0), "NO TRANSFER TO THE ZERO ADDRESS");
        require(sender != receiver, "NO SELF TRANSFER");

        uint256 currentSenderShares = shares[sender];
        require(
            amountShares <= currentSenderShares,
            "TRANSFER EXCEEDS BALANCE"
        );
        //keeps a tally for data bragging rights
        if(shares[receiver] == 0){
            stakeAccts = stakeAccts.add(1);
        }

        shares[sender] = currentSenderShares.sub(amountShares);
        shares[receiver] = shares[receiver].add(amountShares);

        if(shares[sender] == 0){
            stakeAccts = stakeAccts.sub(1);
        }
    }

    function _getTotalShares() internal view returns (uint256) {
        return TOTAL_AVAX_SHARES.getStorageUint256();
    }


    function _getTotalAvaxPooled() internal view virtual returns (uint256){}


    function _pauseParent() internal{

        _pause();
    }


    function _resume() internal{

        _unpause();
    }
}