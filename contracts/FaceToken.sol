pragma solidity ^0.4.23;

import "./StandardToken.sol";

contract FaceToken is StandardToken {

  // Token metadata
  string public constant name = "FaceWorths Token";
  string public constant symbol = "FACE";
  uint256 public constant decimals = 6;
  address public vault;

  constructor() public {
    vault = msg.sender;
    totalSupply_ = (10**9) * 10**decimals; // 1 billion
    balances[vault] = totalSupply_;
    emit Mint(vault, balances[vault]);
  }

  event Mint(address indexed to, uint256 amount);
}
