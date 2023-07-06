/**
TODO : 
    - Make register verfication function 
    - Make price culcuate system
    - Make explorer readable interface
    - Make 

 */


/**
 * Core Contract (full position version)
 * 
 * This contract is use for doing basice trading action and trading lifecircle.
 * And part of user system
 * 
 * Interface:
 *  - 
 */

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

    interface ERC20Token{
        function balanceOf(address account) external view returns (uint256);
        function approve(address spender, uint256 amount) external returns (bool);
        function transfer(address to, uint256 amount) external returns (bool);
    }
    interface Vault{
        function deposit(address player,uint farm,uint256 amount) external returns (bool);
        function withdraws(uint256 amount) external returns (uint256);
    }

contract fstarCore is Ownable {
    using SafeMath for uint256;
    /** Order Struct */
    struct order {
        address sender;
        uint256 positionId;
        uint256 orderId;
        uint    status; //0 for pending confirm . 1 for confirm
        bool    side;// true for Buy | false for Sell
        address symble;
        uint256 qty;
        uint256 createTime;
        uint256 confirmPrice;
        uint256 confirmTime;
    }
    /** Position Struct */
    struct position {
        address sender;
        uint256 positionId;
        uint    status;//0 for open , 1 for closed
        uint256 uid;
        uint256 nonce;
        address symble;
        bool    side;// true for Buy | false for Sell
        uint256 qty;
        uint256 originQty; // the origin amount;
        uint256 amount;// the amount that permit to use
        uint256 originAmount;
        uint256[] orders;
        uint256 liquidationPrice;
    }

    /** User Struck */
    struct user {
        address sender;
        uint256[] orderId;
        uint256[] positionId;
    }

    /** Core Data Array */
    order[] private _os;
    position[] private _ps;
    user[] private _us;

    /** Id Index */
    mapping(string => uint256) private orderIndex;
    mapping(string => uint256) private positionIndex;
    mapping(address => uint256) private userIndex;

    /** Incressing Nonce */
    using Counters for Counters.Counter;
    Counters.Counter private userCount;

    
    using SafeERC20 for IERC20;
    address private keyToken ; 
    address private vault;
    /** Init constuctor */
    constructor(address key ,address val) {
        Owner.push(msg.sender);
        isOwner[msg.sender] = true;
        userSign();
        keyToken = key;
        vault = val;
    }

    /** Owner Part */
    address[] private Owner;
    mapping(address=>bool) private isOwner;

/**
 * Write funtions
 */
 
/**
 * Public trading function
 */

        /**
         * A new position must have a new order incomming .
         * Position life cricle : 
         *  - New position (Open a new position with Frax_base margin ) (including new order)
         *  - New orders (order x n)
         *  - Last order (order to close this position)
         */
    function makePosition(position memory positionData) public returns (order memory , position memory)
    {
        if(userIndex[msg.sender]>0)
        {
            openPosition(positionData);
            
        }else{
            userSign();
            return makePosition(positionData);
        }
    }

        /**
         * A new order is to open a new order in market price only as a maker 
         * Order life circle :
         * - New order (User open a order on chain)
         * - Confirm order (Monitor confirm the order offchain with cefi's data)
         * 
         * Additional information :
         * 1. A order have same amount but different direction to a position will force close the position
         */
    function makeOrder(order memory no) public returns (order memory , position memory)
    {
        //Confirm the position exists and belong to the user
        require(_ps[no.positionId].sender == msg.sender , "wrong sender");
        //Confirm the direction different to position
        require(_ps[no.positionId].side != no.side , "wrong side");
        //Confirm the amount of order acceptable 
        require(_ps[no.positionId].qty>=no.qty);

        newOrder(no);
    }

/**
 * Prive trading function
 */

    /**
     *  address sender;
        uint256 positionId;
        uint256 orderId;
        uint    status; //0 for pending confirm . 1 for confirm
        bool    side;// true for Buy | false for Sell
        address symble;
        uint256 qty;
        uint256 createTime;
        uint256 confirmPrice;
        uint256 confirmTime;
     */
    function newOrder(order memory no) private returns (order memory) {
        no.status = 0;
        no.orderId = _os.length ;//userIndex[msg.sender]+(readNonces)[0]+block.timestamp;
        _os.push(no);

        _us[userIndex[msg.sender]].orderId.push(no.orderId);

        return no;

    }
    
    function newPositionOrder(position memory ps) private returns (order memory)
    {
        //make new order ;
        order memory no ;
        no.sender = msg.sender;
        no.side = ps.side;
        no.qty = ps.qty;
        no.symble = ps.symble;
        no.createTime=block.timestamp;
        no.positionId=ps.positionId;
        return newOrder(no);
    }



    /**
     *  address sender;
        uint256 positionId;
        uint    status;//0 for open , 1 for closed
        uint256 uid;
        uint256 nonce;
        address symble;
        bool    side;// true for Buy | false for Sell
        uint256 qty;
        uint256 originQty; // the origin amount;
        uint256 amount;// the amount that permit to use
        uint256 originAmount;
        uint[] orders;
        uint256 liquidationPrice;
     */
    function openPosition(position memory ps) private returns (position memory) {
        //Transfer token into vault
        // IERC20(keyToken).transferFrom(msg.sender,address(this), ps.amount);
        Vault(vault).deposit(msg.sender,0, ps.amount);
        //make new position
        ps.sender = msg.sender;
        ps.positionId = _ps.length;
        ps.nonce = userIndex[msg.sender].add(_ps.length).add(block.timestamp);
        ps.liquidationPrice = 0 ;
        ps.originQty = ps.qty;
        ps.originAmount = ps.amount;
        ps.uid = userIndex[msg.sender];
        //confirm and add it with user sign
        _ps.push(ps);
        _us[userIndex[msg.sender]].positionId.push(ps.positionId);

        //new order for the position
        _ps[ps.positionId].orders.push((newPositionOrder(ps)).orderId);
        return _ps[ps.positionId];
    }

    function closePosition(uint256 i)private returns (position memory) {
        require(_ps[i].qty==0);
        _ps[i].status = 1;
    }


/**
    User system 
 */
    function userSign() public returns(uint256)
    {
        //make record for user sign
        require(userIndex[msg.sender]==0,"user already sign");
        user memory us ;
        us.sender = msg.sender;
        _us.push(us);
            //confirm it have no sign before
            userIndex[msg.sender]=userCount.current();
            userCount.increment();
        return userIndex[msg.sender];
    }

/**
 * Monitor system
 */
    function updatePosition(position memory ps) public onlyOwner returns (bool)
    {   
        //to culcuate liquidationPrice
    }

    function updateLiquidation(uint256 id) private returns (bool)
    {
        if(_ps[id].side)
        {
            _ps[id].liquidationPrice = _os[_ps[id].orders[0]].confirmPrice.sub(_ps[id].amount.div(_ps[id].qty));
        }else
        {
            _ps[id].liquidationPrice = _os[_ps[id].orders[0]].confirmPrice.add(_ps[id].amount.div(_ps[id].qty));
        }

    }

    function updatePositionAmount(uint256 id,uint256 orderId) private
    {
        uint256 amountChange = 0;
        uint256 amountBase = ((_os[orderId].qty).div(_ps[id].qty)).mul(_ps[id].amount);
        uint256 _final = 0;
        if(_ps[id].side)
        {

            // ## Warning ## You need to confirm your monitor make every confirm by order index
            if(_os[orderId].confirmPrice > _os[_ps[id].orders[0]].confirmPrice)
            {
                //cutting wininng , transfer amount from vault to user
                amountChange = ((_os[orderId].confirmPrice).sub(_os[_ps[id].orders[0]].confirmPrice)).mul(_ps[id].qty);
                _final = amountBase.add(amountChange);
            }else
            {
                //cutting losing , reduce the amount of position
                amountChange = ((_os[_ps[id].orders[0]].confirmPrice).sub(_os[orderId].confirmPrice)).mul(_ps[id].qty);
                _final = amountBase.sub(amountChange);
            }
        }else
        {
        if(_os[_ps[id].orders[_ps[id].orders.length.sub(1)]].confirmPrice > _os[_ps[id].orders[0]].confirmPrice)
            {
                //cutting losing , reduce the amount of position
                amountChange = ((_os[orderId].confirmPrice).sub(_os[_ps[id].orders[0]].confirmPrice)).mul(_ps[id].qty);
                _final = amountBase.sub(amountChange);
            }else
            {
                //cutting wininng , transfer amount from vault to user
                amountChange = ((_os[_ps[id].orders[0]].confirmPrice).sub(_os[orderId].confirmPrice)).mul(_ps[id].qty);
                _final = amountBase.add(amountChange);
            }
        }
        _ps[id].amount=_ps[id].amount.sub(amountBase);
        if(_final > 0)
        {
             Vault(vault).withdraws(_final);
             IERC20(keyToken).transfer(_ps[id].sender, _final);
        }
    }

    function updateOrder(uint[] memory n,uint256 price) public onlyOwner returns (bool){
        for(uint i = 0 ; i < n.length ; i++)
        {
            order memory no=_os[n[i]];
            require(_os[n[i]].status==0,"already confirm ");
            //confirm the order's price and time
            _os[n[i]].confirmPrice =price;
            _os[n[i]].confirmTime = block.timestamp;
            _os[n[i]].status = 1; // confirm the status change
            //TODO verfi oracle information match

            //If it is not the init order , make the qty sub
            if(_ps[no.positionId].side != no.side)
            {
                //Update the position amount 
                updatePositionAmount(no.positionId,no.orderId);
                _ps[no.positionId].qty=_ps[no.positionId].qty.sub(no.qty);
            }
            //Transfer wining price to it , or sub the lock amount;

            //Check if the position terminated
            if(_ps[no.positionId].qty==0)
            {
                closePosition(no.positionId);
            }else
            {
                //If not , update the liquidation price of position
                updateLiquidation(no.positionId);
            }

        }
        return true;
    }

    function updateSetting() public onlyOwner returns (bool){

    }
/**
    Data output interface :
 */

/**
* Read only funtions
*/ 
    function readNonces() public view returns (uint256[3] memory)
    {
        return [_os.length,_ps.length,userCount.current()];
    }

    function readOrder(uint256 i) public view returns (order memory)
    {
        return _os[i];
    }

    function readPosition(uint256 i) public view returns (position memory)
    {
        return _ps[i];
    }

    function readUser(uint256 i) public view returns (user memory)
    {
        return _us[i];
    }

    function readUserId(address i) public view returns (uint256)
    {
        return userIndex[i];
    }
}