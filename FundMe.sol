// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// 1 创建收款函数
// 2 记录投资人并查看
// 3 在锁定期内，达到目标值，生产商可以收款
// 4 在锁定期内，未达到目标值，投资人可以退款
contract FundMe {
    mapping(address => uint256) public fundsToAmount;
    // 最少投资3usd
    uint256 constant MINI_VALUE = 3 * 10**18;
    // 目标值为10usd
    uint256 constant TARGET = 10 * 10 ** 18;
    AggregatorV3Interface internal dataFeed;

    address public  owner;

    constructor() {
        dataFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        // 合约的部署者即管理员
        owner = msg.sender;
    }

    function fund() external payable {
        require(convertEthToUsd(msg.value) >= MINI_VALUE, "send more ETH");
        fundsToAmount[msg.sender] = msg.value;
    }

    
    /**
     * Returns the latest answer.
     */
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    function convertEthToUsd(uint256 ethAmount) internal view returns (uint256) {
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer());
        // ETH/USD precision = 10 ** 8;
        // x / ETH precision = 10 ** 18;
        return ethAmount * ethPrice / (10 ** 8);
    }

    function transferOwner(address newOwner) public {
        require(msg.sender == owner, "this function only can be called by owner");
        owner = newOwner;
    }

    function getFund() public{
        // address(this).balance 当前合约的余额
        require(convertEthToUsd(address(this).balance) >= TARGET, "target is not reached");
        require(msg.sender == owner, "this function only can be called by owner");
        // transfer: transfer ETH and revert if tx failed
        // payable(msg.sender).transfer(address(this).balance);
        // send: transfer ETH and return false if failed
        // bool success = payable(msg.sender).send(address(this).balance);
        // require(success, "failed to getFund");
        // call: transfer ETH with data return value of function and bool
        bool success;
        (success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "failed to tx");
    }

    function refund() external {
        require(convertEthToUsd(address(this).balance) < TARGET, "target is reached");
        require(fundsToAmount[msg.sender] != 0, "there is no fund for you");
        bool success;
        (success, ) = payable(msg.sender).call{value: fundsToAmount[msg.sender]}("");
        require(success, "failed to tx");
    }
}
