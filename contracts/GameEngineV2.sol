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

contract GameEngineV2 is
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

    RNGInterface private s_rng;
    RNGInterface.RngRequest internal s_rngRequest;
    address private s_cryptoHands;

    uint256 private s_commissionPercentage;
    uint256 private s_refreeCommission;
    uint256 private s_divider;

    CountersUpgradeable.Counter private s_totalBets;

    mapping(address => Player) private s_players;
    mapping(uint256 => Bet) private s_bets;

    uint256[5] private s_availableBets;

    uint256 private s_nftWinPercentage;
    uint256 private s_basisPoints;

    function initialize(address rng_, address cryptoHands_) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        s_rng = RNGInterface(rng_);
        s_cryptoHands = cryptoHands_;

        s_commissionPercentage = 300;
        s_refreeCommission = 2500;
        s_divider = 10;

        s_availableBets = [
            0.001 ether,
            0.002 ether,
            0.003 ether,
            0.004 ether,
            0.005 ether
        ];

        s_nftWinPercentage = 500; // TODO: make it 1000 in production
        s_basisPoints = 10000;
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
            allNftsOfPlayer
        );

        emit RewardClaimed(_msgSender(), claimableAmount, _currentTime());
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

        _getRandomNumberRequest();
        require(shouldProceed, "GameEngineV2: Invalid bet amount");
        if (
            s_players[refree_].totalGamesPlayed >= 1 &&
            s_players[msg.sender].totalGamesPlayed == 0
        ) {
            _createAndSettleBet(choice_, msg.value, _msgSender(), refree_);
        } else {
            _createAndSettleBet(choice_, msg.value, _msgSender(), address(0));
        }

        _winNft(_msgSender(), msg.value);
    }

    /***************************
     *****INTERNAL FUNCTIONS****
     ***************************/

    function _getRandomNumberRequest() internal {
        (address feeToken, uint256 requestFee) = s_rng.getRequestFee();

        if (feeToken != address(0) && requestFee > 0) {
            IERC20(feeToken).safeIncreaseAllowance(address(s_rng), requestFee);
        }

        (uint32 requestId, uint32 lockBlock) = s_rng.requestRandomNumber();

        s_rngRequest.id = requestId;
        s_rngRequest.lockBlock = lockBlock;
        s_rngRequest.requestedAt = _currentTime();
    }

    function _winNft(address _player, uint256 _bet) internal {
        address refree = s_players[_player].refree;
        uint256 winPercentage = _getNftWinPercentage(_bet);
        uint256 randomNumber = s_rng.randomNumber(s_rngRequest.id - 1);

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
                s_players[_player].nftWoned = s_players[_player].nftWoned + 1;
            } else {
                if (combinedWinPercentage > formattedRandomNumber) {
                    ICryptoHands(s_cryptoHands).winHands(_player);
                    s_players[_player].nftWoned =
                        s_players[_player].nftWoned +
                        1;
                }
            }
        }

        emit NFTWonned(
            _player,
            _currentTime(),
            "greater",
            formattedRandomNumber
        );

        s_players[_player].nftWinPercentage =
            s_players[_player].nftWinPercentage +
            winPercentage;

        if (refree != address(0)) {
            s_players[refree].refreeNftWinPercentage =
                s_players[refree].refreeNftWinPercentage +
                winPercentage;
        }

        // s_nftWinPercentage = s_nftWinPercentage - 1; //REVIEW: WHY
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

        uint256 randomNumber = s_rng.randomNumber(s_rngRequest.id - 1);

        GameChoices _outcome = _getChoiceAccordingToNumber(randomNumber % 3);

        Results _result = _winOrLoose(_playerChoice, _outcome);

        uint256 winAmount = _amountToWinningPool(betAmount_);

        _calculateAndTransferFunds(player_, betAmount_, _result);

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

        emit ResultsDeclared(
            s_totalBets.current(),
            _playerChoice,
            _outcome,
            betAmount_,
            winAmount,
            player_,
            _result,
            _currentTime()
        );

        emit BetCreated(
            s_totalBets.current(),
            _playerChoice,
            player_,
            betAmount_,
            winAmount,
            _currentTime()
        );
    }

    function _calculateAndTransferFunds(
        address player_,
        uint256 betAmount_,
        Results _result
    ) internal {
        address refree = s_players[player_].refree;
        (uint256 gameCommision, uint256 refreeCommision) = _getComissionFromBet(
            betAmount_,
            player_
        );
        uint256 winAmount = _amountToWinningPool(betAmount_);

        if (_result == Results.Win) {
            if (refree == address(0)) {
                transferNative(player_, winAmount - gameCommision);
            } else {
                transferNative(player_, winAmount - gameCommision);
                transferNative(refree, refreeCommision);

                s_players[refree].referralEarnings =
                    s_players[refree].referralEarnings +
                    refreeCommision;
            }

            s_players[player_].totalGamesWonned =
                s_players[player_].totalGamesWonned +
                1;

            s_players[player_].totalEarnings =
                s_players[player_].totalEarnings +
                winAmount;
        }
        if (_result == Results.Tie) {
            if (refree == address(0)) {
                transferNative(player_, betAmount_ - gameCommision);
            } else {
                transferNative(player_, betAmount_ - gameCommision);
                transferNative(refree, refreeCommision);
                s_players[refree].referralEarnings =
                    s_players[refree].referralEarnings +
                    refreeCommision;
            }
        }
        if (_result == Results.Loose) {
            if (refree != address(0)) {
                transferNative(refree, refreeCommision);
                s_players[refree].referralEarnings =
                    s_players[refree].referralEarnings +
                    refreeCommision;
            }
        }
    }

    /***************************
     **INTERNAL VIEW FUNCTIONS**
     ***************************/

    function _getNftWinPercentage(
        uint256 _bet
    ) public view returns (uint256 nftWinPercentage) {
        uint256 nftWinPercentageWithDecrease = _getNftWinPercentageWithDecrease();

        return nftWinPercentageWithDecrease;
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
        _winningPool = _bet * 2;
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
            uint256 gameCommision = _bet.mul(s_commissionPercentage).div(10000);
            uint256 refreeCommission = gameCommision
                .mul(s_refreeCommission)
                .div(10000);
            uint256 formattedGameCommission = gameCommision -
                s_refreeCommission;
            return (formattedGameCommission, refreeCommission);
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
        (uint256 lastTotalSupply, uint256 lastRecordedBalance) = ICryptoHands(
            s_cryptoHands
        ).getCryptoHandsToken(tokenId);
        claimableAmount = lastRecordedBalance.div(lastTotalSupply);
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

    function getRNG() external view returns (RNGInterface rng) {
        rng = s_rng;
    }

    function getCrytptoHands() external view returns (address cryptoHands) {
        cryptoHands = s_cryptoHands;
    }

    function getCommissionPercentage()
        external
        view
        returns (uint256 commissionPercentage)
    {
        commissionPercentage = s_commissionPercentage;
    }

    function getRefreeCommissionPercentage()
        external
        view
        returns (uint256 refreeCommissionPercentage)
    {
        refreeCommissionPercentage = s_refreeCommission;
    }

    function getDivider() external view returns (uint256 divider) {
        divider = s_divider;
    }

    function getTotalBets() external view returns (uint256 totalBets) {
        totalBets = s_totalBets.current();
    }

    function getPlayer(
        address player
    ) external view returns (Player memory currentPlayer) {
        currentPlayer = s_players[player];
    }

    function getBet(uint256 betId) external view returns (Bet memory bet) {
        bet = s_bets[betId];
    }

    function getBetAmounts()
        external
        view
        returns (uint256[5] memory betAmounts)
    {
        betAmounts = s_availableBets;
    }

    function getNFTWinPercentage()
        external
        view
        returns (uint256 NFTWinPercentage)
    {
        NFTWinPercentage = s_nftWinPercentage;
    }

    /***************************
     ******OWNER FUNCTIONS******
     ***************************/

    function updateRNG(RNGInterface rng_) external onlyOwner {
        s_rng = rng_;
        emit RNGUpdated(address(rng_));
    }

    function updateCryptoHands(address cryptoHands_) external onlyOwner {
        s_cryptoHands = cryptoHands_;
        emit CryptoHandsUPdated(cryptoHands_);
    }

    function updateCommissionPercentage(
        uint256 commission_
    ) external onlyOwner {
        s_commissionPercentage = commission_;
        emit CommissionPercentageUpdated(commission_);
    }

    function updateRefreeCommission(
        uint256 refreeCommision_
    ) external onlyOwner {
        s_refreeCommission = refreeCommision_;
        emit RefreeCommissionUpdated(refreeCommision_);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateDivider(uint256 divider_) external onlyOwner {
        s_divider = divider_;
        emit DividerUpdated(divider_);
    }

    function updateAvailableBets(
        uint256 index_,
        uint256 betAmount_
    ) external onlyOwner {
        require(index_ < s_availableBets.length, "GameEngineV2: Out of bound");
        s_availableBets[index_] = betAmount_;
        emit AvailableBetsUpdated(betAmount_);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /***************************
     *****UTILITY FUNCTIONS*****
     ***************************/

    receive() external payable {}

    function transferNative(address player, uint256 amount) internal {
        (bool hs, ) = payable(player).call{value: (amount)}("");
        require(hs, "GameEngineV2: Failed to transfer Token");
    }
}
