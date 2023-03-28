// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

interface IBEP20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract SushiToken is IBEP20 {
    string public name = "SushiToken";
    string public symbol = "Sushi";
    uint8 public decimals = 18;
    uint256 public override totalSupply = 0;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;

    address public governance;
    address private _owner;

    modifier onlyOwner() {
        require(_owner == msg.sender, "Is not owner address");
        _;
    }

    constructor() {
        governance = msg.sender;
    }

    function mint(address account, uint256 amount) public onlyOwner {
        require(msg.sender == _owner, "!minter");
        require(account != address(0), "Cannot mint to the zero address");

        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    // 设置 owner 地址
    function transferOwnerShip(address newOwner) public {
        _owner = newOwner;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(amount <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        require(amount <= balances[sender], "Insufficient balance");
        require(
            amount <= allowances[sender][msg.sender],
            "Insufficient allowance"
        );
        balances[sender] -= amount;
        balances[recipient] += amount;
        allowances[sender][msg.sender] -= amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }
}