import { NORDLE_CONTRACT_ADDRESS } from "../constants"
import { Nordle__factory } from "../typechain-types"
import { BigNumber } from "ethers"

import { signer } from "./shared"

async function main() {
    const nordle = Nordle__factory.connect(NORDLE_CONTRACT_ADDRESS, signer)

    // Mint two tokens: Token0 = flying, Token1 = unicorn
    // const ids = [2]
    const addr = signer.address
    const ids = await nordle.getTokenIds(addr)
    const burnedIds = await nordle.getBurnedTokenIds(addr)
    console.log(ids)
    console.log(burnedIds)
    return

    // for (let i = 0; i < ids.length; i++) {
    //     const id = ids[i]
    //     console.log(`>>> Checking ID ${id}...`)
    //     console.log(`- Owner: ${await nordle.ownerOf(id)}`)
    //     console.log(`- Phrase: ${await nordle.tokenWords(id)}`)
    //     console.log(`- Image: ${await nordle.tokenURI(id)}`)
    // }
}

main().catch((error) => {
    console.error(error)
    process.exit(1)
})
