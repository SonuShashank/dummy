// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;
import "./ERC2981.sol";

contract ERC1155Royalty is ERC2981 { 
    // royality 
    function setTokenRoyalty(
        uint256 tokenId,
        address recipient,
        uint96 fraction
    ) public {
        _setTokenRoyalty(tokenId, recipient, fraction);
    }

    function setDefaultRoyalty(address recipient, uint96 fraction) public {
        _setDefaultRoyalty(recipient, fraction);
    }

    function deleteDefaultRoyalty() public {
        _deleteDefaultRoyalty();
    }
   
    function _feeDenominator() internal pure virtual override returns (uint96) {
        return 100;
    }
   
}