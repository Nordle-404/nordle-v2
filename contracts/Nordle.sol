// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Chainlink, ChainlinkClient, LinkTokenInterface} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {ERC721, ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import {NordleWordBank} from "./NordleWordBank.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here:
 * https://docs.chain.link/docs/link-token-contracts/
 */

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
    uint64 private vrfSubscriptionId;

    /// @dev Chainlink VRF Max Gas Price Key Hash
    bytes32 private vrfKeyHash;

    /// @dev Chainlink Any API Job ID
    bytes32 private jobIdAnyApi;

    /// @dev Chainlink Any API Fee
    uint256 private feeAnyApi;

    /// @dev NFT Token ID counter
    uint256 private tokenIdCount;

    /// @dev User-owned token Ids
    mapping(address => uint256[]) private userTokenIds;

    /// @dev Mapping to keep track of index of user-owned token Ids within the array
    mapping(address => mapping(uint256 => uint256)) private userTokenIdIndex;

    /// @dev User-burned token Ids
    mapping(address => uint256[]) private userBurnedTokenIds;

    /// @dev Words (phrase) associated with each token
    mapping(uint256 => string) public tokenWords;

    /// @dev Words (phrase) for requests
    mapping(uint256 => string) private requestWords;

    /// @dev TokenIds to be burned
    mapping(uint256 => uint256[]) private tokensToBurn;

    /// @dev Addresses of word creation requesters
    mapping(uint256 => address) private wordRequesters;

    uint256 public wordForcedPrice = 5e16; // 0.05 (18 decimals)

    NordleWordBank public nordleWordBank;

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
        uint64 _vrfSubscriptionId,
        address _nordleWordBank
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
        nordleWordBank = NordleWordBank(payable(_nordleWordBank)); // wordbank is payable
    }

    /// @dev Initiate request to create new word NFT, and you can "buy" a word (initiate it)
    function requestCreateWord(string memory _word) public payable {
        require(msg.value == wordForcedPrice, "Invalid payment");
        require(nordleWordBank.exists(_word), "Word must exist in the word bank");
        _createWord(_word, msg.sender, new uint256[](0));
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
        string[] memory words = nordleWordBank.wordBank();
        uint256 randomIndex = _randomWords[0] % words.length;
        _createWord(words[randomIndex], wordRequesters[_vrfRequestId], new uint256[](0)); // last arg: no tokens to combine
        delete wordRequesters[_vrfRequestId];
    }

    function requestCombine(uint256[] memory _tokensToCombine)
        public
        returns (string memory newWord)
    {
        require(ownerOf(_tokensToCombine[0]) == msg.sender);
        newWord = tokenWords[_tokensToCombine[0]];

        for (uint256 i = 1; i < _tokensToCombine.length; i++) {
            uint256 tokenId = _tokensToCombine[i];
            // Check to see if token exists & msg.sender owns the token
            require(ownerOf(tokenId) == msg.sender);
            newWord = string.concat(newWord, "%20", tokenWords[tokenId]);
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
        req.add("get", string.concat(
            "https://nordle-server-ltu9g.ondigitalocean.app/draw?phrase=",
            phrase
        ));
        req.add("path", "payload,data"); // response looks like: { payload: { data: '' } }
        requestId = uint256(sendChainlinkRequest(req, feeAnyApi));
    }

    function _mintWord(uint256 _apiRequestId, string memory _imageUrl) internal {
        // NOTE: burn before minting, for safety
        if (tokensToBurn[_apiRequestId].length > 0) {
            for (uint256 i = 0; i < tokensToBurn[_apiRequestId].length; i++) {
                uint256 tokenId = tokensToBurn[_apiRequestId][i];
                _burnWord(tokenId);
            }
            delete tokensToBurn[_apiRequestId];
        }

        address owner = wordRequesters[_apiRequestId];
        _mint(owner, tokenIdCount);
        _setTokenURI(tokenIdCount, _imageUrl);
        tokenWords[tokenIdCount] = requestWords[_apiRequestId];

        userTokenIds[owner].push(tokenIdCount);
        userTokenIdIndex[owner][tokenIdCount] = userTokenIds[owner].length-1;

        tokenIdCount++;
        delete wordRequesters[_apiRequestId];
        delete requestWords[_apiRequestId];
    }

    function _burnWord(uint256 tokenId) internal {
        // Swap to-be-burned tokenId with the last tokenId in the unordered list
        // Then burn & delete the last tokenId (which is the correct tokenId to burn)
        address owner = ownerOf(tokenId);
        uint index = userTokenIdIndex[owner][tokenId];

        _burn(tokenId);
        userBurnedTokenIds[owner].push(tokenId);

        userTokenIds[owner][index] = userTokenIds[owner][userTokenIds[owner].length-1];
        userTokenIdIndex[owner][userTokenIds[owner][index]] = index;

        delete userTokenIds[owner][userTokenIds[owner].length-1];
        delete userTokenIdIndex[owner][tokenId];
    }

    function getTokenIds(address user) public view returns (uint256[] memory) {
        return userTokenIds[user];
    }

    function getBurnedTokenIds(address user) public view returns (uint256[] memory) {
        return userBurnedTokenIds[user];
    }

    function withdraw() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
        (bool sent, ) = address(msg.sender).call{value: address(this).balance}(
            ""
        );
        require(sent, "Unable to transfer");
    }

    receive() external payable {}
}
