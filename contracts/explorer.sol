/**
TODO : 
    - Make order history
    - Make position history
    - Make trading history
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

    /**
    Page struct
     */
    struct page {
        uint256 pageSize;
        uint256 pageNum;
        uint256 totalSize;
        uint256 totalPage;
    }
    /**
        Detail Position
     */
     struct detailPosition {
        position ps;
        uint256 status;
        uint256 openPrice;
        uint256 closePrice;
        order[] orders;
     }

    interface CoreContract{
        function readNonces() external view returns (uint256[3] memory);
        function readUserId(address i) external view returns (uint256);
        function readUser(uint256 i) external view returns (user memory);
        function readPosition(uint256 i) external view returns (position memory);
        function readOrder(uint256 i) external view returns (order memory);
    }

contract explorer is Ownable {
    using SafeMath for uint256;
    address private core ;
    constructor(address _core) 
    {
        core=_core;
    }

    function getCore() public returns(address) 
    {
        return core;
    }

    function setCore(address _core) public onlyOwner 
    {
        core=_core;
    }

    /**
    Explorer interface
     */
     
     
     function positionList(page memory p) public view returns(page memory , position[] memory)
     {
        uint256 sz = p.pageSize.mul(p.pageNum);
        uint256 psTotal = CoreContract(core).readNonces()[0];
        //confirm it is not out of bounds
        require(psTotal>=sz.add(p.pageSize),"out of bound"); 
        p.totalPage = psTotal.div(p.pageSize);
        p.totalSize = psTotal;
        //Read data from core contract
        position[] memory _ps = new position[](p.pageSize) ;
        for(uint i = sz; i < sz.add(p.pageSize); i++)
        {
            _ps[i.sub(sz)]=CoreContract(core).readPosition(i);
        }
        return (p,_ps);
     }

    function positionDetailsList(page memory p) public view returns(page memory , detailPosition[] memory)
     {
        uint256 sz = p.pageSize.mul(p.pageNum);
        uint256 psTotal = CoreContract(core).readNonces()[0];
        //confirm it is not out of bounds
        require(psTotal>=sz.add(p.pageSize),"out of bound"); 
        p.totalPage = psTotal.div(p.pageSize);
        p.totalSize = psTotal;
        //Read data from core contract
        
        detailPosition[] memory _ds = new detailPosition[](p.pageSize) ;
        for(uint i = sz; i < sz.add(p.pageSize); i++)
        {
            detailPosition memory ds ;
            ds.ps = CoreContract(core).readPosition(i);
            ds.status = ds.ps.status;

            order[] memory _os = new order[](ds.ps.orders.length) ;
            for ( uint ii = 0 ; ii < ds.ps.orders.length ; ii ++)
            {
                _os[ii]=CoreContract(core).readOrder(ii);
            }
            ds.orders = _os;
            ds.openPrice = ds.orders[0].confirmPrice;
            if(ds.status!=0)
            {
                ds.closePrice = ds.orders[ds.orders.length.sub(1)].confirmPrice;
            }
            _ds[i.sub(sz)]=ds;
        }
        return (p,_ds);
     }

    function orderList(page memory p) public view returns(page memory , order[] memory)
     {
        uint256 sz = p.pageSize.mul(p.pageNum);
        uint256 osTotal = CoreContract(core).readNonces()[1];
        //confirm it is not out of bounds
        require(osTotal>=sz.add(p.pageSize),"out of bound"); 
        p.totalPage = osTotal.div(p.pageSize);
        p.totalSize = osTotal;
        //Read data from core contract
        order[] memory _ps = new order[](p.pageSize) ;
        for(uint i = sz; i < sz.add(p.pageSize); i++)
        {
            _ps[i.sub(sz)]=CoreContract(core).readOrder(i);
        }
        return (p,_ps);
     }

    

    /**
        User public interface
     */
    function userList(page memory p) public view returns(page memory , user[] memory)
     {
        uint256 sz = p.pageSize.mul(p.pageNum);
        uint256 usTotal = CoreContract(core).readNonces()[2];
        //confirm it is not out of bounds
        require(usTotal>=sz.add(p.pageSize),"out of bound"); 
        p.totalPage = usTotal.div(p.pageSize);
        p.totalSize = usTotal;
        //Read data from core contract
        user[] memory _ps = new user[](p.pageSize) ;
        for(uint i = sz; i < sz.add(p.pageSize); i++)
        {
            _ps[i.sub(sz)]=CoreContract(core).readUser(i);
        }
        return (p,_ps);
     }

    function userInfo(address us) public view returns(user memory)
    {
        uint256 uid = CoreContract(core).readUserId(us);
        require(uid >0);
        return CoreContract(core).readUser(uid);
    }

    function userPositionList(page memory p,address us) public view returns(page memory , position[] memory)
    {
        user memory u = userInfo((us));
        uint256 sz = p.pageSize.mul(p.pageNum);
        uint256 psTotal = u.positionId.length;
        //confirm it is not out of bounds
        require(psTotal>=sz.add(p.pageSize),"out of bound"); 
        p.totalPage = psTotal.div(p.pageSize);
        p.totalSize = psTotal;
        //Read data from core contract
        position[] memory _ps = new position[](p.pageSize) ;
        for(uint i = sz; i < sz.add(p.pageSize); i++)
        {
            _ps[i.sub(sz)]=CoreContract(core).readPosition(u.positionId[i]);
        }
        return (p,_ps);
    }

    function userPositionDetailList(page memory p,address us) public view returns(page memory , detailPosition[] memory)
    {
        user memory u = userInfo((us));
        uint256 sz = p.pageSize.mul(p.pageNum);
        uint256 psTotal = u.positionId.length;
        //confirm it is not out of bounds
        require(psTotal>=sz.add(p.pageSize),"out of bound"); 
        p.totalPage = psTotal.div(p.pageSize);
        p.totalSize = psTotal;
        //Read data from core contract
        detailPosition[] memory _ds = new detailPosition[](p.pageSize) ;
        for(uint i = sz; i < sz.add(p.pageSize); i++)
        {
            detailPosition memory ds ;
            ds.ps = CoreContract(core).readPosition(u.positionId[i]);
            ds.status = ds.ps.status;

            order[] memory _os = new order[](ds.ps.orders.length) ;
            for ( uint ii = 0 ; ii < ds.ps.orders.length ; ii ++)
            {
                _os[ii]=CoreContract(core).readOrder(ii);
            }
            ds.orders = _os;
            ds.openPrice = ds.orders[0].confirmPrice;
            if(ds.status!=0)
            {
                ds.closePrice = ds.orders[ds.orders.length.sub(1)].confirmPrice;
            }
            _ds[i.sub(sz)]=ds;
        }
        return (p,_ds);
    }

        function userOrderList(page memory p,address us) public view returns(page memory , order[] memory)
    {
        user memory u = userInfo((us));
        uint256 sz = p.pageSize.mul(p.pageNum);
        uint256 psTotal = u.orderId.length;
        //confirm it is not out of bounds
        require(psTotal>=sz.add(p.pageSize),"out of bound"); 
        p.totalPage = psTotal.div(p.pageSize);
        p.totalSize = psTotal;
        //Read data from core contract
        order[] memory _ps = new order[](p.pageSize) ;
        for(uint i = sz; i < sz.add(p.pageSize); i++)
        {
            _ps[i.sub(sz)]=CoreContract(core).readOrder(u.orderId[i]);
        }
        return (p,_ps);
    }

}