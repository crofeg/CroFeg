//SPDX-License-Identifier: Unlicensed

pragma solidity ^0.7.4;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

abstract contract Auth {
    address internal owner;
    mapping (address => bool) internal authorizations;

    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
    }

    /**
     * Function modifier to require caller to be contract owner
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    /**
     * Function modifier to require caller to be authorized
     */
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED"); _;
    }

    /**
     * Authorize address. Owner only
     */
    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }

    /**
     * Remove address' authorization. Owner only
     */
    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
    }

    /**
     * Check if address is owner
     */
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /**
     * Return address' authorization status
     */
    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    /**
     * Transfer ownership to new address. Caller must be owner. Leaves old owner authorized
     */
    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    event OwnershipTransferred(address owner);
}

contract CROFEG is IBEP20, Auth {
    
    using SafeMath for uint256;

    string constant _name = "CROFEG";
    string constant _symbol = "CROFEG";
    uint8 constant _decimals = 18;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;
    address routerAddress = 0x145677FC4d9b8F19B5D56d1820c48e0443049a30; //MMF router

    uint256 _totalSupply = 100000000 * (10 ** _decimals);
    uint256 public _maxTxAmount = 500000 * (10 ** _decimals);
    
    bool public tradingIsEnabled = false; 

    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) public isFeeExempt;
    mapping (address => bool) public isTxLimitExempt;

    uint256 public marketingFee = 50;
    uint256 public liquidityFee  = 25;
    uint256 public dev1Fee = 5;
    uint256 public dev2Fee = 5;
    uint256 public dev3Fee = 5;
    uint256 public dev4Fee = 5;
    uint256 public dev5Fee = 5;
    uint256 public extraFeeOnSell = 150;
    uint256 public feeDenominator = 1000;
    uint256 public totalFees     = marketingFee + liquidityFee + dev1Fee + dev2Fee + dev3Fee + dev4Fee + dev5Fee;
    uint256 public totalFeesIfSelling = totalFees + extraFeeOnSell;


    address private devWallet1 = 0xCe299DB33eeE09627D2bd0D15a14b635Ca144947;
    address private devWallet2 = 0x510906F4B9eA97892c605E4FaCA7e63f20b946b1;
    address private devWallet3 = 0x3972adC1fCD26e9b02EbF83ba2a827774cb6e891;
    address private devWallet4 = 0x27f30eC5CcF74dAa46a5ca3dCDc30980E366c2f0;
    address private devWallet5 = 0x1b940e8C05c974250C461ab2E9a9c9AeC00531F0;

    address public marketingWallet = 0x4042A241e86EA60C8ea1708f3dC93f5903AA16C3;

    IDEXRouter public router;
    address public pair;

    // max wallet tools
    mapping(address => bool) private _isExcludedFromMaxWallet;
    bool private enableMaxWallet = true;
    uint256 private maxWalletRate = 10;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public swapAndLiquifyByLimitOnly = false;

    uint256 public swapThreshold = _totalSupply / 1000;
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor () Auth(msg.sender) {
        
        router = IDEXRouter(routerAddress);
        pair = IDEXFactory(router.factory()).createPair(router.WETH(), address(this));
        _allowances[address(this)][address(router)] = uint256(-1);

        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;

        isTxLimitExempt[msg.sender] = true;
        isTxLimitExempt[pair] = true;

        // exclude from max wallet limit
        _isExcludedFromMaxWallet[msg.sender] = true;
        _isExcludedFromMaxWallet[address(0)] = true;
        _isExcludedFromMaxWallet[address(this)] = true;
        _isExcludedFromMaxWallet[DEAD] = true;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable { }

    function name() external pure override returns (string memory) { return _name; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function getOwner() external view override returns (address) { return owner; }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, uint256(-1));
    }

    function enableTrading() external onlyOwner {
        require(!tradingIsEnabled, "Trading is already enabled");
        tradingIsEnabled = true;
    }
    
    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }

    function changeTxLimit(uint256 newLimit) external authorized {
        _maxTxAmount = newLimit;
    }

    function setIsTxLimitExempt(address holder, bool exempt) external authorized {
        isTxLimitExempt[holder] = exempt;
    }

    function setFeeRates(uint256 _marketingFee, uint256 _liquidityFee, uint256 _dev1Fee, uint256 _dev2Fee, uint256 _dev3Fee, uint256 _dev4Fee, uint256 _dev5Fee, uint256 _extraFeeOnSell, uint256 _feeDenominator) public onlyOwner {
            marketingFee = _marketingFee;
            liquidityFee = _liquidityFee;
            dev1Fee = _dev1Fee;
            dev2Fee = _dev2Fee;
            dev3Fee = _dev3Fee;
            dev4Fee = _dev4Fee;
            dev5Fee = _dev5Fee;
            feeDenominator = _feeDenominator;
            extraFeeOnSell = _extraFeeOnSell;
            totalFees = _marketingFee + _liquidityFee + _dev1Fee + _dev2Fee + _dev3Fee + _dev4Fee + _dev5Fee;
            totalFeesIfSelling = totalFees + extraFeeOnSell;

            require(totalFees <= _feeDenominator / 3, "max 33%");
    }

    function setDevWallets(address wallet1, address wallet2, address wallet3, address wallet4, address wallet5) external onlyOwner{
        devWallet1 = wallet1;
        devWallet2 = wallet2;
        devWallet3 = wallet3;
        devWallet4 = wallet4;
        devWallet5 = wallet5;
    }

    function setMarketingWallet(address payable wallet) external onlyOwner{
        marketingWallet = wallet;
    }

    function isExcludedFromMaxWallet(address account) public view returns(bool) {
        return _isExcludedFromMaxWallet[account];
    }

    function maxWalletAmount() public view returns (uint256) {
        return getCirculatingSupply().mul(maxWalletRate).div(1000);
    }

    function setmaxWalletAmountRateDenominator1000(uint256 _val) public onlyOwner {
        require(_val > 9, "Max wallet percentage cannot be lower than 1%");
        maxWalletRate = _val;
    }

    function setExcludeFromMaxWallet(address account, bool exclude) public onlyOwner {
          _isExcludedFromMaxWallet[account] = exclude;
    }

    function setenableMaxWallet(bool _val) public onlyOwner {
        enableMaxWallet = _val;
    }

    function changeSwapBackSettings(bool enableSwapBack, uint256 newSwapBackLimit) external authorized {
        swapAndLiquifyEnabled  = enableSwapBack;
        swapThreshold = newSwapBackLimit;
    }
    
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        
        if(_allowances[sender][msg.sender] != uint256(-1)){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }
        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(tradingIsEnabled || (isFeeExempt[sender] || isFeeExempt[recipient]), "Trading is disabled");
        require(amount <= _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");

        if(inSwapAndLiquify){ return _basicTransfer(sender, recipient, amount); }

        if (enableMaxWallet && maxWalletAmount() > 0) {
            if (
                _isExcludedFromMaxWallet[sender] == false
                && _isExcludedFromMaxWallet[recipient] == false &&
                recipient != pair
            ) {
                uint balance  = balanceOf(recipient);
                require(balance + amount <= maxWalletAmount(), "MaxWallet: Transfer amount exceeds the maxWalletAmount");
            }
        }

        if(msg.sender != pair && !inSwapAndLiquify && swapAndLiquifyEnabled && _balances[address(this)] >= swapThreshold){ swapBack(); }

        bool takeFee = !inSwapAndLiquify;

        //Exchange tokens
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        if(isFeeExempt[sender] || isFeeExempt[recipient]) {
            takeFee = false;
        }
        // no fee for wallet to wallet transfers
        if(sender != pair && recipient != pair) {
            takeFee = false;
        }
        
        uint256 finalAmount = amount;

        if(takeFee) {
            finalAmount = takeFees(sender, recipient, amount);
        }

        _balances[recipient] = _balances[recipient].add(finalAmount);

        emit Transfer(sender, recipient, finalAmount);
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function takeFees(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 feeApplicable = pair == recipient ? totalFeesIfSelling : totalFees;
        uint256 feeAmount = amount.mul(feeApplicable).div(feeDenominator);

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }

    function swapBack() internal lockTheSwap {
        
        uint256 tokensToLiquify = _balances[address(this)];
        uint256 amountToLiquify = tokensToLiquify.mul(liquidityFee).div(totalFees).div(2);
        uint256 amountToSwap = tokensToLiquify.sub(amountToLiquify);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountCRO = address(this).balance;

        uint256 totalCroFee = totalFees.sub(liquidityFee.div(2));
        
        uint256 amountCroLiquidity = amountCRO.mul(liquidityFee).div(totalCroFee).div(2);
        uint256 amountCroMarketing = amountCRO * marketingFee / totalCroFee;
        uint256 amountCroDev1 = amountCRO * dev1Fee / totalCroFee;
        uint256 amountCroDev2 = amountCRO * dev2Fee / totalCroFee;
        uint256 amountCroDev3 = amountCRO * dev3Fee / totalCroFee;
        uint256 amountCroDev4 = amountCRO * dev4Fee / totalCroFee;
        uint256 amountCroDev5 = amountCRO * dev5Fee / totalCroFee;     

        if(marketingFee > 0){
            payable(marketingWallet).transfer(amountCroMarketing);
        }
        if(dev1Fee > 0){
            payable(devWallet1).transfer(amountCroDev1);
        }
        if(dev2Fee > 0){
            payable(devWallet2).transfer(amountCroDev2);
        }
        if(dev3Fee > 0){
            payable(devWallet3).transfer(amountCroDev3);
        }
        if(dev4Fee > 0){
            payable(devWallet4).transfer(amountCroDev4);
        }
        if(dev5Fee > 0){
            payable(devWallet5).transfer(amountCroDev5);
        }

        if(amountToLiquify > 0){
            router.addLiquidityETH{value: amountCroLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                DEAD,
                block.timestamp
            );
            emit AutoLiquify(amountCroLiquidity, amountToLiquify);
        }
    }

    event AutoLiquify(uint256 amountBNB, uint256 amountBOG);

}
