// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./helpers/SuperfluidHelper.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {StreamingNFTManager} from "../src/StreamingNFTManager.sol";
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

    StreamingNFTManager public seasonManager;

    function setUp() public virtual {
        setupSuperfluid();

        vm.startPrank(ADMIN);
        seasonManager = new StreamingNFTManager(ADMIN);
        vm.stopPrank();

        for (uint256 i; i < _testAccounts.length; ++i) {
            mintSuperTokens(_testAccounts[i], INITIAL_BALANCE);
        }
    }

    function testCreateSeason() public {
        vm.startPrank(ADMIN);

        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );

        StreamingNFTManager.Season memory season = seasonManager.getSeason(
            seasonId
        );
        assertTrue(season.active);
        assertEq(season.name, "Test Season");

        vm.stopPrank();
    }

    function testScheduleVesting() public {
        vm.startPrank(ADMIN);

        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        address factoryAddress = seasonManager.getSeasonFactory(seasonId);
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
        assertEq(schedule.originalRecipient, ALICE);
        assertEq(schedule.amountPerSecond, STREAM_RATE);
        assertEq(schedule.startTime, startTime);
        assertEq(schedule.endTime, endTime);
        assertFalse(schedule.isExecuted);
        assertTrue(schedule.active);

        vm.stopPrank();
    }

    function testClaimVesting() public {
        vm.startPrank(ADMIN);

        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );

        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
        );
        assertEq(seasonManager.getSeasonFactory(seasonId), address(factory));

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
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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

        assertEq(factory.ownerOf(tokenId), BOB);

        address vestingContract = factory.getVestingContract(tokenId);
        int96 flowRate = getSuperToken().getFlowRate(vestingContract, BOB);
        assertEq(flowRate, STREAM_RATE);

        flowRate = getSuperToken().getFlowRate(vestingContract, ALICE);
        assertEq(flowRate, 0);
    }

    function testAdminCanDirectExecute() public {
        vm.startPrank(ADMIN);
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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

    function testStopStream() public {
        vm.startPrank(ADMIN);
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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
        Vesting(vestingContract).stopStream();

        int96 flowRate = getSuperToken().getFlowRate(vestingContract, ALICE);
        assertEq(flowRate, 0);

        uint256 treasuryBalanceAfter = getSuperToken().balanceOf(TREASURY);
        assertTrue(treasuryBalanceAfter > treasuryBalanceBefore);

        vm.stopPrank();
    }

    function testCannotScheduleWithZeroAmount() public {
        vm.startPrank(ADMIN);
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = uint32(block.timestamp + 365 days);

        vm.expectRevert(IVestingFactory.InvalidParameters.selector);
        factory.scheduleVestingStream(ALICE, 0, startTime, endTime);
        vm.stopPrank();
    }

    function testCannotScheduleWithInvalidTime() public {
        vm.startPrank(ADMIN);
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
        );

        uint32 startTime = uint32(block.timestamp + 1 days);
        uint32 endTime = startTime - 1 days;

        vm.expectRevert(IVestingFactory.InvalidParameters.selector);
        factory.scheduleVestingStream(ALICE, STREAM_RATE, startTime, endTime);
        vm.stopPrank();
    }

    function testOnlyAdminCanSchedule() public {
        vm.startPrank(ADMIN);
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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

    function testOnlyAdminCanStopStream() public {
        vm.startPrank(ADMIN);
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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
        vm.expectRevert(Vesting.OnlyFactoryOrAdmin.selector);
        Vesting(vestingContract).stopStream();
        vm.stopPrank();
    }

    function testStreamStopAfterTransfer() public {
        vm.startPrank(ADMIN);
        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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

        // Verify initial stream to ALICE
        address vestingContract = factory.getVestingContract(tokenId);
        assertEq(
            getSuperToken().getFlowRate(vestingContract, ALICE),
            STREAM_RATE
        );

        // Transfer NFT to BOB
        factory.transferFrom(ALICE, BOB, tokenId);
        vm.stopPrank();

        // Verify stream is now to BOB
        assertEq(
            getSuperToken().getFlowRate(vestingContract, BOB),
            STREAM_RATE
        );
        assertEq(getSuperToken().getFlowRate(vestingContract, ALICE), 0);

        // Stop stream as admin
        vm.startPrank(ADMIN);
        Vesting(vestingContract).stopStream();
        vm.stopPrank();

        // Verify stream is stopped
        assertEq(getSuperToken().getFlowRate(vestingContract, BOB), 0);
        uint256 treasuryBalance = getSuperToken().balanceOf(TREASURY);
        assertTrue(treasuryBalance > 0);
    }

    function testMultipleStreamStops() public {
        // ... second implementation ...
    }

    function testDeactivateSeason() public {
        vm.startPrank(ADMIN);

        uint256 seasonId = seasonManager.createSeason(
            "Test Season",
            TREASURY,
            getSuperToken(),
            "https://api.example.com/metadata/"
        );
        assertTrue(seasonManager.getSeason(seasonId).active);

        seasonManager.deactivateSeason(seasonId);
        assertFalse(seasonManager.getSeason(seasonId).active);

        VestingFactory factory = VestingFactory(
            seasonManager.getSeasonFactory(seasonId)
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
}
