// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MyToken
 * @dev 实现ERC20标准的代币合约
 * @author xuchenyao
 * 
 * 功能说明：
 * - 标准ERC20功能：余额查询、转账、授权转账
 * - 增发功能：合约所有者可以增发代币
 * - 事件记录：所有转账和授权操作都会触发事件
 * - 安全检查：防止溢出、零地址检查等
 */
contract MyToken {
    
    // ===== 代币基本信息 =====
    
    /// @dev 代币名称
    string public name;
    
    /// @dev 代币符号
    string public symbol;
    
    /// @dev 代币精度（小数位数）
    uint8 public decimals;
    
    /// @dev 代币总供应量
    uint256 public totalSupply;
    
    /// @dev 合约所有者地址
    address public owner;
    
    // ===== 存储映射 =====
    
    /// @dev 账户余额映射：地址 => 余额
    mapping(address => uint256) private _balances;
    
    /// @dev 授权映射：所有者地址 => (被授权地址 => 授权金额)
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // ===== 事件定义 =====
    
    /**
     * @dev 转账事件
     * @param from 发送方地址
     * @param to 接收方地址  
     * @param value 转账金额
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev 授权事件
     * @param owner 授权方地址
     * @param spender 被授权方地址
     * @param value 授权金额
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @dev 增发事件
     * @param to 接收增发代币的地址
     * @param amount 增发数量
     */
    event Mint(address indexed to, uint256 amount);
    
    /**
     * @dev 所有权转移事件
     * @param previousOwner 原所有者
     * @param newOwner 新所有者
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // ===== 修饰器 =====
    
    /**
     * @dev 只有所有者可以调用的修饰器
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "MyToken: caller is not the owner");
        _;
    }
    
    /**
     * @dev 检查地址不为零地址的修饰器
     * @param account 要检查的地址
     */
    modifier validAddress(address account) {
        require(account != address(0), "MyToken: address cannot be zero");
        _;
    }
    
    // ===== 构造函数 =====
    
    /**
     * @dev 构造函数
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _decimals 代币精度
     * @param _initialSupply 初始供应量
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        
        // 初始供应量分配给合约部署者
        uint256 _totalSupply = _initialSupply * 10**_decimals;
        totalSupply = _totalSupply;
        _balances[msg.sender] = _totalSupply;
        
        // 触发转账事件（从零地址到部署者）
        emit Transfer(address(0), msg.sender, _totalSupply);
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    // ===== ERC20标准函数 =====
    
    /**
     * @dev 查询账户余额
     * @param account 要查询的账户地址
     * @return 账户余额
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev 转账函数
     * @param to 接收方地址
     * @param amount 转账金额
     * @return 是否转账成功
     */
    function transfer(address to, uint256 amount) 
        public 
        validAddress(to) 
        returns (bool) 
    {
        address from = msg.sender;
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev 查询授权金额
     * @param tokenOwner 授权方地址
     * @param spender 被授权方地址
     * @return 授权金额
     */
    function allowance(address tokenOwner, address spender) 
        public 
        view 
        returns (uint256) 
    {
        return _allowances[tokenOwner][spender];
    }
    
    /**
     * @dev 授权函数
     * @param spender 被授权方地址
     * @param amount 授权金额
     * @return 是否授权成功
     */
    function approve(address spender, uint256 amount) 
        public 
        validAddress(spender) 
        returns (bool) 
    {
        address tokenOwner = msg.sender;
        _approve(tokenOwner, spender, amount);
        return true;
    }
    
    /**
     * @dev 代扣转账函数
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amount 转账金额
     * @return 是否转账成功
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        validAddress(from) 
        validAddress(to) 
        returns (bool) 
    {
        address spender = msg.sender;
        
        // 检查并更新授权额度
        _spendAllowance(from, spender, amount);
        
        // 执行转账
        _transfer(from, to, amount);
        
        return true;
    }
    
    // ===== 增发功能 =====
    
    /**
     * @dev 增发代币（只有所有者可以调用）
     * @param to 接收增发代币的地址
     * @param amount 增发数量
     */
    function mint(address to, uint256 amount) 
        public 
        onlyOwner 
        validAddress(to) 
    {
        require(amount > 0, "MyToken: mint amount must be greater than 0");
        
        // 增加总供应量
        totalSupply += amount;
        
        // 增加接收方余额
        _balances[to] += amount;
        
        // 触发转账事件（从零地址增发）
        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }
    
    // ===== 所有权管理 =====
    
    /**
     * @dev 转移合约所有权
     * @param newOwner 新所有者地址
     */
    function transferOwnership(address newOwner) 
        public 
        onlyOwner 
        validAddress(newOwner) 
    {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    /**
     * @dev 放弃合约所有权
     */
    function renounceOwnership() public onlyOwner {
        address oldOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }
    
    // ===== 内部函数 =====
    
    /**
     * @dev 内部转账函数
     * @param from 发送方地址
     * @param to 接收方地址
     * @param amount 转账金额
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "MyToken: transfer from the zero address");
        require(to != address(0), "MyToken: transfer to the zero address");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "MyToken: transfer amount exceeds balance");
        
        // 执行转账
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev 内部授权函数
     * @param tokenOwner 授权方地址
     * @param spender 被授权方地址
     * @param amount 授权金额
     */
    function _approve(address tokenOwner, address spender, uint256 amount) internal {
        require(tokenOwner != address(0), "MyToken: approve from the zero address");
        require(spender != address(0), "MyToken: approve to the zero address");
        
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }
    
    /**
     * @dev 消费授权额度
     * @param tokenOwner 授权方地址
     * @param spender 被授权方地址
     * @param amount 要消费的金额
     */
    function _spendAllowance(address tokenOwner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(tokenOwner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "MyToken: insufficient allowance");
            unchecked {
                _approve(tokenOwner, spender, currentAllowance - amount);
            }
        }
    }
    
    // ===== 辅助函数 =====
    
    /**
     * @dev 增加授权额度
     * @param spender 被授权方地址
     * @param addedValue 增加的授权金额
     * @return 是否成功
     */
    function increaseAllowance(address spender, uint256 addedValue) 
        public 
        validAddress(spender) 
        returns (bool) 
    {
        address tokenOwner = msg.sender;
        _approve(tokenOwner, spender, allowance(tokenOwner, spender) + addedValue);
        return true;
    }
    
    /**
     * @dev 减少授权额度
     * @param spender 被授权方地址
     * @param subtractedValue 减少的授权金额
     * @return 是否成功
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) 
        public 
        validAddress(spender) 
        returns (bool) 
    {
        address tokenOwner = msg.sender;
        uint256 currentAllowance = allowance(tokenOwner, spender);
        require(currentAllowance >= subtractedValue, "MyToken: decreased allowance below zero");
        unchecked {
            _approve(tokenOwner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
    
    /**
     * @dev 批量转账
     * @param recipients 接收方地址数组
     * @param amounts 转账金额数组
     * @return 是否全部转账成功
     */
    function batchTransfer(address[] memory recipients, uint256[] memory amounts) 
        public 
        returns (bool) 
    {
        require(recipients.length == amounts.length, "MyToken: arrays length mismatch");
        require(recipients.length > 0, "MyToken: empty arrays");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], amounts[i]);
        }
        
        return true;
    }
}
