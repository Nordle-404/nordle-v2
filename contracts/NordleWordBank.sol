// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NordleWordBank is Ownable {
		string[] public words = ["unicorn", "outlier", "ethereum", "pepe", "rainbow", "happy", "royal", "gold", "shiny", "ape"];
		string[] public requested;

		mapping(string => uint256) public wordsMap;
		mapping(string => uint256) public requestedMap;

		constructor() {
				// Finish initializing default words
				for (uint i = 0; i < words.length;) {
					wordsMap[words[i]] = i;
					unchecked {
						i++;
					}
				}
		}

		function requestWord(string memory word) public {
				require(requestedMap[word] == 0, 'Already requested');
				// comparing string memory to literal_string can be done by hashing w keccak
				require(wordsMap[word] == 0 && keccak256(bytes(word)) != keccak256(bytes('unicorn')), 'Already added');
				requested.push(word);
				requestedMap[word] = requested.length-1;
		}

		function acceptWord(string memory word) public onlyOwner {
				require(wordsMap[word] == 0 && keccak256(bytes(word)) != keccak256(bytes('unicorn')), 'Already added');
				words.push(word);
				wordsMap[word] = words.length-1;
				deleteRequestedWord(word);
		}

		function rejectWord(string memory word) public onlyOwner {
				// require word exists in requested?
				deleteRequestedWord(word);
		}

		function deleteRequestedWord(string memory word) internal {
				uint index = requestedMap[word];
				requested[index] = requested[requested.length-1];
				requestedMap[requested[index]] = index;
				delete requested[requested.length-1];
				delete requestedMap[word];
		}

		function removeWord(string memory word) public onlyOwner {
				uint index = wordsMap[word];
				if (index == 0) return; // caveat: item 0 is undeletable, but that's ok because it's unicorn
				// if (words.length > 1) // we don't need to check if words.length > 1 ^^
				words[index] = words[words.length-1];
				wordsMap[words[index]] = index;
				delete words[words.length-1];
				delete wordsMap[word];
		}

		function exists(string memory word)	public view returns (bool) {
				return wordsMap[word] != 0 || keccak256(bytes(word)) == keccak256(bytes('unicorn'));
		}

		function wordBank() public view returns (string[] memory) {
			return words;
		}
		// receive() external payable {}
}