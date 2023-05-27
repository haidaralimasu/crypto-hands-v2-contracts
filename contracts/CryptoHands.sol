// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ICryptoHands} from "./interfaces/ICryptoHands.sol";

contract CryptoHands is
    ERC721A,
    Ownable,
    ReentrancyGuard,
    Pausable,
    ICryptoHands
{
    using Strings for uint256;
    using Counters for Counters.Counter;

    uint256 private immutable i_maxHands = 2000;
    uint256 private immutable i_maxHandsAvailableToMint = 1000;

    string private s_baseUri;
    string private s_hiddenUri;

    uint256 private s_price = 0.01 ether;
    uint256 private s_maxHandsPerTx = 3;
    uint256 private s_cryptoHandsLimit = 3;

    bool private s_isPresale = true;
    bool private s_isRevealed = false;

    uint256 private s_totalMinted;
    Counters.Counter private s_totalWinned;

    address private s_game;

    mapping(address => bool) public s_isWhitelist;

    constructor(
        string memory _baseUri,
        string memory _hiddenUri
    ) ERC721A("CryptoHands", "CH") {
        s_baseUri = _baseUri;
        s_hiddenUri = _hiddenUri;
    }

    modifier onlyGame() {
        require(
            msg.sender == s_game,
            "CryptoHands: Caller is not Game Contract"
        );
        _;
    }

    modifier winCompliance() {
        require(
            s_totalWinned.current() <= i_maxHands - s_totalMinted,
            "CryptoHands: All Available Hands Wonned"
        );
        _;
    }

    modifier mintComplaince(address _receiver, uint256 _mintAmount) {
        require(
            s_totalMinted <= i_maxHandsAvailableToMint,
            "CryptoHands: All Available Hands Minted"
        );
        _;
        require(
            s_totalMinted + _mintAmount <= i_maxHandsAvailableToMint,
            "CryptoHands: Incorrect Amount"
        );
        _;
        if (s_isPresale == true) {
            require(
                s_isWhitelist[_receiver] == true,
                "CryptoHands: Caller is not Whitelist"
            );
            _;
            require(
                _mintAmount + _numberMinted(_receiver) <= s_cryptoHandsLimit,
                "Mint limit exceed"
            );
            _;
        }
    }

    function mintHands(
        uint256 _mintAmount
    )
        external
        payable
        override
        mintComplaince(msg.sender, _mintAmount)
        nonReentrant
        whenNotPaused
    {
        require(
            msg.value == s_price * _mintAmount,
            "CryptoHands: Insufficient Funds"
        );
        _mintHands(msg.sender, _mintAmount);
        s_totalMinted = s_totalMinted + _mintAmount;
        emit HandsMinted(msg.sender, _mintAmount);
    }

    function winHands(
        address _winner
    ) external override winCompliance onlyGame whenNotPaused {
        _mintHands(_winner, 1);
        emit HandsWon(_winner);
    }

    function _mintHands(address _receiver, uint256 _mintAmount) internal {
        _safeMint(_receiver, _mintAmount);
    }

    function revealHands() external override onlyOwner {
        s_isRevealed = true;
        emit Revealed();
    }

    function addWhitelist(
        address[] memory _addresses
    ) external override onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            s_isWhitelist[_addresses[i]] = true;
            emit WhitelistAdded(_addresses[i]);
        }
    }

    function removeWhitelist(
        address[] memory _addresses
    ) external override onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            s_isWhitelist[_addresses[i]] = false;
            emit WhitelistRemoved(_addresses[i]);
        }
    }

    function updatePrice(uint256 _price) external override onlyOwner {
        s_price = _price;
        emit PriceUpdated(_price);
    }

    function updateBaseUri(string memory _baseUri) external override onlyOwner {
        s_baseUri = _baseUri;
        emit BaseUriUpdated(_baseUri);
    }

    function updateGameAddress(address _game) external override onlyOwner {
        s_game = _game;
        emit GameAddressUpdated(_game);
    }

    function updateHiddenUri(
        string memory _hiddenUri
    ) external override onlyOwner {
        s_hiddenUri = _hiddenUri;
        emit HiddenUriUpdated(_hiddenUri);
    }

    function updateNftMintLimit(
        uint256 _mintLimit
    ) external override onlyOwner {
        s_cryptoHandsLimit = _mintLimit;
        emit NftMintLimitUpdated(_mintLimit);
    }

    function pause() external override onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external override onlyOwner whenPaused {
        _unpause();
    }

    function togglePresale() external override onlyOwner {
        s_isPresale = !s_isPresale;
        emit PresaleToggled();
    }

    function tokenURI(
        uint256 _tokenId
    )
        public
        view
        virtual
        override(ERC721A, ICryptoHands)
        returns (string memory _tokenUri)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (s_isRevealed == false) {
            _tokenUri = s_hiddenUri;
        }

        string memory currentBaseURI = _baseURI();
        _tokenUri = bytes(currentBaseURI).length > 0
            ? string(
                abi.encodePacked(currentBaseURI, _tokenId.toString(), ".json")
            )
            : "";
    }

    function _baseURI()
        internal
        view
        virtual
        override
        returns (string memory _baseUri)
    {
        _baseUri = s_baseUri;
    }

    function getPrice() external view override returns (uint256 _price) {
        _price = s_price;
    }

    function getNftMintLimit()
        external
        view
        override
        returns (uint256 _nftMintLimit)
    {
        _nftMintLimit = s_cryptoHandsLimit;
    }

    function getBaseUri()
        external
        view
        override
        returns (string memory _baseUri)
    {
        _baseUri = s_baseUri;
    }

    function getHiddenUri()
        external
        view
        override
        returns (string memory _hiddenUri)
    {
        _hiddenUri = s_hiddenUri;
    }

    function getMaxHands() external pure override returns (uint256 _maxHands) {
        _maxHands = i_maxHands;
    }

    function getMaxHandsAvailableToMint()
        external
        pure
        override
        returns (uint256 _maxHandsAvailableToMint)
    {
        _maxHandsAvailableToMint = i_maxHandsAvailableToMint;
    }

    function getMaxHandsAvailableToWin()
        external
        pure
        override
        returns (uint256 _maxHandsAvailableToWin)
    {
        _maxHandsAvailableToWin = i_maxHands - i_maxHandsAvailableToMint;
    }

    function getTotalHandsMinted()
        external
        view
        override
        returns (uint256 _totalHandsMinted)
    {
        _totalHandsMinted = s_totalMinted;
    }

    function getTotalHandsWinned()
        external
        view
        override
        returns (uint256 _totalHandsWinned)
    {
        _totalHandsWinned = s_totalWinned.current();
    }

    function getIsPresale() external view override returns (bool _isPresale) {
        _isPresale = s_isPresale;
    }

    function getGameAddress() external view override returns (address _game) {
        _game = s_game;
    }

    function getMaxHandsPerTx()
        external
        view
        override
        returns (uint256 _maxHandsPerTx)
    {
        _maxHandsPerTx = s_maxHandsPerTx;
    }

    function withdraw() external onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
}
