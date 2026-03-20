// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseStrategy} from "./AuraBaseStrategy.sol";

/**
 * @title AURA Commander
 * @author AURA Ecosystem
 * @notice The AURA Commander is an ERC-4626 compliant vault that aggregates yield
 * across multiple Polkadot-native strategies. It acts as the "Control Tower"
 * for the AURA ecosystem on Polkadot Hub.
 */
contract AuraCommander is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    // Queue of strategies to withdraw from in order of priority (liquidity/yield impact)
    address[] public withdrawalQueue;
    
    // Mapping to track if a strategy is active
    mapping(address => bool) public isStrategyActive;

    // Performance fee (default 10%) - basis points (1000 = 10%)
    uint256 public performanceFee = 1000;
    uint256 public constant MAX_BPS = 10000;

    // --- Events ---
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event StrategyReported(address indexed strategy, uint256 gain, uint256 loss, uint256 debtPaid);

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}

    // --- Public Views ---

    /**
     * @notice Total assets including all funds deployed to strategies.
     */
    function totalAssets() public view override returns (uint256) {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        uint256 deployed = 0;
        
        for (uint256 i = 0; i < withdrawalQueue.length; i++) {
            deployed += BaseStrategy(withdrawalQueue[i]).estimatedTotalAssets();
        }
        
        return idle + deployed;
    }

    // --- Admin Actions ---

    /**
     * @notice Adds a strategy to the vault's management.
     */
    function addStrategy(address _strategy) external onlyOwner {
        require(_strategy != address(0), "Invalid strategy");
        require(!isStrategyActive[_strategy], "Strategy already exists");
        
        isStrategyActive[_strategy] = true;
        withdrawalQueue.push(_strategy);
        
        // Ensure the strategy wants the same asset
        require(BaseStrategy(_strategy).want() == asset(), "Asset mismatch");
        
        emit StrategyAdded(_strategy);
    }

    /**
     * @notice Removes a strategy from the withdrawal queue.
     */
    function removeStrategy(address _strategy) external onlyOwner {
        require(isStrategyActive[_strategy], "Strategy not active");
        
        isStrategyActive[_strategy] = false;
        
        // Remove from withdrawal queue (index-shifting cleanup)
        for (uint256 i = 0; i < withdrawalQueue.length; i++) {
            if (withdrawalQueue[i] == _strategy) {
                withdrawalQueue[i] = withdrawalQueue[withdrawalQueue.length - 1];
                withdrawalQueue.pop();
                break;
            }
        }
        
        emit StrategyRemoved(_strategy);
    }

    // --- Internal Hooks ---

    /**
     * @notice Pulls funds from strategies if idle balance is insufficient for withdrawal.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        
        if (assets > idle) {
            uint256 needed = assets - idle;
            
            // Iterate through queue to liquidate sufficient funds
            for (uint256 i = 0; i < withdrawalQueue.length; i++) {
                if (needed == 0) break;
                
                address strategy = withdrawalQueue[i];
                uint256 available = BaseStrategy(strategy).estimatedTotalAssets();
                uint256 amountToPull = available > needed ? needed : available;
                
                if (amountToPull > 0) {
                    // Logic to pull funds from strategy
                    // Note: BaseStrategy must have a mechanism for vault to pull funds
                    // In Yearn, this is usually triggered by the strategy reporting or a direct withdraw call
                    // For AURA, we ensure BaseStrategy.withdraw() is callable by vault.
                    BaseStrategy(strategy).withdraw(amountToPull);
                    needed -= amountToPull;
                }
            }
            require(needed == 0, "Insufficient liquidity");
        }
        
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /**
     * @notice Allows the vault to push unused funds into strategies.
     * For AURA, we might implement a simple rebalance or manual push by governance.
     */
    function depositIntoStrategy(address _strategy, uint256 _amount) external onlyOwner {
        require(isStrategyActive[_strategy], "Strategy not active");
        IERC20(asset()).safeTransfer(_strategy, _amount);
        // BaseStrategy usually has an internal hook for deposit or just accounts for balance
    }
}
