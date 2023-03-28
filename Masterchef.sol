// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./sushitoken.sol";

contract MasterChef {
    struct UserInfo {
        uint256 amount; // 用户 iptoken 的数量
        uint256 rewardDebt; // 用户不可以领取的点位
    }

    // 流动池，可以创建多个流动池
    struct PoolInfo {
        SushiToken lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
    }

    SushiToken public sushi;
    uint256 public rewardPerBlock;
    uint256 public totalAllocPoint;
    uint256 public startBlock;
    uint256 public endBlock;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(SushiToken _sushi) {
        sushi = _sushi;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // 添加一个质押池，一个质押池 100 个分配点位，并且不能添加已经添加过的 lptoken
    function addPool(SushiToken _lpToken) external {
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            require(poolInfo[pid].lpToken != _lpToken, "Pool already added");
        }
        totalAllocPoint = 100;

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: totalAllocPoint,
                lastRewardBlock: block.number > startBlock
                    ? block.number
                    : startBlock,
                accRewardPerShare: 0
            })
        );
    }

    function setPool(uint256 _pid, uint256 _allocPoint) external {
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function getPendingReward(
        address _user,
        uint256 _pid
    ) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 reward = (multiplier * rewardPerBlock * pool.allocPoint) /
                totalAllocPoint;
            accRewardPerShare += (reward * 1e12) / lpSupply;
        }
        return (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
    }

    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 reward = (multiplier * rewardPerBlock * pool.allocPoint) /
            totalAllocPoint;
        sushi.mint(address(this), reward);
        pool.accRewardPerShare += (reward * 1e12) / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    // 追加质押
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        // 如果之前有质押，那么先进行结算
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accRewardPerShare) /
                1e12 -
                user.rewardDebt;
            sushi.transfer(msg.sender, pending);
        }
        // 把用户的 lptoken 转移到 MasterChef
        pool.lpToken.transferFrom(msg.sender, address(this), _amount);
        user.amount += _amount;

        // 更新不可领取的部分
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // 解除质押
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "Withdraw: insufficient balance");
        updatePool(_pid);
        uint256 pending = (user.amount * pool.accRewardPerShare) /
            1e12 -
            user.rewardDebt;
        sushi.transfer(msg.sender, pending);
        user.amount -= _amount;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;
        pool.lpToken.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.transfer(msg.sender, user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }
}