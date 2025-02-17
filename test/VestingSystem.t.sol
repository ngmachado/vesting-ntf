// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./helpers/SuperfluidHelper.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {VestingSessionManager} from "../src/VestingSessionManager.sol";
import {VestingFactory} from "../src/VestingFactory.sol";
import {Vesting} from "../src/VestingStream.sol";
import {IVestingFactory} from "../src/interfaces/IVestingFactory.sol";

contract VestingSystemTest is SuperfluidHelper {
    using SuperTokenV1Library for ISuperToken;

    uint256 public constant INITIAL_BALANCE = 1_000_000 ether;
    int96 public constant STREAM_RATE = 155555555;

    address public constant ADMIN = address(0x420);
    address public constant TREASURY = address(0x421);
    address public constant ALICE = address(0x1);
    address public constant BOB = address(0x2);
    address public constant CAROL = address(0x3);

    address[] internal _testAccounts = [ADMIN, TREASURY, ALICE, BOB, CAROL];

    VestingSessionManager public sessionManager;

    function setUp() public virtual {
        setupSuperfluid();

        vm.startPrank(ADMIN);
        sessionManager = new VestingSessionManager(ADMIN);
        vm.stopPrank();

        for (uint256 i; i < _testAccounts.length; ++i) {
            mintSuperTokens(_testAccounts[i], INITIAL_BALANCE);
        }
    }

    function testCreateSession() public {
        vm.startPrank(ADMIN);

        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );

        VestingSessionManager.Session memory session = sessionManager
            .getSession(sessionId);
        assertTrue(session.active);
        assertEq(session.name, "Test Session");

        vm.stopPrank();
    }

    function testScheduleVesting() public {
        vm.startPrank(ADMIN);

        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        address factoryAddress = sessionManager.getSessionFactory(sessionId);
        VestingFactory factory = VestingFactory(factoryAddress);

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );

        VestingFactory.VestingSchedule memory schedule = factory
            .getVestingSchedule(tokenId);
        assertEq(schedule.recipient, ALICE);
        assertEq(schedule.amountPerSecond, STREAM_RATE);
        assertEq(schedule.startTime, startTime);
        assertEq(schedule.endTime, endTime);
        assertFalse(schedule.isExecuted);
        assertTrue(schedule.active);

        vm.stopPrank();
    }

    function testClaimVesting() public {
        vm.startPrank(ADMIN);

        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );

        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );
        assertEq(sessionManager.getSessionFactory(sessionId), address(factory));

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );

        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);

        vm.startPrank(ALICE);
        factory.claimVestingStream(tokenId);

        assertEq(factory.ownerOf(tokenId), ALICE);

        VestingFactory.VestingSchedule memory schedule = factory
            .getVestingSchedule(tokenId);
        assertTrue(schedule.isExecuted);
        assertTrue(schedule.active);

        address vestingContract = factory.getVestingContract(tokenId);

        int96 flowRate = getSuperToken().getFlowRate(vestingContract, ALICE);
        assertEq(flowRate, STREAM_RATE);

        vm.stopPrank();
    }

    function testCannotClaimBeforeStartTime() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );

        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.startPrank(ALICE);
        vm.expectRevert(IVestingFactory.StreamError.selector);
        factory.claimVestingStream(tokenId);
        vm.stopPrank();
    }

    function testCannotClaimTwice() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);
        vm.startPrank(ALICE);
        factory.claimVestingStream(tokenId);

        vm.expectRevert(IVestingFactory.StreamError.selector);
        factory.claimVestingStream(tokenId);
        vm.stopPrank();
    }

    function testTransferNFTUpdatesRecipient() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);
        vm.startPrank(ALICE);
        factory.claimVestingStream(tokenId);

        factory.transferFrom(ALICE, BOB, tokenId);
        vm.stopPrank();

        address vestingContract = factory.getVestingContract(tokenId);
        int96 flowRate = getSuperToken().getFlowRate(vestingContract, BOB);
        assertEq(flowRate, STREAM_RATE);

        flowRate = getSuperToken().getFlowRate(vestingContract, ALICE);
        assertEq(flowRate, 0);
    }

    function testAdminCanDirectExecute() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        vm.warp(startTime);

        factory.directExecuteVesting(tokenId);

        assertEq(factory.ownerOf(tokenId), ALICE);

        VestingFactory.VestingSchedule memory schedule = factory
            .getVestingSchedule(tokenId);
        assertTrue(schedule.isExecuted);
        vm.stopPrank();
    }

    function testEmergencyWithdraw() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);
        vm.startPrank(ALICE);
        factory.claimVestingStream(tokenId);
        vm.stopPrank();

        uint256 treasuryBalanceBefore = getSuperToken().balanceOf(TREASURY);

        vm.startPrank(ADMIN);
        address vestingContract = factory.getVestingContract(tokenId);
        Vesting(vestingContract).emergencyWithdraw();

        int96 flowRate = getSuperToken().getFlowRate(vestingContract, ALICE);
        assertEq(flowRate, 0);

        uint256 treasuryBalanceAfter = getSuperToken().balanceOf(TREASURY);
        assertTrue(treasuryBalanceAfter > treasuryBalanceBefore);

        vm.stopPrank();
    }

    function testCannotScheduleWithZeroAmount() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);

        vm.expectRevert(IVestingFactory.InvalidParameters.selector);
        factory.scheduleVestingStream(ALICE, 0, startTime, endTime);
        vm.stopPrank();
    }

    function testCannotScheduleWithInvalidTime() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = startTime - 1 days;

        vm.expectRevert(IVestingFactory.InvalidParameters.selector);
        factory.scheduleVestingStream(ALICE, STREAM_RATE, startTime, endTime);
        vm.stopPrank();
    }

    function testOnlyAdminCanSchedule() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );
        vm.stopPrank();

        vm.startPrank(ALICE);
        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);

        vm.expectRevert(IVestingFactory.Unauthorized.selector);
        factory.scheduleVestingStream(ALICE, STREAM_RATE, startTime, endTime);
        vm.stopPrank();
    }

    function testOnlyRecipientCanClaim() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);
        vm.startPrank(BOB);
        vm.expectRevert(IVestingFactory.Unauthorized.selector);
        factory.claimVestingStream(tokenId);
        vm.stopPrank();
    }

    function testCannotClaimWithoutFunding() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        vm.stopPrank();

        vm.warp(startTime);
        vm.startPrank(ALICE);
        vm.expectRevert(IVestingFactory.BalanceError.selector);
        factory.claimVestingStream(tokenId);
        vm.stopPrank();
    }

    function testOnlyAdminCanEmergencyWithdraw() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);
        vm.startPrank(ALICE);
        factory.claimVestingStream(tokenId);
        vm.stopPrank();

        vm.startPrank(BOB);
        address vestingContract = factory.getVestingContract(tokenId);
        vm.expectRevert("Only admin or factory");
        Vesting(vestingContract).emergencyWithdraw();
        vm.stopPrank();
    }

    function testMultipleSessionsAndReceivers() public {
        vm.startPrank(ADMIN);

        uint256 sessionId1 = sessionManager.createSession(
            "Session 1",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/1/"
        );
        uint256 sessionId2 = sessionManager.createSession(
            "Session 2",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/2/"
        );

        VestingFactory factory1 = VestingFactory(
            sessionManager.getSessionFactory(sessionId1)
        );
        VestingFactory factory2 = VestingFactory(
            sessionManager.getSessionFactory(sessionId2)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 aliceTokenId = factory1.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        uint256 bobTokenId = factory1.scheduleVestingStream(
            BOB,
            STREAM_RATE,
            startTime,
            endTime
        );

        uint256 carolTokenId = factory2.scheduleVestingStream(
            CAROL,
            STREAM_RATE,
            startTime,
            endTime
        );

        getSuperToken().transfer(address(factory1), totalAmount * 2);
        getSuperToken().transfer(address(factory2), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);

        vm.startPrank(ALICE);
        factory1.claimVestingStream(aliceTokenId);
        vm.stopPrank();

        vm.startPrank(BOB);
        factory1.claimVestingStream(bobTokenId);
        vm.stopPrank();

        vm.startPrank(CAROL);
        factory2.claimVestingStream(carolTokenId);
        vm.stopPrank();

        address aliceVesting = factory1.getVestingContract(aliceTokenId);
        address bobVesting = factory1.getVestingContract(bobTokenId);
        address carolVesting = factory2.getVestingContract(carolTokenId);

        assertEq(getSuperToken().getFlowRate(aliceVesting, ALICE), STREAM_RATE);
        assertEq(getSuperToken().getFlowRate(bobVesting, BOB), STREAM_RATE);
        assertEq(getSuperToken().getFlowRate(carolVesting, CAROL), STREAM_RATE);
    }

    function testChainedTransfers() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        getSuperToken().transfer(address(factory), totalAmount);
        vm.stopPrank();

        vm.warp(startTime);
        vm.startPrank(ALICE);
        factory.claimVestingStream(tokenId);

        address vestingContract = factory.getVestingContract(tokenId);
        assertEq(
            getSuperToken().getFlowRate(vestingContract, ALICE),
            STREAM_RATE
        );

        vm.warp(startTime + 1 hours);

        factory.transferFrom(ALICE, BOB, tokenId);
        vm.stopPrank();
    }

    function testDeactivateSession() public {
        vm.startPrank(ADMIN);

        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        assertTrue(sessionManager.getSession(sessionId).active);

        sessionManager.deactivateSession(sessionId);
        assertFalse(sessionManager.getSession(sessionId).active);

        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );
        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);

        uint256 tokenId = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        assertTrue(tokenId >= 0);

        vm.stopPrank();
    }

    function testMultipleEmergencyWithdraws() public {
        vm.startPrank(ADMIN);
        uint256 sessionId = sessionManager.createSession(
            "Test Session",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            sessionManager.getSessionFactory(sessionId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);
        uint256 totalAmount = uint256(uint96(STREAM_RATE)) *
            uint256(endTime - startTime);

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = factory.scheduleVestingStream(
            ALICE,
            STREAM_RATE,
            startTime,
            endTime
        );
        tokenIds[1] = factory.scheduleVestingStream(
            BOB,
            STREAM_RATE,
            startTime,
            endTime
        );
        tokenIds[2] = factory.scheduleVestingStream(
            CAROL,
            STREAM_RATE,
            startTime,
            endTime
        );

        getSuperToken().transfer(address(factory), totalAmount * 3);
        vm.stopPrank();

        vm.warp(startTime);

        vm.prank(ALICE);
        factory.claimVestingStream(tokenIds[0]);

        vm.prank(BOB);
        factory.claimVestingStream(tokenIds[1]);

        vm.prank(CAROL);
        factory.claimVestingStream(tokenIds[2]);

        vm.startPrank(ADMIN);
        uint256 treasuryBalanceBefore = getSuperToken().balanceOf(TREASURY);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            address vestingContract = factory.getVestingContract(tokenIds[i]);
            Vesting(vestingContract).emergencyWithdraw();
        }

        uint256 treasuryBalanceAfter = getSuperToken().balanceOf(TREASURY);
        assertTrue(treasuryBalanceAfter > treasuryBalanceBefore);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            address vestingContract = factory.getVestingContract(tokenIds[i]);
            address recipient = factory
                .getVestingSchedule(tokenIds[i])
                .recipient;
            assertEq(
                getSuperToken().getFlowRate(vestingContract, recipient),
                0
            );
        }

        vm.stopPrank();
    }
}
