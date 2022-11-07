import { NORDLE_WORD_BANK_CONTRACT_ADDRESS } from "../constants"

import { signer } from "./shared"
import { NordleWordBank__factory } from "../typechain-types/factories/contracts/NordleWordBank__factory"

async function main() {
    const wordBank = NordleWordBank__factory.connect(NORDLE_WORD_BANK_CONTRACT_ADDRESS, signer)

    // Mint two tokens: Token0 = flying, Token1 = unicorn
    console.log(await wordBank.wordBank())
		console.log((await wordBank.wordsMap('unicorn')).toNumber())
		console.log(await wordBank.exists('unicorn'))
}

main().catch((error) => {
    console.error(error)
    process.exit(1)
})
