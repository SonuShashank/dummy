// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ERC1155Royalty.sol"; /* Royality related calculaation contract */

contract CreativeSocialNFT is
    ERC1155,
    Ownable,
    Pausable,
    ERC1155Supply,
    ERC1155Royalty
{
    /* Execute once on contract deployment with royaltyFraction and royalty receiver */

    constructor(uint96 royaltyPercentage, address royaltyReceiver) ERC1155("") {
        setDefaultRoyalty(royaltyReceiver, royaltyPercentage); // royalityReceiver may be zero address
    }

    /* NFTId that holds tokenId that increment on new item mint */
    using Counters for Counters.Counter;
    Counters.Counter private NFTId;
    using SafeMath for uint256;

    /* define struct for holds token and sale data */
    struct CreativeNFT {
        string tokenURI;
        address minter;
        uint96 royalty;
        mapping(address => uint256) salePrice;
        mapping(address => uint256) onSale;
        mapping(address => uint256) buyLimit;
    }

    /* Map all CreativeNFT to  CreativeNFTs*/
    mapping(uint256 => CreativeNFT) public CreativeNFTs;

    /* To check only token minter is allowed */
    modifier tokenMinterOnly(uint256 tokenId) {
        CreativeNFT storage nft = CreativeNFTs[tokenId];
        require(
            nft.minter == _msgSender(),
            "CreativeSocialNFT: tokenHolder allowed to mint or burn"
        );
        _;
    }

    /* Mint with Quantities, saleQauntity, unit price, currency,royaltyFraction */
    function mint(
        uint256 quantitities,
        uint256 unitPrice,
        uint256 saleQuantity,
        uint256 buyLimit,
        string calldata tokenURI,
        uint96 royaltyPercentage
    ) public returns (uint256 tokenId) {
        NFTId.increment();
        tokenId = NFTId.current();
        address minter = _msgSender();
        require(
            quantitities >= 1,
            "ERC1155: quantity should be equal or greater than 1"
        );
        require(
            bytes(tokenURI).length >= 1,
            "ERC1155: uri should not be empty"
        );
        require(unitPrice >= 1, "ERC1155: unit price required");
        require(
            buyLimit <= saleQuantity,
            "ERC1155: buy Limit should be  equal or greater than saleQuantity"
        );
        require(
            saleQuantity <= quantitities,
            "ERC1155: saleQuantity should not be more than total quantity"
        );
        _mint(minter, tokenId, quantitities, "");
        if (bytes(tokenURI).length > 0) {
            emit URI(tokenURI, tokenId);
        }
        setTokenRoyalty(tokenId, minter, royaltyPercentage);
        CreativeNFT storage newNFT = CreativeNFTs[tokenId];
        newNFT.tokenURI = tokenURI;
        newNFT.minter = minter;
        newNFT.royalty = royaltyPercentage;
        newNFT.salePrice[minter] = unitPrice;
        newNFT.onSale[minter] = saleQuantity;
        newNFT.buyLimit[minter] = buyLimit;
    }

    /* Pause contract for execution - stopped state */
    function pause() public onlyOwner {
        _pause();
    }

    /* Unpause contract return to normal state */
    function unpause() public onlyOwner {
        _unpause();
    }

    /* Return token original owner  */
    function ownerOf(uint256 tokenId) internal view virtual returns (address) {
        require(_exists(tokenId), "CreativeSocialNFT: TokenId not found!");
        address owner = CreativeNFTs[tokenId].minter;
        require(owner != address(0), "ERC1155: token not exist!");
        return owner;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return CreativeNFTs[tokenId].minter != address(0);
    }

    /* Token minter can add more quantity - only original owner */
    function addOnSupply(
        address account,
        uint256 tokenId,
        uint256 quantity,
        bytes memory data
    ) public tokenMinterOnly(tokenId) {
        require(account != address(0), "ERC1155: mint from the zero address");
        require(_exists(tokenId), "CreativeSocialNFT: TokenId not found!");
        _mint(account, tokenId, quantity, data);
    }

    /* Token minter can burn quantity - only original owner */
    function burnSupply(
        address account,
        uint256 tokenId,
        uint256 quantity
    ) public virtual tokenMinterOnly(tokenId) {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(_exists(tokenId), "CreativeSocialNFT: TokenId not found!");
        require(
            balanceOf(account, tokenId) >= quantity,
            "CreativeSocialNFT: burn quantity exceeds."
        );
        _burn(account, tokenId, quantity);
    }

    /* Update token price per unit */
    function updateTokenPrice(
        address account,
        uint256 tokenId,
        uint256 unitPrice
    ) public whenNotPaused {
        require(
            account == _msgSender(),
            "CreativeSocialNFT: only tokenHolder allowed"
        );
        require(_exists(tokenId), "CreativeSocialNFT: TokenId not found!");
        require(unitPrice >= 1, "ERC1155: unit price required");
        require(
            balanceOf(account, tokenId) > 0,
            "CreativeSocialNFT: not have sufficient balance for update unit price"
        );
        CreativeNFT storage nft = CreativeNFTs[tokenId];
        nft.salePrice[account] = unitPrice;
    }

    /* Add token for sale it would be resale or new sale */
    function addOnSale(
        uint256 tokenId,
        uint256 unitPrice,
        uint256 saleQuantity,
        uint256 buyLimit
    ) public whenNotPaused {
        address account = _msgSender();
        require(_exists(tokenId), "CreativeSocialNFT: TokenId not found!");
        require(unitPrice >= 1, "ERC1155: unit price required");
        require(saleQuantity >= 1, "ERC1155: saleQuantity required");
        require(
            buyLimit <= saleQuantity,
            "ERC1155: buy Limit should be  equal or greater than saleQuantity"
        );
        uint256 quantity = balanceOf(account, tokenId);
        CreativeNFT storage nft = CreativeNFTs[tokenId];
        require(
            nft.onSale[account].add(saleQuantity) <= quantity,
            "ERC1155: saleQuantity should not be more than total quantity"
        );
        nft.salePrice[account] = unitPrice;
        nft.buyLimit[account] = buyLimit;
        nft.onSale[account] = nft.onSale[account].add(saleQuantity);
    }

    function getsaleQuantities(uint256 tokenId) public view returns (uint256) {
        uint256 currentId = NFTId.current();
        require(tokenId <= currentId, "ERC1155: query for non existent token");
        address owner = CreativeNFTs[tokenId].minter;
        require(
            _msgSender() == owner,
            "ProtoNFT: only tokenHolder allowed to check the onsale tokens"
        );
        return CreativeNFTs[tokenId].onSale[owner];
    }

    /* Remove quantity from sale */
    function cancelSale(
        address account,
        uint256 tokenId,
        uint256 cancelQuantity
    ) public whenNotPaused {
        require(account == _msgSender(), "HumblNFT: only tokenHolder allowed");
        require(_exists(tokenId), "HumblNFT: TokenId not found!");
        require(cancelQuantity >= 1, "ERC1155: cancelQuantity required");
        CreativeNFT storage nft = CreativeNFTs[tokenId];
        require(
            cancelQuantity <= nft.onSale[account],
            "HumblNFT: cancel quantity can not more than on sale"
        );
        nft.onSale[account] = nft.onSale[account].sub(cancelQuantity);
    }

    /* Return unit price of token from sale */
    function getUnitPrice(uint256 tokenId, address owner)
        public
        view
        returns (uint256)
    {
        require(_exists(tokenId), "CreativeSocialNFT: TokenId not found!");
        CreativeNFT storage nft = CreativeNFTs[tokenId];
        return nft.salePrice[owner];
    }

    /*Override setApprovalForAll function*/
    function setApprovalForAll(address operator, bool approved)
        public
        view
        override
    {
        // Change this function as per requirment
    }

    /*Override isApprovedForAll function*/
    function isApprovedForAll(address, address)
        public
        pure
        override
        returns (bool)
    {
        // Change this function as per requirment
        return false;
    }

    /*Override safeTransferFrom function*/
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        // Change this function as per requirment
    }

    /*Override safeBatchTransferFrom function*/
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amount,
        bytes memory data
    ) public virtual override {
        // Change this function as per requirment
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
