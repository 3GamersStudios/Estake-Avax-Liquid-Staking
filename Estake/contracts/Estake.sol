// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./unstructured-storage.sol";
contract Estake is PausableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, ERC20Upgradeable{

    using SafeMath for uint;
    using SafeMath for uint256;
    using UnstructuredStorage for bytes32;

    
    mapping(address => uint256) private shares;

    mapping(address => mapping(address => uint256)) private allowances;

        //wallets staked
    uint256 stakeAccts;

    uint256 private _totalSupply;

    uint public DebondagePeriod;
    uint public WithdrawWindow;

    
    mapping(address => withdrawRequest[]) public acctWithdrawRequestArray;
    mapping(address => uint) public acctSharesHeld;

    struct withdrawRequest{
        uint requestTime;

        uint withdrawAmount;
    }
    
    struct outstandingReceipt{
        uint withdrawlTime;

        uint amountOwed;
    }

    //array of outstanding withdrawl receipts-mapped to addresses incase delegator wallet changes
    mapping(address => outstandingReceipt[]) public outstandingWithdrawlReciepts;


    bytes32 constant public AdminRole = keccak256("DEFAULT_ADMIN");
    bytes32 constant public RewardsRole = keccak256("REWARDS_ROLE");
    bytes32 constant public DepositRole = keccak256("DEPOSIT_ROLE");
    bytes32 constant public WithdrawRole = keccak256("WITHDRAW_ROLE");
    bytes32 constant public PauseRole = keccak256("PAUSE_ROLE");
    bytes32 constant public ResumeRole = keccak256("RESUME_ROLE");

    bytes32 internal constant TOTAL_AVAX_SHARES = keccak256("estake.esAvax.totalShares");
    bytes32 internal constant transientAvax = keccak256("TRANSIENT_AVAX");
    bytes32 internal constant delegatedAvax = keccak256("DELEGATED_AVAX");
    bytes32 internal constant totalControledAvax = keccak256("CONTROLLED_AVAX");
    bytes32 internal constant avaxLockedForWithdrawl = keccak256("AVAILABLE_AVAX_WITHDRAWL");

    event Submitted(address indexed sender, uint256 amount);
    event WithdrawRequested(address withdrawAcct, uint256 amountAvax);
    event Withdrawn(address withdrawee, uint timeRequested, uint amountAvax);
    event DebondageUpdated(uint oldPeriod, uint newPeriod);
    event WithdrawUpdated(uint oldPeriod, uint newPeriod);
    event UpdatedDeposit(address depositeer, uint256 amountDeposited);
    event DelegationWithdrawl(address delegator, uint256 amount);
    event WithdrawRequestCancelled(address cancellor, uint timeRequested, uint SharesCancelled);

    function initialize( uint _withdrawWindow, uint _debondageWindow) public initializer {
        __ERC20_init("Estake", "esAVAX");

        _setupRole(AdminRole, msg.sender);

        WithdrawWindow = _withdrawWindow;
        emit WithdrawUpdated(0, _withdrawWindow);

        DebondagePeriod = _debondageWindow;
        emit DebondageUpdated(0, _debondageWindow);
    }

        //returns name when queried
    function name() public pure override returns (string memory) {
        return "EstakedAvax";
    }
    //returns decimal count to caculate shares to avax
    function decimals() public pure override returns (uint8) {
        return 18;
    }
    //returns shortened name used on cexs and the web
    function symbol() public pure override returns (string memory) {
        return "esAVAX";
    }


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

    function stake() external payable returns (uint256){
        return _stake();
    }

    function withdraw( uint256 amountShares) external {
        return RequestWithdrawl(amountShares);
    }

    function getSupply() public view returns (uint256){
        return _totalSupply;
    }

    function getAcctRequests(address acct) external view returns (uint256){
        return acctWithdrawRequestArray[acct].length;
    }

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

        if(shares[mintTo] == 0){
            stakeAccts = stakeAccts.add(1);
        }
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

        if(shares[burnFrom] == 0){
            stakeAccts = stakeAccts.sub(1);
        }
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



    function _pauseParent() internal{

        _pause();
    }


    function _resume() internal{

        _unpause();
    }

    function retrieveAcctRequestesEnumerated(address acct, uint256 start, uint256 end) external view returns (withdrawRequest[] memory){
        require(start < acctWithdrawRequestArray[acct].length, "INDEX OUT OF BOUNDS");
        require(start < end, "START MUST BE BEFORE END");

        if (start > acctWithdrawRequestArray[acct].length) {
            start = acctWithdrawRequestArray[acct].length;
        }        

        withdrawRequest[] memory EnumedToReturn = new withdrawRequest[](end.sub(start));

        for(uint i=0; i < end.sub(start); i++){
            EnumedToReturn[i] = acctWithdrawRequestArray[acct][start.add(i)];
        }

        return(EnumedToReturn);
    }

    function _getTotalAvaxPooled() internal view returns(uint256){
        //to deploy make this actually run a caculation
        uint256 Avax = transientAvax.getStorageUint256();
        return Avax;
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
        _emitTransferAfterMint(sender, sharesToMint);

        return sharesToMint;
    }
    //@dev only can withdraw when avax in contract is enough
    function RequestWithdrawl(uint256 amountShares) internal nonReentrant whenNotPaused {
        require(amountShares > 0, "CANNOT_WITHDRAW_ZERO");
        require(amountShares <= sharesOf(msg.sender), "WITHDRAW_EXCEEDS_OWNED_SHARES");
        
        acctSharesHeld[msg.sender] = acctSharesHeld[msg.sender].add(amountShares);
        _transferShares(msg.sender, address(this), amountShares);

        acctWithdrawRequestArray[msg.sender].push(withdrawRequest(block.timestamp, amountShares));

        avaxLockedForWithdrawl.setStorageUint256(avaxLockedForWithdrawl.getStorageUint256().add(amountShares));

        emit WithdrawRequested(msg.sender, getPooledAvaxfromShares(amountShares));
    }

    function _cancelWithdrawRequest(uint withdrawIndex) internal whenNotPaused {
        require(withdrawIndex < acctWithdrawRequestArray[msg.sender].length, "INDEX OUT OF RANGE");

        withdrawRequest memory request = acctWithdrawRequestArray[msg.sender][withdrawIndex];

        require( !_isExpiredRequest(request), "NULL REQUEST IS EXPIRED");

        uint sharesAmount = request.withdrawAmount;
        uint withdrawRequestedAt = request.requestTime;

        if(withdrawIndex != acctWithdrawRequestArray[msg.sender].length -1 ){
            acctWithdrawRequestArray[msg.sender][withdrawIndex] = acctWithdrawRequestArray[msg.sender][acctWithdrawRequestArray[msg.sender].length -1];
        }

        acctWithdrawRequestArray[msg.sender].pop();

        acctSharesHeld[msg.sender] = acctSharesHeld[msg.sender].sub(sharesAmount);
        _transferShares(address(this), msg.sender, sharesAmount);

        avaxLockedForWithdrawl.setStorageUint256(avaxLockedForWithdrawl.getStorageUint256().sub(sharesAmount));

        emit WithdrawRequestCancelled(msg.sender, withdrawRequestedAt, sharesAmount);

    }

    function _withdrawStake(uint withdrawIndex) internal whenNotPaused{
        require (withdrawIndex < acctWithdrawRequestArray[msg.sender].length, "INDEX OUT OF BOUNDS");

        withdrawRequest memory request = acctWithdrawRequestArray[msg.sender][withdrawIndex];

        require(_isWithinClaimWindow(request), "REQUEST NOT IN CLAIM WINDOW");

        uint256 sharesAmount = request.withdrawAmount;
        uint256 requestTime = request.requestTime;

        acctSharesHeld[msg.sender] = acctSharesHeld[msg.sender].sub(sharesAmount);
        _burnShares(address(this), sharesAmount);

        transientAvax.setStorageUint256(transientAvax.getStorageUint256().sub(sharesAmount));
        _recaculateAvax();

        acctWithdrawRequestArray[msg.sender][withdrawIndex] = acctWithdrawRequestArray[msg.sender][acctWithdrawRequestArray[msg.sender].length.sub(1)];
        acctWithdrawRequestArray[msg.sender].pop();

        (bool success,) = msg.sender.call{value: sharesAmount}("");
        require(success, "AVAX WITHDRAWL FAILED");


        emit Withdrawn(msg.sender, requestTime, sharesAmount);
    }

    function _isWithinDebondagePeriod(withdrawRequest memory request) internal view returns (bool){
        return request.requestTime.add(DebondagePeriod) >= block.timestamp;
    }

    function _isWithinClaimWindow(withdrawRequest memory request) internal view returns (bool) {
        return !_isWithinDebondagePeriod(request) && request.requestTime.add(DebondagePeriod).add(WithdrawWindow) >= block.timestamp;
    }

    function _isExpiredRequest(withdrawRequest memory request) internal view returns (bool){
        return request.requestTime.add(DebondagePeriod).add(WithdrawWindow) < block.timestamp;
    }


    function _submitted(address sender, uint256 amount) internal {
        transientAvax.setStorageUint256(transientAvax.getStorageUint256().add(amount));
        _recaculateAvax();
        

        emit Submitted(sender, amount);
    }

    function _recaculateAvax() internal {
        totalControledAvax.setStorageUint256(delegatedAvax.getStorageUint256().add(transientAvax.getStorageUint256()));
    }

    function _emitTransferAfterMint(address receiver, uint256 amount) internal{
        emit Transfer(address(0), receiver, getPooledAvaxfromShares(amount));
    }

    function pause() external{
        require(hasRole(PauseRole, msg.sender), "MHM NOT HAPPENING");

        _pauseParent();
    }


    function resume() external{
        require(hasRole(ResumeRole, msg.sender), "HA NICE TRY BUD");

        _resume();
    }

    function withdrawForDelegation(uint256 avaxAmount) external nonReentrant{
        require(hasRole(WithdrawRole, msg.sender), "ADDRESS IS WRONG MY FRIEND");

        outstandingWithdrawlReciepts[msg.sender].push(outstandingReceipt(block.timestamp, avaxAmount));
        delegatedAvax.setStorageUint256(delegatedAvax.getStorageUint256().add(avaxAmount));
        transientAvax.setStorageUint256(transientAvax.getStorageUint256().sub(avaxAmount));

        (bool success,) = msg.sender.call{value: avaxAmount}("");
        require(success, "AVAX TRANSFER FAILED");

        emit DelegationWithdrawl(msg.sender, avaxAmount);
    }

    function accrueRewards(uint256 amount) external nonReentrant{
        require(hasRole(RewardsRole, msg.sender),"NEED A WALLET TO REBASE BRO");

        transientAvax.setStorageUint256(transientAvax.getStorageUint256().add(amount));
        _recaculateAvax();

    }

    function getAvailableAvaxtoDelegate() external view returns (uint sharesAvailable){
        require(hasRole(DepositRole, msg.sender), "MISSNG REQUIRED ROLE");
        sharesAvailable = transientAvax.getStorageUint256().sub(avaxLockedForWithdrawl.getStorageUint256());
    }

    //deposit Avax from staking without shares
    function depositToCloseReciepts(uint256 receiptIndex) external payable{
        require(hasRole(DepositRole, msg.sender), "MAYBE TMRW??");
        require(msg.value > 0, "NO VALUE");
        require(msg.value == outstandingWithdrawlReciepts[msg.sender][receiptIndex].amountOwed, "VALUE DOES NOT EQUAL AMOUNT OWED");

        outstandingWithdrawlReciepts[msg.sender][receiptIndex] = outstandingWithdrawlReciepts[msg.sender][outstandingWithdrawlReciepts[msg.sender].length.sub(1)];
        outstandingWithdrawlReciepts[msg.sender].pop();

        delegatedAvax.setStorageUint256(delegatedAvax.getStorageUint256().sub(msg.value));
        transientAvax.setStorageUint256(transientAvax.getStorageUint256().add(msg.value));

        emit UpdatedDeposit(msg.sender, msg.value);
    }

    function setDebondagePeriod(uint newDebondagePeriod) external {
        require(hasRole(AdminRole, msg.sender), "MAYBE THE WRONG WALLET?");

        uint oldDebondage = DebondagePeriod;
        DebondagePeriod = newDebondagePeriod;

        emit DebondageUpdated(oldDebondage, newDebondagePeriod);
    }

    function setNewWithdrawWindow(uint newWindow) external {
        require(hasRole(AdminRole, msg.sender), "AAAAAND NOPE NICE TRY THO");

        uint oldWithdraw = WithdrawWindow;
        WithdrawWindow = newWindow;

        emit WithdrawUpdated(oldWithdraw, newWindow);
    }

    //ROLES
    


}