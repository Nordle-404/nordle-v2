# Nordle (contracts)

Nordle is a unique attempt at reimagining NFTs. *Mint an Nord, be a AI-powered Nerd!*

Mint an Nord  using a randomly generated word that instructs DALL-E to randomly generate an associated image.

Combine the Nords into a longer phrase and generate novel images with DALL-E. A "flying" Nord and "unicorn" Nord will produce a ["flying unicorn" Nord](https://bafybeifpx2uxcidm3st65446x6cc7ow2yglbdfatenq5cxlv4uimkqag5m.ipfs.w3s.link/flying_unicorn).

## Observations

In recent months, the AI community has seen the massive popularity of generative ML models in real-life applications. From GPT-3 and StableDiffusion to DALL-E, the community has created a new field of content generation. However, the NFT community has yet failed to fully leverage the cutting-edge generative art models from the ML community. 

NFT images are still drawn and rigged by people manually. Not only is their creativity limited to their local perspectives, but they are often biased to follow successful projects. For instance, countless collections mimic BAYC in hopes of earning quick cash. These repetitive artistic expressions bring more trouble for NFT buyers and prohibit the introduction of NFTs into a wider population (who’d enjoy the same-looking monkeys everywhere?). Generative models like DALL-E, on the other hand, can produce unique art on a massive scale. Furthermore, given the same phrase/thoughts, DALL-E can generate countless arts related to the phrase. This unique computational creativity breaks the traditional cycle of trait-based NFTs; it introduces one-in-one arts that people can feel more special about. What’s more amazing is that images can now be stored as phrases, and phrases can be combined to “derive” new images.

## Introducing Nordle

Nordle reimagines a user’s lifetime interaction with NFTs. For a typical NFT project, once art is generated from traits and minted as an NFT, not much happens with the NFT’s art. Nordle is different, it’s interactive with a rewarding mechanism for larger collections. When a user requests to mint a Nordle NFT, a Chainlink VRF is triggered for randomness. The VRF callback function picks a word with randomness from the Nordle Word Bank (which can add/remove words) and sends the Chainlink Any API request to our server. The server receives the word and generates a new image using OpenAI’s DALLE-2, which then gets pinned to IPFS. The user now owns a randomly generated image NFT that is derived from a randomly picked word.

Once the user acquires two or more Nordle NFTs, she can combine the NFTs to produce a new Nordle NFT! If the user owns a “unicorn” NFT and a “happy” NFT, she can call our contract to combine the words in the desired sequence, which triggers the Any API request to our server. The server again generates a new random image with the newly combined words. Now the user gets the “happy unicorn” NFT (or “unicorn happy”) and burns the old NFTs (the record is still maintained). This process can be repeated infinitely to fully reap the benefit of DALL-E while rewarding the collection of cool and/or transitory words! For instance, “gold” might be an expensive Nordle NFT to trade, while “This” as the starting Nordle NFT word can be valued very highly.

Nordle brings novel experiences for users by redefining the NFT lifecycle. Creating a new NFT is a truly random experience backed with Chainlink’s robust VRF and OpenAI’s DALL-E. To incentivize more royal collectors, a larger collection presents many more ways to combine and create the ultimate NFTs.

The website provides an intuitive interface for users to easily see their NFT collection and combine NFTs into a new word. Check out the [Nordle website](https://nordle-website.vercel.app/) to mint and combine NFT! Please be aware that minting & combining takes some time as they involve off-chain components including Chainlink VRF and Any API.

## Execution

Upon the release of DALL-E a few days ago, we conceived this idea and started coding right away. We wrote Solidity contracts from scratch with Hardhat configs and integrated them with Chainlink Any API and VRF (referenced docs), and wrote the server in Node.js to be the intermediary between Any API calls and the OpenAI image generation (which we pin on IPFS). Then we created a simple frontend using Next.js to connect the users with the blockchain.
