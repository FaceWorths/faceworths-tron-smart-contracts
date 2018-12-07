pragma solidity ^0.4.23;

contract FaceToken {

  address public owner;
  uint256 totalSupply_;
  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) internal allowed;

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

  constructor() public {
    owner = msg.sender;
  }

  function totalSupply()
    public
    view
    returns (uint256)
  {
    return totalSupply_;
  }

  function transfer(address _to, uint256 _value)
    public
    returns (bool)
  {
    require(_value <= balances[msg.sender]);
    require(_to != address(0));

    balances[msg.sender] = sub(balances[msg.sender], _value);
    balances[_to] = add(balances[_to], _value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  function balanceOf(address _owner)
    public
    view
    returns (uint256)
  {
    return balances[_owner];
  }

  function transferFrom(address _from, address _to, uint256 _value)
    public
    returns (bool)
  {
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    require(_to != address(0));

    balances[_from] = sub(balances[_from], _value);
    balances[_to] = add(balances[_to], _value);
    allowed[_from][msg.sender] = sub(allowed[_from][msg.sender], _value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  function approve(address _spender, uint256 _value)
    public
    returns (bool)
  {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender)
    public
    view
    returns (uint256)
  {
    return allowed[_owner][_spender];
  }

  function increaseApproval(address _spender, uint256 _addedValue)
    public
    returns (bool)
  {
    allowed[msg.sender][_spender] = add(allowed[msg.sender][_spender], _addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval(address _spender, uint256 _subtractedValue)
    public
    returns (bool)
  {
    uint256 oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue >= oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = sub(oldValue, _subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function sub(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
  {
    assert(b <= a);
    c = a - b;
  }

  function add(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
  {
    c = a + b;
    assert(c >= a);
  }

}
