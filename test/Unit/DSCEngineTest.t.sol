//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address weth;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = config
            .activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ////////////////////////////
    //// Constructor Tests/////
    ///////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength
                .selector
        );
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////
    //// Price Test /////
    /////////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 15000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        console.log("actualUsd: ", actualUsd);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.1 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, expectedWeth);
    }

    /////////////////////////////////
    //// depositCollateral Test /////
    /////////////////////////////////
    function testrevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock(
            "Ran",
            "RAN",
            USER,
            AMOUNT_COLLATERAL
        );
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo()
        public
        depositedCollateral
    {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce
            .getAccountInformation(USER);
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(
            weth,
            collateralValueInUsd
        );
        uint256 expectedTotalDscMinted = 0;
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testMintDsc() public depositedCollateral {
        uint256 dscAmountToMint = 1000e18;
        vm.startPrank(USER);
        dsce.mintDsc(dscAmountToMint);
        vm.stopPrank();
        uint256 expectedDscBalance = dsc.balanceOf(USER);
        assertEq(expectedDscBalance, dscAmountToMint);
    }

    function testHealthFactor() public depositedCollateral {
        uint256 dscAmountToMint = 100000e18;
        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                5e16 // <- This must match the value that the contract will revert with.
            )
        );
        dsce.mintDsc(dscAmountToMint);
        vm.stopPrank();
    }

    function testRedeemCollateralTransfersBackToUser()
        public
        depositedCollateral
    {
        uint256 dscAmountToMint = 1000e18;
        uint256 amountCollateralToRedeem = 1 ether;

        vm.startPrank(USER);

        // Mint DSC
        dsce.mintDsc(dscAmountToMint);

        // Approve DSC to burn
        dsc.approve(address(dsce), dscAmountToMint);

        // Get user's WETH balance before redemption
        uint256 userWethBalanceBefore = ERC20Mock(weth).balanceOf(USER);

        // Redeem collateral
        dsce.redeemCollateralForDsc(
            weth,
            amountCollateralToRedeem,
            dscAmountToMint
        );

        // Get user's WETH balance after redemption
        uint256 userWethBalanceAfter = ERC20Mock(weth).balanceOf(USER);

        // Assert that the user received the redeemed amount
        assertEq(
            userWethBalanceAfter - userWethBalanceBefore,
            amountCollateralToRedeem
        );

        vm.stopPrank();
    }
}
