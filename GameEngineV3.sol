// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {IERC721AQueryable} from "erc721a/contracts/extensions/IERC721AQueryable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICryptoHands} from "./interfaces/ICryptoHands.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {GameEngineV2Interface} from "./interfaces/GameEngineV2Interface.sol";
import {KeeperCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import {RNGInterface} from "./interfaces/RNGInterface.sol";

contract GameEngineV3 is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    GameEngineV2Interface,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    RNGInterface public s_rng;
    RNGInterface.RngRequest internal s_rngRequest;
    address public s_cryptoHands;

    uint256 public s_commissionPercentage;
    uint256 public s_refreeCommission;
    uint256 public s_divider;

    CountersUpgradeable.Counter public s_totalBets;

    mapping(address => Player) public s_players;
    mapping(uint256 => Bet) public s_bets;

    uint256[5] public s_availableBets;

    uint256 public s_nftWinPercentage;
    uint256 public s_basisPoints;

    function initialize(address rng_, address cryptoHands_) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        s_rng = RNGInterface(rng_);
        s_cryptoHands = cryptoHands_;

        s_commissionPercentage = 300;
        s_refreeCommission = 100;
        s_divider = 10;

        s_availableBets = [
            0.001 ether,
            0.002 ether,
            0.003 ether,
            0.004 ether,
            0.005 ether
        ];

        s_nftWinPercentage = 1000;
        s_basisPoints = 100000000;
    }

    /*********************
     **EXTERNAL FUNCTIONS**
     **********************/

    function claim() external nonReentrant whenNotPaused {
        uint256 claimableAmount = getClaimAmount(_msgSender());
        (bool os, ) = payable(_msgSender()).call{value: claimableAmount}("");
        require(os);

        uint256[] memory allNftsOfPlayer = IERC721AQueryable(s_cryptoHands)
            .tokensOfOwner(_msgSender());

        ICryptoHands(s_cryptoHands).updateCryptoHandsTokensStruct(
            allNftsOfPlayer,
            _currentTime()
        );
    }

    function makeBet(
        uint256 choice_,
        address refree_
    ) external payable whenNotPaused nonReentrant {
        bool shouldProceed = false;

        for (uint256 i = 0; i < s_availableBets.length; i++) {
            if (msg.value == s_availableBets[i]) {
                shouldProceed = true;
                break;
            }
        }

        require(shouldProceed, "GameEngineV2: Invalid bet amount");

        (address feeToken, uint256 requestFee) = s_rng.getRequestFee();

        if (feeToken != address(0) && requestFee > 0) {
            IERC20(feeToken).safeIncreaseAllowance(address(s_rng), requestFee);
        }

        (uint32 requestId, uint32 lockBlock) = s_rng.requestRandomNumber();

        s_rngRequest.id = requestId;
        s_rngRequest.lockBlock = lockBlock;
        s_rngRequest.requestedAt = _currentTime();

        _createAndSettleBet(choice_, msg.value, _msgSender(), refree_);
        _winNft(_msgSender(), msg.value);
    }

    /***************************
     **INTERNAL VIEW FUNCTIONS**
     ***************************/

    function _getNftWinPercentage(
        uint256 _bet
    ) public view returns (uint256 nftWinPercentage) {
        uint256 nftWinPercentageWithDecrease = _getNftWinPercentageWithDecrease();
        uint256 multiple = _bet.mul(nftWinPercentageWithDecrease).div(1 ether);
        nftWinPercentage = multiple;
    }

    function _getChoiceAccordingToNumber(
        uint256 _number
    ) internal pure returns (GameChoices _gameChoice) {
        require(_number < 3, "GameEngineV2: Choice should be less than 3");
        if (_number == 0) {
            _gameChoice = GameChoices.Rock;
        }
        if (_number == 1) {
            _gameChoice = GameChoices.Paper;
        }
        if (_number == 2) {
            _gameChoice = GameChoices.Scissors;
        }
    }

    function _amountToWinningPool(
        uint256 _bet
    ) internal view returns (uint256 _winningPool) {
        uint256 balance = address(this).balance;
        _winningPool = (balance / s_divider) + _bet;
    }

    function _currentTime() internal view returns (uint64 currentTime) {
        return uint64(block.timestamp);
    }

    function _getComissionFromBet(
        uint256 _bet,
        address _player
    ) internal view returns (uint256, uint256) {
        if (s_players[_player].refree == address(0)) {
            uint256 _comission = _bet.mul(s_commissionPercentage).div(10000);
            return (_comission, 0);
        } else {
            uint256 refreeCommsion = _bet.mul(s_refreeCommission).div(10000);
            uint256 gameCommision = _bet
                .mul(s_commissionPercentage)
                .div(10000)
                .sub(refreeCommsion);
            return (gameCommision, refreeCommsion);
        }
    }

    function _winOrLoose(
        GameChoices _playerChoice,
        GameChoices _outcome
    ) internal pure returns (Results _result) {
        if (_playerChoice == GameChoices.Rock && _outcome == GameChoices.Rock) {
            _result = Results.Tie;
        }
        if (
            _playerChoice == GameChoices.Rock && _outcome == GameChoices.Paper
        ) {
            _result = Results.Loose;
        }
        if (
            _playerChoice == GameChoices.Rock &&
            _outcome == GameChoices.Scissors
        ) {
            _result = Results.Win;
        }
        if (
            _playerChoice == GameChoices.Paper && _outcome == GameChoices.Paper
        ) {
            _result = Results.Tie;
        }
        if (
            _playerChoice == GameChoices.Paper &&
            _outcome == GameChoices.Scissors
        ) {
            _result = Results.Loose;
        }
        if (
            _playerChoice == GameChoices.Paper && _outcome == GameChoices.Rock
        ) {
            _result = Results.Win;
        }
        if (
            _playerChoice == GameChoices.Scissors &&
            _outcome == GameChoices.Scissors
        ) {
            _result = Results.Tie;
        }
        if (
            _playerChoice == GameChoices.Scissors &&
            _outcome == GameChoices.Rock
        ) {
            _result = Results.Loose;
        }
        if (
            _playerChoice == GameChoices.Scissors &&
            _outcome == GameChoices.Paper
        ) {
            _result = Results.Win;
        }
    }

    function _getNftWinPercentageWithDecrease()
        internal
        view
        returns (uint256)
    {
        IERC721AQueryable cryptoHands = IERC721AQueryable(s_cryptoHands);
        return s_nftWinPercentage.sub(cryptoHands.totalSupply());
    }

    function _getClaimableAmountPerNft(
        uint256 tokenId
    ) internal view returns (uint256 claimableAmount) {
        (uint256 lastClaimTime, uint256 lastTotalSupply) = ICryptoHands(
            s_cryptoHands
        ).getCryptoHandsToken(tokenId);
        require(lastClaimTime != 0, "GameEngineV2: ClaimTime doesnot exist !");
        uint256 timeDifference = _currentTime() - lastClaimTime;
        uint256 _claimableAmount = timeDifference.div(address(this).balance);
        uint256 _claimableAmountPerToken = _claimableAmount.div(
            lastTotalSupply
        );
        claimableAmount = _claimableAmountPerToken;
    }

    /***************************
     **EXTERNAL VIEW FUNCTIONS**
     ***************************/

    function getClaimAmount(
        address player_
    ) public view returns (uint256 totalCalimableAmount) {
        require(
            IERC721AQueryable(s_cryptoHands).balanceOf(player_) >= 1,
            "GameEngineV2: You dont have any CryptoHands Token"
        );
        uint256[] memory allNftsOfPlayer = IERC721AQueryable(s_cryptoHands)
            .tokensOfOwner(player_);

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < allNftsOfPlayer.length; i++) {
            uint256 calimableAmount = _getClaimableAmountPerNft(
                allNftsOfPlayer[i]
            );
            totalAmount = totalAmount + calimableAmount;
        }
        totalCalimableAmount = totalAmount;
    }

    /***************************
     *****INTERNAL FUNCTIONS****
     ***************************/

    function _winNft(address _player, uint256 _bet) internal {
        address refree = s_players[_player].refree;
        uint256 winPercentage = _getNftWinPercentage(_bet);
        uint256 randomNumber = s_rng.randomNumber(s_rngRequest.id);

        uint256 formattedRandomNumber = randomNumber % s_basisPoints;

        uint256 totalHandsWinned = ICryptoHands(s_cryptoHands)
            .getTotalHandsWinned();
        uint256 maxHandsAvailableToWin = ICryptoHands(s_cryptoHands)
            .getMaxHandsAvailableToWin();

        uint256 nftWinPercentage = s_players[_player].nftWinPercentage;
        uint256 refreeWinPercentage = s_players[_player].refreeNftWinPercentage;

        uint256 combinedWinPercentage = nftWinPercentage.add(
            refreeWinPercentage
        );

        if (totalHandsWinned <= maxHandsAvailableToWin) {
            if (combinedWinPercentage == s_basisPoints) {
                ICryptoHands(s_cryptoHands).winHands(_player);
                s_players[_player].nftWinPercentage = 0;
                s_players[_player].refreeNftWinPercentage = 0;
            }
            if (combinedWinPercentage > formattedRandomNumber) {
                ICryptoHands(s_cryptoHands).winHands(_player);
            }
        }

        s_players[_player].nftWinPercentage =
            s_players[_player].nftWinPercentage +
            winPercentage;
        s_players[refree].refreeNftWinPercentage =
            s_players[refree].refreeNftWinPercentage +
            winPercentage;
    }

    function _createAndSettleBet(
        uint256 choice_,
        uint256 betAmount_,
        address player_,
        address refree_
    ) internal {
        address refree = address(0);

        if (
            s_players[player_].refree == address(0) &&
            refree_ != address(0) &&
            refree_ != player_
        ) {
            s_players[player_].refree = refree_;
            refree = refree_;
            s_players[refree_].totalReferrals =
                s_players[refree_].totalReferrals +
                1;
        } else {
            refree = s_players[player_].refree;
        }

        GameChoices _playerChoice = _getChoiceAccordingToNumber(choice_);

        uint256 randomNumber = s_rng.randomNumber(s_rngRequest.id);

        GameChoices _outcome = _getChoiceAccordingToNumber(randomNumber % 3);

        uint256 winAmount = _amountToWinningPool(betAmount_);

        (uint256 gameCommision, uint256 refreeCommision) = _getComissionFromBet(
            betAmount_,
            player_
        );

        Results _result = _winOrLoose(_playerChoice, _outcome);

        if (refree == address(0)) {
            if (_result == Results.Win) {
                (bool hs, ) = payable(player_).call{
                    value: (winAmount - gameCommision)
                }("");
                require(
                    hs,
                    "GameEngineV2: Failed to send MATIC for win clause"
                );

                s_players[player_].totalGamesWonned =
                    s_players[player_].totalGamesWonned +
                    1;
                s_players[player_].totalEarnings =
                    s_players[player_].totalEarnings +
                    winAmount;
            }
            if (_result == Results.Tie) {
                (bool hs, ) = payable(player_).call{
                    value: (betAmount_ - gameCommision)
                }("");
                require(
                    hs,
                    "GameEngineV2: Failed to send MATIC for tie clause"
                );
            }
        } else {
            if (_result == Results.Win) {
                (bool hs, ) = payable(player_).call{
                    value: (winAmount - gameCommision)
                }("");
                require(
                    hs,
                    "GameEngineV2: Failed to send MATIC for win clause"
                );

                (bool sh, ) = payable(refree).call{value: (refreeCommision)}(
                    ""
                );
                require(
                    sh,
                    "GameEngineV2: Failed to send commision MATIC to refree win clause"
                );

                s_players[player_].totalGamesWonned =
                    s_players[player_].totalGamesWonned +
                    1;

                s_players[player_].totalEarnings =
                    s_players[player_].totalEarnings +
                    winAmount;

                s_players[refree].referralEarnings =
                    s_players[refree].referralEarnings +
                    refreeCommision;
            }
            if (_result == Results.Tie) {
                (bool hs, ) = payable(player_).call{
                    value: (betAmount_ - gameCommision)
                }("");
                require(
                    hs,
                    "GameEngineV2: Failed to send MATIC for tie clause"
                );

                (bool sh, ) = payable(refree).call{value: (refreeCommision)}(
                    ""
                );
                require(
                    sh,
                    "GameEngineV2: Failed to send commision MATIC to refree tie clause"
                );
            }
        }

        Bet memory currentBet = Bet(
            s_totalBets.current(),
            _playerChoice,
            _outcome,
            player_,
            betAmount_,
            winAmount,
            _result
        );

        s_bets[s_totalBets.current()] = currentBet;
        s_totalBets.increment();

        s_players[player_].totalGamesPlayed =
            s_players[player_].totalGamesPlayed +
            1;
    }

    /***************************
     *****OWNER FUNCTIONS****
     ***************************/

    function updateRNG(RNGInterface rng_) external onlyOwner {
        s_rng = rng_;
    }

    function updateCryptoHands(address cryptoHands_) external onlyOwner {
        s_cryptoHands = cryptoHands_;
    }

    function updateCommissionPercentage(
        uint256 commission_
    ) external onlyOwner {
        s_commissionPercentage = commission_;
    }

    function updateRefreeCommission(
        uint256 refreeCommision_
    ) external onlyOwner {
        s_refreeCommission = refreeCommision_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateDivider(uint256 divider_) external onlyOwner {
        s_divider = divider_;
    }

    function updateAvailableBets(
        uint256 index_,
        uint256 betAmount_
    ) external onlyOwner {
        require(index_ < s_availableBets.length, "GameEngineV2: Out of bound");
        s_availableBets[index_] = betAmount_;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /***************************
     *****UTILITY FUNCTIONS*****
     ***************************/

    receive() external payable {}
}
