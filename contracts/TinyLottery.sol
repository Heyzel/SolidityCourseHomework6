// SPDX-License-Identifier: MIT
pragma solidity >=0.8.3;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TinyLottery is OwnableUpgradeable {
    using SafeMath for uint256;

    struct User {
        address addr;
        uint256 funds;
    }

    struct Lottery {
        address token;
        uint256 price;
        uint256 funds;
        uint256 initDate;
        uint256 interestEarned;
    }

    // ========== VARIABLES V1 ========== //

    /**
    * Network: Mainnet
    * Token: DAI
    * Address: 0x6B175474E89094C44Da98b954EedeAC495271d0F
    */
    IERC20 public DAI;

    /**
    * Network: Mainnet
    * Token: USDC
    * Address: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    */
    IERC20 public USDC;

    /**
    * Network: Mainnet
    * Token: USDT
    * Address: 0xdAC17F958D2ee523a2206206994597C13D831ec7
    */
    IERC20 public USDT;

    // Receives `fee` of the total ETH used for swaps   
    address public feeRecipient;

    // fee charged, initialized in 0.1%
    uint16 public fee;

    uint64 public currentLottery;

    Lottery[] lotteries;
    mapping(uint64 => User[]) users;

    function initialize(
        address _feeRecipient, 
        uint16 _fee, 
        address DAIAddress, 
        address USDCAddress, 
        address USDTAddress
        ) external initializer {
        __Ownable_init();

        require(_feeRecipient != address(0));
        require(_fee > 0);
        feeRecipient = _feeRecipient;
        fee = _fee;
        DAI = IERC20(DAIAddress);
        USDC = IERC20(USDCAddress);
        USDT = IERC20(USDTAddress);
    }

    function createLottery(address token, uint256 price, User[] memory _laggardUsers) external {
        Lottery memory newLottery;
        newLottery.token = token;
        newLottery.price = price;
        newLottery.initDate = block.timestamp;
        lotteries.push(newLottery);
        for (uint64 i = 0; i < _laggardUsers.length; i++){
            User memory newUser;
            newUser.addr = _laggardUsers[i].addr;
            newUser.funds = _laggardUsers[i].funds;
            users[currentLottery].push(newUser);
        }
    }

    function buyTickets(string memory _crypto) public {
        uint256 funds;
        User memory newUser;
        if(isPurchasePeriod()){
            if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("DAI"))){
                funds = DAI.allowance(msg.sender, address(this));
                newUser.addr = msg.sender;
                newUser.funds = funds;
                users[currentLottery].push(newUser);
                
            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDC"))){
                // swap()

                
            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDT"))){
                // swap()


            }else{
                revert("That Token is not accepted in this lottery");
            }
        }else{
             if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("DAI"))){
                funds = DAI.allowance(msg.sender, address(this));
                newUser.addr = msg.sender;
                newUser.funds = funds;
                users[currentLottery+1].push(newUser);

            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDC"))){
                // swap()


            }else if(keccak256(abi.encodePacked(_crypto)) == keccak256(abi.encodePacked("USDT"))){
                // swap()

                
            }else{
                revert("That Token is not accepted in this lottery");
            }
        }
    }

    function isPurchasePeriod() internal view returns(bool) {
        if(lotteries[currentLottery].initDate + 172800 > block.timestamp){
            return true;
        }else{
            return false;
        }
    }
}