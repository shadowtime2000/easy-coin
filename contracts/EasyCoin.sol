pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract EasyCoin is ERC20 {
  using SafeMath for uint;

  event Mint(address indexed from, uint reward_amount, uint epochCount, bytes32 newChallengeNumber);

  uint public latestDifficultyPeriodStarted;
  uint public epochCount;

  uint public BLOCKS_PER_READJUSTMENT = 256;
  uint public MINIMUM_TARGET = 2**48;
  uint public MAXIMUM_TARGET = 2**255;

  uint public miningTarget;
  bytes32 public challengeNumber;

  address public lastRewardTo;
  uint public lastRewardEthBlockNumber;

  mapping (bytes32 => bytes32) solutionForChallenge;

  constructor() ERC20("EasyCoin", "EASY") public {
    _startNewMiningEpoch();
  }

  function mint(uint256 nonce, bytes32 challenge_digest) public returns (bool success) {

    bytes32 digest = keccak256(abi.encodePacked(challengeNumber, msg.sender, nonce));

    if (digest != challenge_digest) revert();

    if (uint256(digest) > miningTarget) revert();

    bytes32 solution = solutionForChallenge[challengeNumber];
    solutionForChallenge[challengeNumber] = digest;
    if (solution != 0x0) revert();

    _mint(msg.sender, 10**18);

    lastRewardTo = msg.sender;
    lastRewardEthBlockNumber = block.number;

    _startNewMiningEpoch();

    emit Mint(msg.sender, 10**18, epochCount, challengeNumber);

    return true;
  }

  function _startNewMiningEpoch() internal {

    epochCount = epochCount.add(1);

    if (epochCount % BLOCKS_PER_READJUSTMENT == 0) {
      _readjustDifficulty();
    }


    challengeNumber = blockhash(block.number - 1);
  }

  function _readjustDifficulty() internal {


    uint ethBlocksSinceLastDifficultyPeriod = block.number - latestDifficultyPeriodStarted;

    uint epochsMined = BLOCKS_PER_READJUSTMENT;

    uint targetEthBlocksPerDiffPeriod = epochsMined*15;

    if (ethBlocksSinceLastDifficultyPeriod < targetEthBlocksPerDiffPeriod) {

      uint excess_block_pct = (targetEthBlocksPerDiffPeriod.mul(100)).div(ethBlocksSinceLastDifficultyPeriod);

      uint thingy;

      if (excess_block_pct.sub(100) > 1000) {
        thingy = 1000;
      } else {
        thingy = excess_block_pct.sub(100);
      }

      uint excess_block_pct_extra = thingy;

      miningTarget = miningTarget.sub(miningTarget.div(2000).mul(excess_block_pct_extra));
    } else {

      uint shortage_block_pct = (ethBlocksSinceLastDifficultyPeriod.mul(100)).div(targetEthBlocksPerDiffPeriod);

      uint thingy;

      if (shortage_block_pct.sub(100) > 1000) {
        thingy = 1000;
      } else {
        thingy = shortage_block_pct.sub(100);
      }

      uint shortage_block_pct_extra = thingy;

      miningTarget = miningTarget.add(miningTarget.div(2000).mul(shortage_block_pct_extra));
    }

    latestDifficultyPeriodStarted = block.number;

    if (miningTarget < MINIMUM_TARGET) {
      miningTarget = MINIMUM_TARGET;
    }

    if (miningTarget > MAXIMUM_TARGET) {
      miningTarget = MAXIMUM_TARGET;
    }
  }

  function getChallengeNumber() public view returns (bytes32) {
    return challengeNumber;
  }

  function getMiningDifficulty() public view returns (uint) {
    return MAXIMUM_TARGET.div(miningTarget);
  }

  function getMiningTarget() public view returns (uint) {
    return miningTarget;
  }

}
