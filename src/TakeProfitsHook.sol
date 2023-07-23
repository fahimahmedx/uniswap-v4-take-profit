// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseHook} from "periphery-next/BaseHook.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/libraries/PoolId.sol";

contract TakeProfitsHook is BaseHook, ERC1155 {
    constructor(IPoolManager _poolManager, string memory _uri) BaseHook(_poolManager) ERC1155(_uri) {}

    using PoolIdLibrary for IPoolManager.PoolKey;
    mapping(PoolId poolId => int24 tickLower) public tickLowerLasts;
    mapping(PoolId poolId => mapping(int24 tick => mapping(bool zeroForOne => int256 amount))) public takeProfitPositions;
    mapping(uint256 tokenId => bool exists) public tokenIdExists;
    mapping(uint256 tokenId => uint256 claimable) public tokenIdClaimable;
    mapping(uint256 tokenId => uint256 supply) public tokenIdTotalSupply;
    mapping(uint256 tokenId => tokenData) public tokenIdData;

    struct TokenData {
        IPoolManager.PoolKey poolKey;
        int24 tick;
        bool zeroForOne;
    }

    function getHooksCall() public pure override returns (Hooks.Calls memory) {
        return Hooks.Call({
            beforeInitialize: false,
            afterInitialize: true,
            beforeModifyPosition: false,
            afterModifyPosition: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }

    function afterInitialize(address, iPoolManager.PoolKey calldata key, uint160, int24 tick) external override poolManagerOnly returns (bytes4) {
        _setTickLowerLast(key.toId(), _getTickLower(tick, key.tickSpacing));
        return TakeProfitsHook.afterInitialize.selector;
    }

    // For ERC-1155 TokenIDs 
    function getTokenId(IPoolManager.PoolKey calldata key, int24 tickLower, bool zeroForOne) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(key.toId(), tickLower, zeroForOne)));
    }
    
    function _setTickLowerLast(PoolId poolId, int24 tickLower) private {
        tickLowerLasts[poolId] = tickLower;
    }

    function _getTickLower(int24 actualTick, int24 tickSpacing) private pure returns (int24) {
        int24 intervals = actualTick / tickSpacing;
        if (actualTick < 0 && actualTick % tickSpacing != 0) intervals--; // round towards negative infinity if negative & it needs to be rounded
            return intervals * tickSpacing;
        }
}