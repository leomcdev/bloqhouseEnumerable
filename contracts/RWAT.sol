// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/ICNR.sol";

/**
 * @title Real world asset tokenization contract to fractionalize real-estate into shares.
 * @dev Should hold no data directly to be easily upgraded
 *
 * Upgrading this contract and adding new parent can be done while there is no dynamic
 * state variables in this contract. All new inherited contracts must be appeneded
 * to the currently inherited contracts.
 */

contract RWAT is
    Initializable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    bytes32 public constant ADMIN = keccak256("ADMIN");

    /**
     * @notice Called first in the initialize (RWAT) contract upon deployment. Functions with
     * state variables that are not stated as CONSTANTS are required to be declared with
     * the onlyInitalizing statement, to not interrupt the initialize call in the RWAT contract.
     */

    function initialize(
        address _default_admin,
        string memory _name,
        string memory _symbol,
        ICNR _CNR
    ) external initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _default_admin);

        __ERC721_init(_name, _symbol);

        CNR = _CNR;
        __Pausable_init();
    }

    // ------------ Events
    event UnitsClaimed(address claimant, uint256[] tokenIds);
    event EarningsClaimed(
        address claimant,
        uint256 assetId,
        uint256[] tokenIds
    );

    ICNR private CNR;
    mapping(address => bool) public isWhitelisted;

    bool pausedTransfers;
    bool whitelistDisabled;
    mapping(uint256 => bool) public assetPaused;

    mapping(uint256 => uint256) private nextId;
    mapping(uint256 => uint256) private lastId;

    mapping(uint256 => IERC20Upgradeable) public assetEarningsToken;
    mapping(uint256 => uint256) public totalShareEarnings;
    mapping(uint256 => uint256) public claimedEarnings;

    mapping(uint256 => uint256) private assetIdToAssetCap;

    address serverPubKey;
    string name_;
    string symbol_;

    /**
     * @notice Creates the asset with a token cap.
     * @dev 9 zeros are added.
     */
    function createAsset(
        uint256 _assetId,
        uint256 _tokenCap,
        IERC20Upgradeable _EarningsToken
    ) external onlyRole(ADMIN) {
        require(nextId[_assetId] == 0, "Asset already exists");
        require(
            nextId[_assetId] < _tokenCap,
            "Asset ID can't be higher than max token cap"
        );
        assetEarningsToken[_assetId] = _EarningsToken;
        nextId[_assetId] = _assetId * 1_000_000_000;
        lastId[_assetId] = _assetId * 1_000_000_000 + _tokenCap;

        assetIdToAssetCap[_assetId] = _tokenCap;
    }

    /**
     * @notice Updates asset cap.
     */
    function updateAssetCap(uint256 _assetId, uint256 _tokenCap)
        external
        onlyRole(ADMIN)
    {
        require(
            nextId[_assetId] <= _assetId * 1_000_000_000 + _tokenCap,
            "Asset cap can not be lower than minted amount"
        );
        lastId[_assetId] = _assetId * 1_000_000_000 + _tokenCap;

        assetIdToAssetCap[_assetId] = _tokenCap;
    }

    /**
     * @notice Mints assets with respective ID as long as the max amount
     * of minted assets has not been exceeded.
     */

    function mintAsset(uint256 _assetId, uint256 _amount)
        external
        onlyRole(ADMIN)
    {
        require(
            (nextId[_assetId] + _amount) <= lastId[_assetId],
            "Amount exceeds max"
        );
        uint256 mints = nextId[_assetId] + _amount;

        for (uint256 i = nextId[_assetId]; i < mints; i++) {
            _mint(address(this), i);
        }
        nextId[_assetId] = mints;
    }

    /**
     * @notice Lets user claim units in the shape of nfts
     * @dev Requires server sig and the token asset to exist.
     */
    function claimUnits(
        uint256[] calldata _tokenIds,
        bytes memory _prefix,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external whenNotPaused {
        bytes memory message = abi.encode(msg.sender, address(this), _tokenIds);
        require(
            ecrecover(
                keccak256(abi.encodePacked(_prefix, message)),
                _v,
                _r,
                _s
            ) == serverPubKey,
            "Invalid signature"
        );

        uint256 assetId = _getTokenAsset(_tokenIds[0]);
        uint256 totalClaim = totalShareEarnings[assetId];
        _setClaimed(assetId, _tokenIds, totalClaim);
        _claimUnits(address(this), msg.sender, _tokenIds);
        emit UnitsClaimed(msg.sender, _tokenIds);
    }

    function claimEarnings(
        uint256[] calldata _tokenIds,
        uint256 _amount,
        uint256 _assetId,
        bytes memory _prefix,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external whenNotPaused {
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; i++) {
            require(ownerOf(_tokenIds[i]) == msg.sender, "Invalid token owner");
            require(
                _getTokenAsset(_tokenIds[i]) == _assetId,
                "Invalid token for asset"
            );
        }
        bytes memory message = abi.encode(
            msg.sender,
            address(this),
            _tokenIds,
            _amount,
            _assetId
        );
        require(
            ecrecover(
                keccak256(abi.encodePacked(_prefix, message)),
                _v,
                _r,
                _s
            ) == serverPubKey,
            "Invalid signature"
        );

        assetEarningsToken[_assetId].transferFrom(
            address(this),
            msg.sender,
            _amount
        );
        emit EarningsClaimed(msg.sender, _assetId, _tokenIds);
    }

    /**
     * @dev Returns the unit from an investor.
     */
    function returnUnits(
        address _from,
        address _to,
        uint256[] calldata _tokenIds
    ) external onlyRole(ADMIN) {
        _claimUnits(_from, _to, _tokenIds);
    }

    /**
     * @notice Whitelists multiple users to be available for shares.
     * @dev Also deWhitelists users by setting to false.
     */
    function setWhitelisted(address[] calldata _users, bool _whitelisted)
        external
        onlyRole(ADMIN)
    {
        uint256 length = _users.length;
        for (uint256 i = 0; i < length; i++) {
            isWhitelisted[_users[i]] = _whitelisted;
        }
    }

    /**
     * @notice Used for users to claim units.
     */
    function _claimUnits(
        address _from,
        address _to,
        uint256[] calldata _tokenIds
    ) internal {
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; i++) {
            _transfer(_from, _to, _tokenIds[i]);
        }
    }

    /**
     * @notice Set units to claimed.
     */
    function _setClaimed(
        uint256 _assetId,
        uint256[] calldata _tokenIds,
        uint256 _amount
    ) internal {
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; i++) {
            require(
                _getTokenAsset(_tokenIds[i]) == _assetId,
                "Invalid token for asset"
            );
            claimedEarnings[_tokenIds[i]] = _amount;
        }
    }

    /**
     * @notice Lets admin transfer units to user thats not whitelited.
     */
    function sendSharesToUser(
        uint256 _assetId,
        address _to,
        uint256 _amount,
        uint256[] calldata _tokenIds
    ) external onlyRole(ADMIN) {
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; i++) {
            require(
                address(this) == ownerOf(_tokenIds[i]),
                "NFTs needs to be owned by this contract or yet to be minted"
            );
        }
        require(
            _amount == length,
            "Amount and amount of nfts to send needs to be the same"
        );
        _setClaimed(_assetId, _tokenIds, _amount);
        _claimUnits(address(this), _to, _tokenIds);
    }

    function setTransfersPaused(bool _paused) external onlyRole(ADMIN) {
        pausedTransfers = _paused;
    }

    function setAssetTransfersPaused(uint256 _assetId, bool _paused)
        external
        onlyRole(ADMIN)
    {
        assetPaused[_assetId] = _paused;
    }

    function updateServer(address _serverPubKey) external onlyRole(ADMIN) {
        serverPubKey = _serverPubKey;
    }

    function pause() external onlyRole(ADMIN) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN) {
        _unpause();
    }

    /**
     * @notice Get current asset cap
     */
    function getAssetCap(uint256 _assetId) public view returns (uint256) {
        return assetIdToAssetCap[_assetId];
    }

    /**
     * @notice Get total minted assets in circulation
     */
    function getTotalMinted(uint256 _assetId) public view returns (uint256) {
        return nextId[_assetId] - 1_000_000_000;
    }

    function _getTokenAsset(uint256 _tokenId) internal pure returns (uint256) {
        return _tokenId / 1_000_000_000;
    }

    /**
     * @notice Set and update name and symbol after deployment!
     */
    function setNameAndSymbol(string memory _name, string memory _symbol)
        external
        onlyRole(ADMIN)
    {
        name_ = _name;
        symbol_ = _symbol;
    }

    function name() public view override returns (string memory) {
        return name_;
    }

    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    /**
     * @notice Overrides the _beforeTokenTransfer in the ERC721Upgradeable contract
     * @dev Checks state and that users are whitelisted.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        if (!(from == address(0) || from == address(this))) {
            require(!pausedTransfers, "Transfers are currently paused");
            require(!assetPaused[_getTokenAsset(tokenId)], "Asset is paused");
            // consider putting the if requirement and buy with crypto for the future
            // if (!whitelistDisabled) {
            require(
                isWhitelisted[from] && isWhitelisted[to],
                "Invalid token transfer"
            );
            // }
        }
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return ICNR(CNR).getNFTURI(address(this), _tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    uint256[1000] private __gap;
}
