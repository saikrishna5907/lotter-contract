// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract InteractionsTest {
    function getBalance(address _address) public view returns (uint256) {
        return _address.balance;
    }
}
