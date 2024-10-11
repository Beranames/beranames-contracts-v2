// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {IReservedRegistry} from "src/registrar/interfaces/IReservedRegistry.sol";

import {StringUtils} from "src/utils/StringUtils.sol";

contract ReservedRegistry is Ownable, IReservedRegistry {
    using StringUtils for string;

    /// State ------------------------------------------------------------

    mapping(bytes32 => string) private _reservedNames;

    bytes32[] private _reservedNamesList;
    uint256 private _reservedNamesCount;

    /// Constructor ------------------------------------------------------

    constructor(address owner_) Ownable(owner_) {
        _transferOwnership(owner_);
    }

    /// Admin Functions  ---------------------------------------------------

    function setReservedName(string calldata name_) public onlyOwner {
        bytes32 labelHash_ = keccak256(abi.encodePacked(name_));
        _reservedNames[labelHash_] = name_;
        _reservedNamesList.push(labelHash_);
        _reservedNamesCount++;
    }

    function removeReservedName(uint256 index_) public onlyOwner {
        bytes32 labelHash_ = _reservedNamesList[index_];
        delete _reservedNames[labelHash_];
        _reservedNamesList[index_] = _reservedNamesList[_reservedNamesCount - 1];
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
