import { NORDLE_CONTRACT_ADDRESS } from "../constants"
import { Nordle__factory } from "../typechain-types"
import { BigNumber } from "ethers"

import { signer } from "./shared"

async function main() {
    const nordle = Nordle__factory.connect(NORDLE_CONTRACT_ADDRESS, signer)

    // Mint two tokens: Token0 = rainbow, Token1 = unicorn
    const wordsToMint = ["rainbow", "unicorn"]

    for (let i = 0; i < wordsToMint.length; i++) {
        const newWord = wordsToMint[i]
        console.log(`Minting token ${i} with word ${newWord}...`)
        const txResponse = await nordle["requestCreateWord(string)"](newWord, {
            gasLimit: 5_000_000,
            value: BigNumber.from(5).mul(BigNumber.from(10).pow(16)),
        })
        console.log("hash: ", txResponse.hash)
        await txResponse.wait(1)
        console.log("Sent request to Chainlink Any API!")
        console.log("----------")
    }
}

main().catch((error) => {
    console.error(error)
    process.exit(1)
})
