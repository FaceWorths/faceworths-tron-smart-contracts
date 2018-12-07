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
  uint public maxParticipants = 10000;
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
    faceTokenRewardPool = faceToken.totalSupply() * 80 / 100;
    oneFace = 10 ** faceToken.decimals();
  }

  event FaceWorthPollCreated (
    bytes32 indexed hash,
    address indexed creator,
    uint blockNumber
  );

  function createFaceWorthPoll(
    bytes32 _faceHash,
    uint _blocksBeforeReveal,
    uint _blocksBeforeEnd
  )
    public
    returns (bytes32)
  {
    require(_blocksBeforeReveal >= minBlocksBeforeReveal);
    require(_blocksBeforeEnd >= minBlocksBeforeEnd);

    FaceWorthPoll memory poll;
    poll.creator = msg.sender;
    poll.faceHash = _faceHash;
    poll.startingBlock = block.number;
    poll.commitEndingBlock = poll.startingBlock + _blocksBeforeReveal;
    poll.revealEndingBlock = poll.commitEndingBlock + _blocksBeforeEnd;
    poll.currentStage = COMMITTING;

    bytes32 hash = keccak256(abi.encodePacked(poll.creator, poll.faceHash, poll.startingBlock));
    polls[hash] = poll;
    pollCount++;

    emit FaceWorthPollCreated(
      hash,
      msg.sender,
      block.number
    );

    return hash;
  }

  function commit(bytes32 hash, bytes32 _saltedWorthHash) payable external {
    FaceWorthPoll storage poll = polls[hash];
    require(!poll.committedBy[msg.sender]);
    require(poll.currentStage == COMMITTING && msg.value == stake);
    poll.saltedWorthHashBy[msg.sender] = _saltedWorthHash;
    poll.committedBy[msg.sender] = true;
    poll.participants.push(msg.sender);
  }

  function reveal(bytes32 hash, string _salt, uint8 _worth) external {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.committedBy[msg.sender]);
    require(!poll.revealedBy[msg.sender]);
    require(poll.currentStage == REVEALING);
    require(poll.saltedWorthHashBy[msg.sender] == keccak256(abi.encodePacked(concat(_salt, _worth))));
    require(_worth >= 0 && _worth <= 100);
    poll.worthBy[msg.sender] = _worth;
    poll.revealedBy[msg.sender] = true;
    poll.revealCount++;
  }

  function cancel(bytes32 hash) external {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.creator == msg.sender);
    require(poll.currentStage == COMMITTING);
    poll.currentStage = CANCELLED;
    emit StageChange(hash, poll.currentStage, COMMITTING);
    refund(hash);
  }

  // this function should be called every 3 seconds (Tron block time)
  function checkBlockNumber(bytes32 hash) external {
    FaceWorthPoll storage poll = polls[hash];
    if (poll.currentStage != CANCELLED && poll.currentStage != ENDED) {
      if (block.number > poll.commitEndingBlock) {
        if (poll.participants.length < minParticipants) {
          poll.currentStage = CANCELLED;
          emit StageChange(hash, poll.currentStage, COMMITTING);
          refund(hash);
        } else if (block.number <= poll.revealEndingBlock) {
          poll.currentStage = REVEALING;
          emit StageChange(hash, poll.currentStage, COMMITTING);
        } else {
          endPoll(hash);
        }
      }
    }
  }

  function refund(bytes32 hash) private {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.currentStage == CANCELLED);
    for (uint i = 0; i < poll.participants.length; i++) {
      if (!poll.refunded[poll.participants[i]]) {
        poll.refunded[poll.participants[i]] = true;
        poll.participants[i].transfer(stake);
        emit Refund(hash, poll.participants[i], stake);
      }
    }
  }

  function endPoll(bytes32 hash) private {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.currentStage != ENDED);
    poll.currentStage = ENDED;

    if (poll.revealCount > 0) {
      // sort the participants by their worth from low to high using Counting Sort
      address[] memory sortedParticipants = sortParticipants(hash);

      uint totalWorth = getTotalWorth(hash);
      // find turning point where the right gives higher than average FaceWorth and the left lower
      uint turningPoint = getTurningPoint(hash, totalWorth, sortedParticipants);

      // reverse those who give lower than average but the same FaceWorth so that the earlier participant is closer to the turning point
      if (turningPoint > 0) {
        uint p = turningPoint - 1;
        while (p > 0) {
          uint start = p;
          uint end = p;
          while (end > 0 && poll.worthBy[sortedParticipants[start]] == poll.worthBy[sortedParticipants[end - 1]]) {
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

      findWinners(hash, turningPoint, totalWorth, sortedParticipants);

      distributePrize(hash);
    }

    rewardFaceTokens(hash);

    emit StageChange(hash, poll.currentStage, REVEALING);
  }

  function rewardFaceTokens(bytes32 hash) private {
    FaceWorthPoll storage poll = polls[hash];
    if (faceTokenRewardPool > 0) {
      uint creatorReward = oneFace + oneFace * poll.participants.length / 10;
      if (faceTokenRewardPool < creatorReward) {
        creatorReward = faceTokenRewardPool;
      }
      rewardFaceTokens(poll.creator, creatorReward);
      if (faceTokenRewardPool > 0) {
        uint participantReward = oneFace / 10;
        for (uint i = 0; i < poll.participants.length; i++) {
          if (!poll.wonBy[poll.participants[i]]) {
            if (faceTokenRewardPool < participantReward) {
              rewardFaceTokens(poll.participants[i], faceTokenRewardPool);
              break;
            } else {
              rewardFaceTokens(poll.participants[i], participantReward);
            }
          }
        }
      }
    }
  }

  function rewardFaceTokens(address _receiver, uint _value) private {
    FaceToken faceToken = FaceToken(faceTokenAddress);
    faceToken.increaseApproval(_receiver, _value);
    faceTokenRewardPool = faceTokenRewardPool.sub(_value);
  }


  function findWinners(bytes32 hash, uint _turningPoint, uint _totalWorth, address[] memory _sortedParticipants) private {
    FaceWorthPoll storage poll = polls[hash];
    uint numOfWinners = poll.participants.length * winnersPerThousand / 1000;
    if (numOfWinners > poll.revealCount) numOfWinners = poll.revealCount;
    uint index = 0;
    uint leftIndex = _turningPoint;
    uint rightIndex = _turningPoint;
    if (poll.worthBy[_sortedParticipants[_turningPoint]] * poll.revealCount == _totalWorth) {
      poll.winners.push(_sortedParticipants[_turningPoint]);
      poll.wonBy[poll.winners[index]] = true;
      index++;
      rightIndex++;
    } else {
      if (leftIndex > 0) leftIndex--;
      else rightIndex++;
    }
    while (index < numOfWinners) {
      uint rightDiff;
      if (rightIndex < _sortedParticipants.length) {
        rightDiff = poll.worthBy[_sortedParticipants[rightIndex]] * poll.revealCount - _totalWorth;
      }
      uint leftDiff = _totalWorth - poll.worthBy[_sortedParticipants[leftIndex]] * poll.revealCount;

      if (rightIndex < _sortedParticipants.length && rightDiff <= leftDiff) {
        poll.winners.push(_sortedParticipants[rightIndex]);
        poll.wonBy[_sortedParticipants[rightIndex]] = true;
        index++;
        rightIndex++;
      } else if (rightIndex >= _sortedParticipants.length || rightIndex < _sortedParticipants.length && rightDiff > leftDiff) {
        poll.winners.push(_sortedParticipants[leftIndex]);
        poll.wonBy[_sortedParticipants[leftIndex]] = true;
        index++;
        if (leftIndex > 0) leftIndex--;
        else rightIndex++;
      }
    }
  }

  function distributePrize(bytes32 hash) private {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.winners.length > 0);
    uint totalPrize = stake * poll.participants.length * distPercentage / 100;
    uint avgPrize = totalPrize / poll.winners.length;
    uint minPrize = (avgPrize + 2 * stake) / 3;
    uint step = (avgPrize - minPrize) / (poll.winners.length / 2);
    uint prize = minPrize;
    for (uint q = poll.winners.length; q > 0; q--) {
      poll.winners[q - 1].transfer(prize);
      prize += step;
    }
  }

  function sortParticipants(bytes32 hash) private view returns (address[]) {
    FaceWorthPoll storage poll = polls[hash];
    address[] memory sortedParticipants_ = new address[](poll.revealCount);
    uint[101] memory count;
    for (uint i = 0; i < 101; i++) {
      count[i] = 0;
    }
    for (uint j = 0; j < poll.participants.length; j++) {
      if (poll.revealedBy[poll.participants[j]]) {
        count[poll.worthBy[poll.participants[j]]]++;
      }
    }
    for (uint k = 1; k < 101; k++) {
      count[k] += count[k - 1];
    }
    for (uint m = poll.participants.length; m > 0; m--) {
      if (poll.revealedBy[poll.participants[m - 1]]) {
        sortedParticipants_[count[poll.worthBy[poll.participants[m - 1]]] - 1] = poll.participants[m - 1];
        count[poll.worthBy[poll.participants[m - 1]]]--;
      }
    }
    return sortedParticipants_;
  }

  function getTurningPoint(bytes32 hash, uint _totalWorth, address[] _sortedParticipants) private view returns (uint) {
    FaceWorthPoll storage poll = polls[hash];
    uint turningPoint_;
    for (uint i = 0; i < _sortedParticipants.length; i++) {
      if (poll.worthBy[_sortedParticipants[i]] * poll.revealCount >= _totalWorth) {
        turningPoint_ = i;
        break;
      }
    }
    return turningPoint_;
  }

  function getTotalWorth(bytes32 hash) private view returns (uint) {
    FaceWorthPoll storage poll = polls[hash];
    uint totalWorth_ = 0;
    for (uint i = 0; i < poll.participants.length; i++) {
      if (poll.revealedBy[poll.participants[i]]) {
        totalWorth_ += poll.worthBy[poll.participants[i]];
      }
    }
    return totalWorth_;
  }

  function getCommitTimeElapsed(bytes32 hash) external view returns (uint) {
    FaceWorthPoll storage poll = polls[hash];
    if (block.number >= poll.commitEndingBlock) return 100;
    return (block.number - poll.startingBlock) * 100 / (poll.commitEndingBlock - poll.startingBlock);
  }

  function getRevealTimeElapsed(bytes32 hash) external view returns (uint) {
    FaceWorthPoll storage poll = polls[hash];
    if (block.number < poll.commitEndingBlock) {
      return 0;
    } else if (block.number >= poll.revealEndingBlock) {
      return 100;
    } else {
      return (block.number - poll.commitEndingBlock - 1) * 100 / (poll.revealEndingBlock - poll.commitEndingBlock - 1);
    }
  }

  function getCurrentStage(bytes32 hash) external view returns (uint8) {
    FaceWorthPoll storage poll = polls[hash];
    return poll.currentStage;
  }

  function getNumberOfParticipants(bytes32 hash) external view returns (uint) {
    FaceWorthPoll storage poll = polls[hash];
    return poll.participants.length;
  }

  function getParticipants(bytes32 hash) external view returns (address[]) {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.currentStage != COMMITTING);
    return poll.participants;
  }

  function getWorthBy(bytes32 hash, address _who) external view returns (uint8) {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.currentStage == ENDED);
    return poll.worthBy[_who];
  }

  function getWinners(bytes32 hash) external view returns (address[]) {
    FaceWorthPoll storage poll = polls[hash];
    require(poll.currentStage == ENDED);
    return poll.winners;
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

  function() public payable {
    revert();
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
}