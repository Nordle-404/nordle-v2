// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {ERC721, ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here:
 * https://docs.chain.link/docs/link-token-contracts/
 */

interface LinkTokenMini {
    function balanceOf(address owner) external view returns (uint256 balance);

    function transfer(address to, uint256 value)
        external
        returns (bool success);
}

contract Nordle is
    ERC721URIStorage,
    ChainlinkClient,
    ConfirmedOwner,
    VRFConsumerBaseV2
{
    using Chainlink for Chainlink.Request;

    /// @dev Chainlink VRF Coordinator
    VRFCoordinatorV2Interface private VRF_COORDINATOR;

    /// @dev Chainlink VRF Subscription ID
    uint64 private immutable vrfSubscriptionId;

    /// @dev Chainlink VRF Max Gas Price Key Hash
    bytes32 private immutable vrfKeyHash;

    /// @dev Chainlink Any API Job ID
    bytes32 private jobIdAnyApi;

    /// @dev Chainlink Any API Fee
    uint256 private feeAnyApi;

    /// @dev NFT Token ID counter
    uint256 public tokenIdCount;

    /// @dev Words (phrase) associated with each token
    mapping(uint256 => string) public tokenWords;

    /// @dev Words (phrase) for requests
    mapping(uint256 => string) public requestWords;

    /// @dev TokenIds to be burned
    mapping(uint256 => uint256[]) public tokensToBurn;

    /// @dev Addresses of word creation requesters
    mapping(uint256 => address) public wordRequesters;

    /// @dev All possible words
    string[] public nordleWords = ["unicorn", "outlier", "ethereum", "pepe"];

    uint256 public wordForcedPrice = 5e16; // 0.05 (18 decimals)

    /**
     * @notice Initialize the link token and target oracle
     * @dev The oracle address must be an Operator contract for multiword response
     *
     * Goerli Testnet details:
     * Link Token: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Oracle: 0xCC79157eb46F5624204f47AB42b3906cAA40eaB7 (Chainlink DevRel)
     * VRF: 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D
     * sKeyHash: 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15
     * jobId: 7da2702f37fd48e5b1b9a5715e3509b6 // https://docs.chain.link/docs/any-api/testnet-oracles/#job-ids
     *
     */
    constructor(
        address _linkToken,
        address _linkOracle,
        address _linkVRFCoordinator,
        bytes32 _sKeyHash,
        // bytes32 _jobIdAnyApi,
        uint64 _vrfSubscriptionId
    )
        ERC721("Nordle", "NRD")
        ConfirmedOwner(msg.sender)
        VRFConsumerBaseV2(_linkVRFCoordinator)
    {
        setChainlinkToken(_linkToken);
        setChainlinkOracle(_linkOracle);
        // jobIdAnyApi = _jobIdAnyApi;
        // https://docs.chain.link/docs/any-api/testnet-oracles/#job-ids
        jobIdAnyApi = "7da2702f37fd48e5b1b9a5715e3509b6"; // Job ID for GET>bytes
        feeAnyApi = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)

        // Intialize the VRF Coordinator
        VRF_COORDINATOR = VRFCoordinatorV2Interface(_linkVRFCoordinator);
        vrfSubscriptionId = _vrfSubscriptionId;
        vrfKeyHash = _sKeyHash;
    }

    /// @dev Initiate request to create new word NFT, and you can "buy" a word (initiate it)
    function requestCreateWord(string memory _word) public payable {
        require(msg.value == wordForcedPrice, "Invalid payment");
        uint256[] memory noTokensToCombine;
        _createWord(_word, msg.sender, noTokensToCombine);
    }

    /// @dev Initiate request to create new word NFT
    function requestCreateWord() public {
        uint256 vrfRequestId = VRF_COORDINATOR.requestRandomWords(
            vrfKeyHash,
            vrfSubscriptionId,
            3, // Number of confirmations
            500_000, // Callback gas limit
            1 // Number of generated words
        );
        wordRequesters[vrfRequestId] = msg.sender;
    }

    /// @dev Callback function for VRF, using the random number to get the initial word
    function fulfillRandomWords(
        uint256 _vrfRequestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 randomIndex = _randomWords[0] % nordleWords.length;
        string memory word = nordleWords[randomIndex];

        uint256[] memory noTokensToCombine;

        _createWord(word, wordRequesters[_vrfRequestId], noTokensToCombine);
        delete wordRequesters[_vrfRequestId];
    }

    function requestCombine(uint256[] memory _tokensToCombine)
        public
        returns (string memory newWord)
    {
        newWord = "";

        for (uint256 i = 0; i < _tokensToCombine.length; i++) {
            uint256 tokenId = _tokensToCombine[i];
            // Check to see if the user owns the token
            require(ownerOf(tokenId) == msg.sender, "Invalid owner of token");
            // Check to see if the token exists (i.e. not burned)
            require(_exists(tokenId) == true, "Token does not exist");
            newWord = string.concat(newWord, tokenWords[tokenId], "%20");
        }

        _createWord(newWord, msg.sender, _tokensToCombine);
    }

    /// @dev Submits an Any API request to generate image URL
    /// and subsequently call fulfillCreateWord()
    function _createWord(
        string memory _word,
        address _owner,
        uint256[] memory _tokensToCombine
    ) internal returns (uint256 apiRequestId) {
        apiRequestId = _submitChainlinkApiRequest(
            _word,
            this.fulfillCreateWord.selector
        );
        requestWords[apiRequestId] = _word;
        wordRequesters[apiRequestId] = _owner;

        // If combining tokens, make note of the Ids to burn later
        if (_tokensToCombine.length > 0) {
            tokensToBurn[apiRequestId] = _tokensToCombine;
        }
    }

    /// @dev Called by Chainlink after image URL is generated via the API call
    function fulfillCreateWord(bytes32 _apiRequestId, bytes memory _bytesData)
        public
        recordChainlinkFulfillment(_apiRequestId)
    {
        uint256 apiRequestId = uint256(_apiRequestId);
        string memory imageUrl = string(_bytesData);
        _mintWord(apiRequestId, imageUrl);
    }

    function _submitChainlinkApiRequest(
        string memory phrase,
        bytes4 callbackSelector
    ) internal returns (uint256 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobIdAnyApi,
            address(this),
            callbackSelector
        );
        string memory drawUrl = string.concat(
            "https://bdd9-4-71-27-132.ngrok.io/draw?phrase=",
            phrase
        );
        req.add("get", drawUrl);
        req.add("path", "payload,data"); // response looks like: { payload: { data: '' } }
        requestId = uint256(sendChainlinkRequest(req, feeAnyApi));
    }

    function _mintWord(uint256 _apiRequestId, string memory _imageUrl)
        internal
    {
        _mint(wordRequesters[_apiRequestId], tokenIdCount);
        _setTokenURI(tokenIdCount, _imageUrl);
        tokenWords[tokenIdCount] = requestWords[_apiRequestId];
        tokenIdCount++;

        delete wordRequesters[_apiRequestId];
        delete requestWords[_apiRequestId];

        if (tokensToBurn[_apiRequestId].length > 0) {
            for (uint256 i = 0; i < tokensToBurn[_apiRequestId].length; i++) {
                uint256 tokenId = tokensToBurn[_apiRequestId][i];
                _burn(tokenId);
            }
            delete tokensToBurn[_apiRequestId];
        }
    }

    function withdraw() public onlyOwner {
        LinkTokenMini link = LinkTokenMini(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
        (bool sent, ) = address(msg.sender).call{value: address(this).balance}(
            ""
        );
        require(sent, "Unable to transfer");
    }
}
