// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface ICryptoHands {
    event PriceUpdated(uint256 newPrice);

    event BaseUriUpdated(string newBaseUri);

    event HiddenUriUpdated(string newHiddenUri);

    event PresaleToggled();

    event RootHashUpdated(bytes32 newRootHash);

    event WhitelistAdded(address user);

    event WhitelistRemoved(address user);

    event Revealed();

    event HandsMinted(address receiver, uint256 amount);

    event HandsWon(address winner);

    event GameAddressUpdated(address game);

    event NftMintLimitUpdated(uint256 newmintLimit);

    function mintHands(uint256 _mintAmount) external payable;

    function winHands(address _winner) external;

    function revealHands() external;

    function addWhitelist(address[] memory _addresses) external;

    function removeWhitelist(address[] memory _addresses) external;

    function updatePrice(uint256 _price) external;

    function updateBaseUri(string memory _baseUri) external;

    function updateGameAddress(address _game) external;

    function updateNftMintLimit(uint256 _nftMintLimit) external;

    function updateHiddenUri(string memory _hiddenUri) external;

    function pause() external;

    function unpause() external;

    function togglePresale() external;

    function tokenURI(uint256 _tokenId)
        external
        view
        returns (string memory _tokenUri);

    function getPrice() external view returns (uint256 _price);

    function getBaseUri() external view returns (string memory _baseUri);

    function getHiddenUri() external view returns (string memory _hiddenUri);

    function getMaxHands() external view returns (uint256 _maxHands);

    function getMaxHandsAvailableToMint()
        external
        view
        returns (uint256 _maxHandsAvailableToMint);

    function getMaxHandsAvailableToWin()
        external
        view
        returns (uint256 _maxHandsAvailableToWin);

    function getTotalHandsMinted()
        external
        view
        returns (uint256 _totalHandsMinted);

    function getTotalHandsWinned()
        external
        view
        returns (uint256 _totalHandsWinned);

    function getIsPresale() external view returns (bool _isPresale);

    function getNftMintLimit() external view returns (uint256 _nftMintLimit);

    function getGameAddress() external view returns (address _game);

    function getMaxHandsPerTx() external view returns (uint256 _maxHandsPerTx);
}
