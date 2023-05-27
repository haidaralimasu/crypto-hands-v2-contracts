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
        address refree;
        bool isRegistered;
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

    event CryptoHandsUpdated(address _newCryptoHands);
    event MaxBetUpdated(uint256 _newMaxBet);
    event MinBetUpdated(uint256 _newMinBet);
    event DividerUpdated(uint256 _newDivider);
    event ComissionPercentageUpdated(uint256 _comissionPercentage);
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
}
