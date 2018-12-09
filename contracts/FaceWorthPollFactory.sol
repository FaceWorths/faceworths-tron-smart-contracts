pragma solidity ^0.4.23;

import "./Owned.sol";
import "./FaceToken.sol";
import "./SafeMath.sol";

contract FaceWorthPollFactory is Owned {

  using SafeMath for uint256;

  uint8 public constant COMMITTING = 1;
  uint8 public constant REVEALING = 2;
  uint8 public constant CANCELLED = 3;
  uint8 public constant ENDED = 4;

  struct FaceWorthPoll {
    address creator;
    bytes32 faceHash;  // face photo's SHA-256 hash
    uint startingBlock;
    uint commitEndingBlock;
    uint revealEndingBlock;
    uint8 currentStage;

    mapping(address => bytes32) saltedWorthHashBy;
    mapping(address => uint8) worthBy;
    mapping(address => bool) committedBy;
    mapping(address => bool) revealedBy;
    mapping(address => bool) refunded;
    mapping(address => bool) wonBy;
    address[] participants;
    address[] winners;
    uint revealCount;
  }

  uint public stake = 100000000; // every participant stake 100 trx
  uint public minParticipants = 3;
  uint public maxParticipants = 100000;
  uint public winnersPerThousand = 382;   // 1000 * distPercentage / winnersPerThousand must be greater than 100,
  uint public distPercentage = 90; // so that winners prize is greater than the stake
  uint public minBlocksBeforeReveal = 10; // 10 blocks is about 30 seconds
  uint public minBlocksBeforeEnd = 10;
  address public faceTokenAddress;
  uint256 public faceTokenRewardPool;
  uint256 public pollCount;

  mapping(bytes32 => FaceWorthPoll) polls;
  uint oneFace;

  constructor(address _faceTokenAddress) public {
    faceTokenAddress = _faceTokenAddress;
    FaceToken faceToken = FaceToken(faceTokenAddress);
    faceTokenRewardPool = faceToken.totalSupply() * 618 / 1000;
    oneFace = 10 ** faceToken.decimals();
  }

  event FaceWorthPollCreated (
    bytes32 indexed hash,
    address indexed creator,
    uint startingBlock,
    uint commitEndingBlock,
    uint revealEndingBlock
  );

  function createFaceWorthPoll(
    bytes32 _faceHash,
    uint _blocksBeforeReveal,
    uint _blocksBeforeEnd
  )
    public
  {
    require(_blocksBeforeReveal >= minBlocksBeforeReveal);
    require(_blocksBeforeEnd >= minBlocksBeforeEnd);

    bytes32 hash = keccak256(abi.encodePacked(msg.sender, _faceHash, block.number));
    polls[hash].creator = msg.sender;
    polls[hash].faceHash = _faceHash;
    polls[hash].startingBlock = block.number;
    polls[hash].commitEndingBlock = block.number + _blocksBeforeReveal;
    polls[hash].revealEndingBlock = polls[hash].commitEndingBlock + _blocksBeforeEnd;
    polls[hash].currentStage = COMMITTING;
    pollCount++;

    emit FaceWorthPollCreated(
        hash,
        msg.sender,
        block.number,
        polls[hash].commitEndingBlock,
        polls[hash].revealEndingBlock
    );
  }

  function commit(bytes32 _hash, bytes32 _saltedWorthHash) payable external {
    require(!polls[_hash].committedBy[msg.sender]);
    require(polls[_hash].participants.length < maxParticipants);
    require(polls[_hash].currentStage == COMMITTING && msg.value == stake);

    polls[_hash].saltedWorthHashBy[msg.sender] = _saltedWorthHash;
    polls[_hash].committedBy[msg.sender] = true;
    polls[_hash].participants.push(msg.sender);
    if(polls[_hash].participants.length >= maxParticipants) {
      polls[_hash].currentStage = REVEALING;
      emit StageChange(_hash, REVEALING, COMMITTING);
    }
  }

  function reveal(bytes32 _hash, string _salt, uint8 _worth) external {
    require(polls[_hash].committedBy[msg.sender]);
    require(!polls[_hash].revealedBy[msg.sender]);
    require(polls[_hash].currentStage == REVEALING);
    require(_worth >= 0 && _worth <= 100);
    require(polls[_hash].saltedWorthHashBy[msg.sender] == keccak256(abi.encodePacked(concat(_salt, _worth))));

    polls[_hash].worthBy[msg.sender] = _worth;
    polls[_hash].revealedBy[msg.sender] = true;
    polls[_hash].revealCount++;
    emit Reveal(_hash, msg.sender, _worth);
  }

  function cancel(bytes32 _hash) external {
    require(polls[_hash].creator == msg.sender);
    require(polls[_hash].currentStage == COMMITTING);

    polls[_hash].currentStage = CANCELLED;
    emit StageChange(_hash, CANCELLED, COMMITTING);
    refund(_hash);
  }

  // this function should be called every 3 seconds (Tron block time)
  function checkBlockNumber(bytes32 _hash) external {
    if (polls[_hash].currentStage != CANCELLED && polls[_hash].currentStage != ENDED) {
      if (block.number > polls[_hash].commitEndingBlock) {
        if (polls[_hash].participants.length < minParticipants) {
          polls[_hash].currentStage = CANCELLED;
          emit StageChange(_hash, polls[_hash].currentStage, COMMITTING);
          refund(_hash);
        } else if (block.number <= polls[_hash].revealEndingBlock) {
          polls[_hash].currentStage = REVEALING;
          emit StageChange(_hash, REVEALING, COMMITTING);
        } else {
          endPoll(_hash);
        }
      }
    }
  }

  function refund(bytes32 _hash) private {
    require(polls[_hash].currentStage == CANCELLED);
    for (uint i = 0; i < polls[_hash].participants.length; i++) {
      if (!polls[_hash].refunded[polls[_hash].participants[i]]) {
        polls[_hash].refunded[polls[_hash].participants[i]] = true;
        polls[_hash].participants[i].transfer(stake);
        emit Refund(_hash, polls[_hash].participants[i], stake);
      }
    }
  }

  function endPoll(bytes32 _hash) private {
    require(polls[_hash].currentStage != ENDED);
    polls[_hash].currentStage = ENDED;

    if (polls[_hash].revealCount > 0) {
      // sort the participants by their worth from low to high using Counting Sort
      address[] memory sortedParticipants = sortParticipants(_hash);

      uint totalWorth = getTotalWorth(_hash);
      // find turning point where the right gives higher than average FaceWorth and the left lower
      uint turningPoint = getTurningPoint(_hash, totalWorth, sortedParticipants);

      // reverse those who give lower than average but the same FaceWorth so that the earlier participant is closer to the turning point
      if (turningPoint > 0) {
        uint p = turningPoint - 1;
        while (p > 0) {
          uint start = p;
          uint end = p;
          while (end > 0 && polls[_hash].worthBy[sortedParticipants[start]] == polls[_hash].worthBy[sortedParticipants[end - 1]]) {
            end = end - 1;
          }
          if (end > 0) p = end - 1;
          while (start > end) {
            address tmp = sortedParticipants[start];
            sortedParticipants[start] = sortedParticipants[end];
            sortedParticipants[end] = tmp;
            start--;
            end++;
          }
        }
      }

      findWinners(_hash, turningPoint, totalWorth, sortedParticipants);

      distributePrize(_hash);
    }

    rewardFaceTokens(_hash);

    emit StageChange(_hash, ENDED, REVEALING);
  }

  function rewardFaceTokens(bytes32 _hash) private {
    if (faceTokenRewardPool > 0) {
      uint creatorReward = oneFace + oneFace * polls[_hash].participants.length * 382 / 10000;
      if (faceTokenRewardPool < creatorReward) {
        creatorReward = faceTokenRewardPool;
      }
      rewardFaceTokens(polls[_hash].creator, creatorReward);
      if (faceTokenRewardPool > 0) {
        uint participantReward = oneFace * 618 / 1000;
        for (uint i = 0; i < polls[_hash].participants.length; i++) {
          if (!polls[_hash].wonBy[polls[_hash].participants[i]]) {
            if (faceTokenRewardPool < participantReward) {
              rewardFaceTokens(polls[_hash].participants[i], faceTokenRewardPool);
              break;
            } else {
              rewardFaceTokens(polls[_hash].participants[i], participantReward);
            }
          }
        }
      }
    }
  }

  function rewardFaceTokens(address _receiver, uint _value) private {
    faceTokenRewardPool = faceTokenRewardPool.sub(_value);
    FaceToken faceToken = FaceToken(faceTokenAddress);
    faceToken.increaseApproval(_receiver, _value);
  }


  function findWinners(bytes32 _hash, uint _turningPoint, uint _totalWorth, address[] memory _sortedParticipants) private {
    uint numOfWinners = polls[_hash].participants.length * winnersPerThousand / 1000;
    if (numOfWinners > polls[_hash].revealCount) numOfWinners = polls[_hash].revealCount;
    uint index = 0;
    uint leftIndex = _turningPoint;
    uint rightIndex = _turningPoint;
    if (polls[_hash].worthBy[_sortedParticipants[_turningPoint]] * polls[_hash].revealCount == _totalWorth) {
      polls[_hash].winners.push(_sortedParticipants[_turningPoint]);
      polls[_hash].wonBy[polls[_hash].winners[index]] = true;
      index++;
      rightIndex++;
    } else {
      if (leftIndex > 0) leftIndex--;
      else rightIndex++;
    }
    while (index < numOfWinners) {
      uint rightDiff;
      if (rightIndex < _sortedParticipants.length) {
        rightDiff = polls[_hash].worthBy[_sortedParticipants[rightIndex]] * polls[_hash].revealCount - _totalWorth;
      }
      uint leftDiff = _totalWorth - polls[_hash].worthBy[_sortedParticipants[leftIndex]] * polls[_hash].revealCount;

      if (rightIndex < _sortedParticipants.length && rightDiff <= leftDiff) {
        polls[_hash].winners.push(_sortedParticipants[rightIndex]);
        polls[_hash].wonBy[_sortedParticipants[rightIndex]] = true;
        index++;
        rightIndex++;
      } else if (rightIndex >= _sortedParticipants.length || rightIndex < _sortedParticipants.length && rightDiff > leftDiff) {
        polls[_hash].winners.push(_sortedParticipants[leftIndex]);
        polls[_hash].wonBy[_sortedParticipants[leftIndex]] = true;
        index++;
        if (leftIndex > 0) leftIndex--;
        else rightIndex++;
      }
    }
  }

  function distributePrize(bytes32 _hash) private {
    require(polls[_hash].winners.length > 0);
    uint totalPrize = stake * polls[_hash].participants.length * distPercentage / 100;
    uint avgPrize = totalPrize / polls[_hash].winners.length;
    uint minPrize = (avgPrize + 2 * stake) / 3;
    uint step = (avgPrize - minPrize) / (polls[_hash].winners.length / 2);
    uint prize = minPrize;
    for (uint q = polls[_hash].winners.length; q > 0; q--) {
      polls[_hash].winners[q - 1].transfer(prize);
      prize += step;
    }
  }

  function sortParticipants(bytes32 _hash) private view returns (address[]) {
    address[] memory sortedParticipants_ = new address[](polls[_hash].revealCount);
    uint[101] memory count;
    for (uint i = 0; i < 101; i++) {
      count[i] = 0;
    }
    for (uint j = 0; j < polls[_hash].participants.length; j++) {
      if (polls[_hash].revealedBy[polls[_hash].participants[j]]) {
        count[polls[_hash].worthBy[polls[_hash].participants[j]]]++;
      }
    }
    for (uint k = 1; k < 101; k++) {
      count[k] += count[k - 1];
    }
    for (uint m = polls[_hash].participants.length; m > 0; m--) {
      if (polls[_hash].revealedBy[polls[_hash].participants[m - 1]]) {
        sortedParticipants_[count[polls[_hash].worthBy[polls[_hash].participants[m - 1]]] - 1] = polls[_hash].participants[m - 1];
        count[polls[_hash].worthBy[polls[_hash].participants[m - 1]]]--;
      }
    }
    return sortedParticipants_;
  }

  function getTurningPoint(bytes32 _hash, uint _totalWorth, address[] _sortedParticipants) private view returns (uint) {
    uint turningPoint_;
    for (uint i = 0; i < _sortedParticipants.length; i++) {
      if (polls[_hash].worthBy[_sortedParticipants[i]] * polls[_hash].revealCount >= _totalWorth) {
        turningPoint_ = i;
        break;
      }
    }
    return turningPoint_;
  }

  function getTotalWorth(bytes32 _hash) private view returns (uint) {
    uint totalWorth_ = 0;
    for (uint i = 0; i < polls[_hash].participants.length; i++) {
      if (polls[_hash].revealedBy[polls[_hash].participants[i]]) {
        totalWorth_ += polls[_hash].worthBy[polls[_hash].participants[i]];
      }
    }
    return totalWorth_;
  }

  function getStatus(bytes32 _hash) external view
    returns (uint commitTimeLapsed_, uint revealTimeLapsed_, uint8 currentStage_, uint numberOfParticipants_)
  {
    if (block.number >= polls[_hash].commitEndingBlock) commitTimeLapsed_ = 100;
    else {
      uint startingBlock = polls[_hash].startingBlock;
      commitTimeLapsed_ = (block.number - startingBlock) * 100 / (polls[_hash].commitEndingBlock - startingBlock);
    }

    uint commitEndingBlock = polls[_hash].commitEndingBlock;
    uint revealEndingBlock = polls[_hash].revealEndingBlock;
    if (block.number < commitEndingBlock) {
      revealTimeLapsed_ = 0;
    } else if (block.number >= revealEndingBlock) {
      revealTimeLapsed_ = 100;
    } else {
      revealTimeLapsed_ = (block.number - commitEndingBlock - 1) * 100 / (revealEndingBlock - commitEndingBlock - 1);
    }

    currentStage_ = polls[_hash].currentStage;

    numberOfParticipants_ = polls[_hash].participants.length;
  }

  function getCommitTimeElapsed(bytes32 _hash) external view returns (uint) {
    if (block.number >= polls[_hash].commitEndingBlock) return 100;
    else {
      uint startingBlock = polls[_hash].startingBlock;
      return (block.number - startingBlock) * 100 / (polls[_hash].commitEndingBlock - startingBlock);
    }
  }

  function getRevealTimeElapsed(bytes32 _hash) external view returns (uint) {
    uint commitEndingBlock = polls[_hash].commitEndingBlock;
    uint revealEndingBlock = polls[_hash].revealEndingBlock;
    if (block.number < commitEndingBlock) {
      return 0;
    } else if (block.number >= revealEndingBlock) {
      return 100;
    } else {
      return (block.number - commitEndingBlock - 1) * 100 / (revealEndingBlock - commitEndingBlock - 1);
    }
  }

  function getCurrentStage(bytes32 _hash) external view returns (uint8) {
    return polls[_hash].currentStage;
  }

  function getNumberOfParticipants(bytes32 _hash) external view returns (uint) {
    return polls[_hash].participants.length;
  }

  function getParticipants(bytes32 _hash) external view returns (address[]) {
    require(polls[_hash].currentStage != COMMITTING);
    return polls[_hash].participants;
  }

  function getWorthBy(bytes32 _hash, address _who) external view returns (uint8) {
    require(polls[_hash].currentStage == ENDED);
    return polls[_hash].worthBy[_who];
  }

  function getWinners(bytes32 _hash) external view returns (address[]) {
    require(polls[_hash].currentStage == ENDED);
    return polls[_hash].winners;
  }

  function concat(string _str, uint8 _v) private pure returns (string) {
    uint maxLength = 3;
    bytes memory reversed = new bytes(maxLength);
    uint i = 0;
    do {
      uint remainder = _v % 10;
      _v = _v / 10;
      reversed[i++] = byte(48 + remainder);
    }
    while (_v != 0);

    bytes memory concatenated = bytes(_str);
    bytes memory s = new bytes(concatenated.length + i);
    uint j;
    for (j = 0; j < concatenated.length; j++) {
      s[j] = concatenated[j];
    }
    for (j = 0; j < i; j++) {
      s[j + concatenated.length] = reversed[i - 1 - j];
    }
    return string(s);
  }


  function updateStake(uint _stake) external onlyOwner {
    require(_stake != stake);
    uint oldStake = stake;
    stake = _stake;
    emit StakeUpdate(stake, oldStake);
  }

  function updateParticipantsRange(uint _minParticipants, uint _maxParticipants) external onlyOwner {
    require(_minParticipants <= _maxParticipants);
    require(_minParticipants != minParticipants || _maxParticipants != maxParticipants);
    if (_minParticipants != minParticipants) {
      uint oldMinParticipants = minParticipants;
      minParticipants = _minParticipants;
      emit MinParticipantsUpdate(minParticipants, oldMinParticipants);
    }
    if (_maxParticipants != maxParticipants) {
      uint oldMaxParticipants = maxParticipants;
      maxParticipants = _maxParticipants;
      emit MaxParticipantsUpdate(maxParticipants, oldMaxParticipants);
    }
  }

  function updateRewardRatios(uint _winnersPerThousand, uint _distPercentage) external onlyOwner {
    require(_distPercentage <= 100);
    require(1000 * _distPercentage / _winnersPerThousand >= 100);
    require(_winnersPerThousand != winnersPerThousand || _distPercentage != distPercentage);
    if (_winnersPerThousand != winnersPerThousand) {
      uint oldWinnersReturn = winnersPerThousand;
      winnersPerThousand = _winnersPerThousand;
      emit RewardRatiosUpdate(winnersPerThousand, oldWinnersReturn);
    }
    if (_distPercentage != distPercentage) {
      uint oldDistPercentage = distPercentage;
      distPercentage = _distPercentage;
      emit DistPercentageUpdate(distPercentage, oldDistPercentage);
    }
  }

  function updateMinBlocksBeforeReveal(uint _minBlocksBeforeReveal) external onlyOwner {
    require(_minBlocksBeforeReveal != minBlocksBeforeReveal);
    uint oldMinBlocksBeforeReveal = minBlocksBeforeReveal;
    minBlocksBeforeReveal = _minBlocksBeforeReveal;
    emit MinBlocksBeforeRevealUpdate(minBlocksBeforeReveal, oldMinBlocksBeforeReveal);
  }

  function updateMinBlocksBeforeEnd(uint _minBlocksBeforeEnd) external onlyOwner {
    require(_minBlocksBeforeEnd != minBlocksBeforeEnd);
    uint oldMinBlocksBeforeEnd = minBlocksBeforeEnd;
    minBlocksBeforeEnd = _minBlocksBeforeEnd;
    emit MinBlocksBeforeEndUpdate(minBlocksBeforeEnd, oldMinBlocksBeforeEnd);
  }

  function withdraw(uint _amount) external onlyOwner {
    require(address(this).balance >= _amount);
    msg.sender.transfer(_amount);
  }

  event StakeUpdate(uint newStake, uint oldStake);

  event MinParticipantsUpdate(uint newMinParticipants, uint oldMinParticipants);

  event MaxParticipantsUpdate(uint newMaxParticipants, uint oldMaxParticipants);

  event RewardRatiosUpdate(uint newWinnersPerThousand, uint oldWinnersPerThousand);

  event DistPercentageUpdate(uint newDistPercentage, uint oldDistPercentage);

  event MinBlocksBeforeRevealUpdate(uint newMinBlocksBeforeReveal, uint oldMinBlocksBeforeReveal);

  event MinBlocksBeforeEndUpdate(uint newMinBlocksBeforeUpdate, uint oldMinBlocksBeforeUpdate);

  event StageChange(bytes32 hash, uint8 newStage, uint8 oldStage);

  event Refund(bytes32 hash, address recepient, uint fund);

  event Reveal(bytes32 hash, address revealor, uint8 worth);
}