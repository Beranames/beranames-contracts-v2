// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IReservedRegistry} from "src/registrar/interfaces/IReservedRegistry.sol";

import {StringUtils} from "src/utils/StringUtils.sol";

contract ReservedRegistry is Ownable, IReservedRegistry {
    using StringUtils for string;

    /// Errors -----------------------------------------------------------

    /// @dev Thrown when a name is already reserved.
    error NameAlreadyReserved(string name);

    /// @dev Thrown when the index is out of bounds.
    error IndexOutOfBounds();

    /// State ------------------------------------------------------------

    mapping(bytes32 => string) private _reservedNames;

    bytes32[] private _reservedNamesList;
    uint256 private _reservedNamesCount;

    /// Constructor ------------------------------------------------------

    constructor(address owner_) Ownable(owner_) {}

    /// Admin Functions  ---------------------------------------------------

    /// @dev Sets a reserved name.
    /// @param name_ The name to set as reserved.
    function setReservedName(string calldata name_) public onlyOwner {
        bytes32 labelHash_ = keccak256(abi.encodePacked(name_));
        if (isReservedName(name_)) revert NameAlreadyReserved(name_);

        _reservedNames[labelHash_] = name_;
        _reservedNamesList.push(labelHash_);
        _reservedNamesCount++;
    }

    /// @dev Removes a reserved name.
    /// @param index_ The index of the reserved name to remove.
    /// @dev After deleting the name, we swap the last element in the array with the one we are deleting to avoid re-indexing.
    function removeReservedName(uint256 index_) public onlyOwner {
        if (index_ >= _reservedNamesCount) revert IndexOutOfBounds();

        bytes32 labelHash_ = _reservedNamesList[index_];
        delete _reservedNames[labelHash_];
        _reservedNamesList[index_] = _reservedNamesList[_reservedNamesCount - 1];
        _reservedNamesList.pop();
        _reservedNamesCount--;
    }

    /// Accessors --------------------------------------------------------

    function reservedNamesCount() public view returns (uint256) {
        return _reservedNamesCount;
    }

    function reservedName(uint256 index_) public view returns (string memory) {
        return _reservedNames[_reservedNamesList[index_]];
    }

    function isReservedName(string calldata name_) public view returns (bool) {
        return _reservedNames[keccak256(abi.encodePacked(name_))].strlen() > 0;
    }
}
