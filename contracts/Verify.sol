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
        string proof;
    }

    // We assume that for a given seller - buyer pair , there is only a single purchase at any given time
    // Maps seller ( server addresses ) to buyer ( client addresses ) which in turn are mapped to tx details
    mapping(address => mapping(address => agreedPurchase)) public orderBook; // Privacy is out of scope for now
    mapping(address => uint256) balances; // stores the Eth balances of sellers

    mapping(uint => DataInfo) public allData; // Store data
    uint public dataCount; // Store data Count

    constructor() public {
        addData(
            0x284271e5A5bCA5a0f9026f5B28145c83d9E6410F,
            "Stevens Graduate Student DB",
            20 * 1e18,
            "https://drive.google.com/file/d/1n2JanYg9-d7N1GZhN-lbb5Cl4d8gMKJr/view?usp=drive_link",
            "this is proof"
        );
        addData(
            0xC83DBdC717581c5B36585beCaA463f4d644d7AFA,
            "Stevens Undergraduate Student DB",
            30 * 1e18,
            "https://drive.google.com/file/d/1n2JanYg9-d7N1GZhN-lbb5Cl4d8gMKJr/view?usp=drive_link",
            "this is proof"
        );
        addData(
            0x284271e5A5bCA5a0f9026f5B28145c83d9E6410F,
            "Stevens Faculty DB",
            40 * 1e18,
            "https://drive.google.com/file/d/1n2JanYg9-d7N1GZhN-lbb5Cl4d8gMKJr/view?usp=drive_link",
            "this is proof"
        );
        addData(
            0xC83DBdC717581c5B36585beCaA463f4d644d7AFA,
            "Stevens Indian Student DB",
            50 * 1e18,
            "https://drive.google.com/file/d/1n2JanYg9-d7N1GZhN-lbb5Cl4d8gMKJr/view?usp=drive_link",
            "this is proof"
        );
        addData(
            0x284271e5A5bCA5a0f9026f5B28145c83d9E6410F,
            "Stevens Staff DB",
            60 * 1e18,
            "https://drive.google.com/file/d/1n2JanYg9-d7N1GZhN-lbb5Cl4d8gMKJr/view?usp=drive_link",
            "this is proof"
        );
    }

    function addData(
        address seller,
        string memory name,
        uint256 price,
        string memory url,
        string memory proof
    ) private {
        dataCount++;
        allData[dataCount] = DataInfo(
            dataCount,
            seller,
            name,
            price,
            url,
            proof
        );
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
        emit BroadcastSecKey(_seller, _buyer, "abc123");
    }

    // This function allocates funds to the server from previous accrued purchase incomes
    function withdrawPayment(address _seller) public payable {
        address payable addr1 = payable(_seller);
        addr1.transfer(balances[_seller]);
        balances[_seller] = 0;
    }
}
