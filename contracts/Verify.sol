pragma solidity ^0.6.0;

contract Verify {
    struct agreedPurchase {
        uint256 agreedPrice;
        bool secretKeySent;
        bool ongoingPurchase;
    }

    struct DataInfo {
        uint id;
        address seller;
        string name;
        uint256 price;
        string url;
        string pic;
    }

    // We assume that for a given seller - buyer pair , there is only a single purchase at any given time
    // Maps seller ( server addresses ) to buyer ( client addresses ) which in turn are mapped to tx details
    mapping(address => mapping(address => agreedPurchase)) public orderBook; // Privacy is out of scope for now
    mapping(address => uint256) balances; // stores the Eth balances of sellers

    mapping(uint => DataInfo) public allData; // Store data
    uint public dataCount; // Store data Count

    string private passpharse = "abc123";

    constructor() public {
        addData(
            0x284271e5A5bCA5a0f9026f5B28145c83d9E6410F,
            "AAPL Stock Data",
            20 * 1e18,
            "https://www.dropbox.com/scl/fo/m12nh4txcdfpeu25es7hh/AA5-GoJEPftZN5q1ZgbDFOk?rlkey=n149i6h1k4kzg85k2992enugh&dl=0",
            "https://pngimg.com/uploads/apple_logo/apple_logo_PNG19688.png"
        );
        addData(
            0xC83DBdC717581c5B36585beCaA463f4d644d7AFA,
            "ABNB Stock Data",
            30 * 1e18,
            "https://www.dropbox.com/scl/fo/919tx35edpjmj7bypd0sx/AIyGUHb9q4fnCWglo0wNwzw?rlkey=rzkseghz317b3oywxnn3dbyp9&dl=0",
            "https://cdn.dribbble.com/users/5068307/screenshots/10877145/media/539577a493c56679cac2f9fdf69172cb.gif"
        );
        addData(
            0x284271e5A5bCA5a0f9026f5B28145c83d9E6410F,
            "MSFT Stock Data",
            40 * 1e18,
            "https://www.dropbox.com/scl/fo/w5sbpk9zdtlvw609t6nv9/AH9-ec6DJf-Lppd3_VgTF_w?rlkey=kbdtee4p0vfinne2goi7shcaa&dl=0",
            "https://banner2.cleanpng.com/20180320/dwq/kisspng-microsoft-windows-logo-scalable-vector-graphics-microsoft-new-logo-simple-5ab0cf05df0f18.2010910315215367739137.jpg"
        );
        addData(
            0xC83DBdC717581c5B36585beCaA463f4d644d7AFA,
            "TSLA Stock Data",
            50 * 1e18,
            "https://www.dropbox.com/scl/fo/tm0u7v0l3gwjkdhehc01v/APz-NBANzMexvzXAeQ-38XY?rlkey=budktpugmyvm2srcaacpv6rpr&dl=0",
            "https://i.pinimg.com/564x/ed/64/13/ed641311d15fe898726224072c2da65e.jpg"
        );
        addData(
            0x284271e5A5bCA5a0f9026f5B28145c83d9E6410F,
            "UBER Stock Data",
            60 * 1e18,
            "https://www.dropbox.com/scl/fo/c3ar4v4nggpcn0c7a4f96/ADWD75OlMrdRm_ES_F04llM?rlkey=sf37kaj6cpa4f4qhahk3ss44l&dl=0",
            "https://1000logos.net/wp-content/uploads/2021/04/Uber-logo.png"
        );
    }

    function addData(
        address seller,
        string memory name,
        uint256 price,
        string memory url,
        string memory pic
    ) private {
        dataCount++;
        allData[dataCount] = DataInfo(dataCount, seller, name, price, url, pic);
    }

    // Events
    event BroadcastOrder(
        address indexed _seller,
        address indexed _buyer,
        uint256 _agreedPrice
    );
    event BroadcastSecKey(
        address indexed _seller,
        address indexed _buyer,
        string _secKey
    );

    // Agreed price could be set by the contract akin to Uniswap whereby price would be dynamically changing
    // according to a constant product formula given the current number of sellers and buyers ( assuming that each tx in the orderBook has the same volume )
    function createPurchaseOrder(uint256 _agreedPrice, address _seller) public {
        require(
            !orderBook[_seller][msg.sender].ongoingPurchase,
            "There can only be one purchase per buyer - seller pair!"
        );
        orderBook[_seller][msg.sender].agreedPrice = _agreedPrice;
        orderBook[_seller][msg.sender].ongoingPurchase = true;
        orderBook[_seller][msg.sender].secretKeySent = false;

        emit BroadcastOrder(_seller, msg.sender, _agreedPrice);
    }

    // If buyer agrees to the details of the purchase ,then it locks the corresponding amount of money .
    function buyerLockPayment(address _seller) public payable {
        require(
            !orderBook[_seller][msg.sender].secretKeySent,
            "Secret keys have been already revealed!"
        );
        require(
            msg.value == orderBook[_seller][msg.sender].agreedPrice,
            "The transferred money does not match the agreed price!"
        );

        sellerSendsSecKey(_seller, msg.sender);
    }

    function sellerSendsSecKey(address _seller, address _buyer) public {
        require(
            !orderBook[_seller][_buyer].secretKeySent,
            "Secret key has been already revealed."
        );

        orderBook[_seller][_buyer].secretKeySent = true;
        balances[_seller] += orderBook[_seller][_buyer].agreedPrice;
        orderBook[_seller][_buyer].ongoingPurchase = false;

        withdrawPayment(_seller);

        // There is no need to store the secret key in storage
        emit BroadcastSecKey(_seller, _buyer, passpharse);
    }

    // This function allocates funds to the server from previous accrued purchase incomes
    function withdrawPayment(address _seller) public payable {
        address payable addr1 = payable(_seller);
        addr1.transfer(balances[_seller]);
        balances[_seller] = 0;
    }
}
