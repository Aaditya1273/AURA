// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseStrategy, StrategyParams} from "./AuraBaseStrategy.sol";
import {IXcm, XCM_PRECOMPILE_ADDRESS} from "./IXcm.sol";


interface IGroth16Verifier {
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[5] calldata _pubSignals
    ) external view returns (bool);
}

/**
 * @title AURA Commander
 * @author AURA Ecosystem
 * @notice The AURA Commander is an ERC-4626 compliant vault that aggregates yield
 * across multiple Polkadot-native strategies. It implements ZK-verified reporting.
 */
contract AuraCommander is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    // --- Yearn-compatible State ---
    mapping(address => StrategyParams) public strategies;
    address[] public withdrawalQueue;
    uint256 public totalDebt;
    uint256 public performanceFee = 1000;
    uint256 public constant MAX_BPS = 10000;


    // --- ZK CONFIG ---
    address public verifier;

    // --- Events ---
    event StrategyAdded(address indexed strategy, uint256 debtRatio);
    event StrategyRemoved(address indexed strategy);
    event StrategyReported(address indexed strategy, uint256 gain, uint256 loss, uint256 debtPaid);
    event VerifiedReport(uint256 totalAssets, uint256 timestamp);
    event XcmSent(bytes destination, bytes message);


    constructor(
        IERC20Metadata _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}

    // --- ZK Actions ---

    function setVerifier(address _verifier) external onlyOwner {
        verifier = _verifier;
    }

    /**
     * @notice Allows the Agent to report verified total assets across integrated parachains.
     */
    function reportWithProof(
        uint256 _totalAssets,
        uint256[2] calldata pA,
        uint256[2][2] calldata pB,
        uint256[2] calldata pC,
        uint256[5] calldata pubSignals
    ) external {
        if (verifier != address(0)) {
            require(
                IGroth16Verifier(verifier).verifyProof(pA, pB, pC, pubSignals),
                "Invalid ZK Proof"
            );
        }
        
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        if (_totalAssets >= idle) {
            totalDebt = _totalAssets - idle;
        } else {
            totalDebt = 0;
        }

        emit VerifiedReport(_totalAssets, block.timestamp);
    }

    /**
     * @notice Execute an XCM message via the Revive XCM Precompile.
     * @param destination SCALE-encoded MultiLocation destination.
     * @param message SCALE-encoded VersionedXCM message.
     */
    function executeXcm(bytes calldata destination, bytes calldata message) external onlyOwner {
        IXcm(XCM_PRECOMPILE_ADDRESS).send(destination, message);
        emit XcmSent(destination, message);
    }


    // --- VaultAPI / Yearn-compatible Views ---

    function apiVersion() external pure returns (string memory) {
        return "0.4.6";
    }

    function token() external view returns (address) {
        return asset();
    }

    function governance() external view returns (address) {
        return owner();
    }

    function management() external view returns (address) {
        return owner();
    }

    function guardian() external view returns (address) {
        return owner();
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + totalDebt;
    }

    function pricePerShare() external view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? 10**decimals() : (totalAssets() * 10**decimals()) / supply;

    }

    function depositLimit() external pure returns (uint256) {
        return type(uint256).max;
    }

    function creditAvailable() external pure returns (uint256) {
        return 0;
    }

    function debtOutstanding() external pure returns (uint256) {
        return 0;
    }

    function expectedReturn() external pure returns (uint256) {
        return 0;
    }

    // --- VaultAPI overloads for ERC-4626 ---

    function deposit(uint256 amount, address recipient) public override returns (uint256) {
        return super.deposit(amount, recipient);
    }

    function deposit(uint256 amount) external returns (uint256) {
        return deposit(amount, msg.sender);
    }

    function withdraw(uint256 shares, address recipient) public returns (uint256) {
        return super.withdraw(convertToAssets(shares), recipient, msg.sender);
    }

    // --- Yearn-compatible Actions ---

    function report(
        uint256 _gain,
        uint256 _loss,
        uint256 _debtPayment
    ) external returns (uint256) {
        require(strategies[msg.sender].activation > 0, "!strategy");
        StrategyParams storage params = strategies[msg.sender];
        
        params.totalGain += _gain;
        params.totalLoss += _loss;
        
        // Update debt
        if (_debtPayment + _loss <= params.totalDebt) {
            params.totalDebt -= (_debtPayment + _loss);
            totalDebt -= (_debtPayment + _loss);
        } else {
            totalDebt -= params.totalDebt;
            params.totalDebt = 0;
        }
        
        params.lastReport = block.timestamp;

        if (_debtPayment > 0) {
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), _debtPayment);
        }
        
        emit StrategyReported(msg.sender, _gain, _loss, _debtPayment);
        return 0; // debtOutstanding
    }

    function addStrategy(
        address _strategy,
        uint256 _debtRatio,
        uint256 _minDebtPerHarvest,
        uint256 _maxDebtPerHarvest,
        uint256 _performanceFee
    ) external onlyOwner {
        require(_strategy != address(0), "Invalid strategy");
        require(strategies[_strategy].activation == 0, "Exists");
        strategies[_strategy] = StrategyParams({
            performanceFee: _performanceFee,
            activation: block.timestamp,
            debtRatio: _debtRatio,
            minDebtPerHarvest: _minDebtPerHarvest,
            maxDebtPerHarvest: _maxDebtPerHarvest,
            lastReport: block.timestamp,
            totalDebt: 0,
            totalGain: 0,
            totalLoss: 0
        });
        withdrawalQueue.push(_strategy);
        emit StrategyAdded(_strategy, _debtRatio);
    }

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
            for (uint256 i = 0; i < withdrawalQueue.length; i++) {
                if (needed == 0) break;
                address strategy = withdrawalQueue[i];
                uint256 available = BaseStrategy(strategy).estimatedTotalAssets();
                uint256 amountToPull = available > needed ? needed : available;
                if (amountToPull > 0) {
                    BaseStrategy(strategy).withdraw(amountToPull);
                    needed -= amountToPull;
                }
            }
            require(needed == 0, "Liquidity");
        }
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}
