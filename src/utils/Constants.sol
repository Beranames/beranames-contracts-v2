// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// @param BERA_NODE The node hash of "bera"
bytes32 constant BERA_NODE = 0xcac7291742cc038df280cfdc67517aa5d83fe6f4716c336481273a83a877997b;

// @param REVERSE_NODE The node hash of "reverse"
bytes32 constant REVERSE_NODE = 0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34;

// @param ADDR_REVERSE_NODE The node hash of "addr.reverse"
bytes32 constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

// @param GRACE_PERIOD the grace period for expired names
uint256 constant GRACE_PERIOD = 30 days;

// @param RECLAIM_ID InterfaceId for the Reclaim interface
bytes4 constant RECLAIM_ID = bytes4(keccak256("reclaim(uint256,address)"));

uint64 constant DEFAULT_TTL = 3600;
