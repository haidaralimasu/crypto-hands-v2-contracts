// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface GameEngineV2Interface {
    struct Player {
        uint256 totalGamesPlayed;
        uint256 totalGamesWonned;
        uint256 totalEarnings;
        uint256 referralEarnings;
        uint256 totalReferrals;
        uint256 nftWoned;
        uint256 nftWinPercentage;
        uint256 refreeNftWinPercentage;
        address refree;
    }

    struct Bet {
        uint256 betId;
        GameChoices choice;
        GameChoices outcome;
        address player;
        uint256 amount;
        uint256 winAmount;
        Results result;
    }

    enum GameChoices {
        Rock,
        Paper,
        Scissors
    }

    enum Results {
        Win,
        Loose,
        Tie
    }

    event RewardClaimed(
        address indexed player,
        uint256 indexed claimedAmount,
        uint256 time
    );

    event BetCreated(
        uint256 _betId,
        GameChoices _playerChoice,
        address _player,
        uint256 _betAmount,
        uint256 _winAmount,
        uint256 _time
    );

    event ResultsDeclared(
        uint256 _betId,
        GameChoices _choice,
        GameChoices _outcome,
        uint256 _amount,
        uint256 _winAmount,
        address _player,
        Results _result,
        uint256 _time
    );

    event NFTWonned(
        address player,
        uint256 time,
        string functionName,
        uint256 randomNumber
    );

    event RNGUpdated(address newRNG);

    event CryptoHandsUPdated(address newCryptoHands);

    event CommissionPercentageUpdated(uint256 newCommissionPercentage);

    event RefreeCommissionUpdated(uint256 newRefreeCommission);

    event DividerUpdated(uint256 newDivider);

    event AvailableBetsUpdated(uint256 newAmount);
}
