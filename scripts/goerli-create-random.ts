import { NORDLE_CONTRACT_ADDRESS } from "../constants"
import { Nordle__factory } from "../typechain-types"
import { BigNumber } from "ethers"

import { signer } from "./shared"

async function main() {
    const nordle = Nordle__factory.connect(NORDLE_CONTRACT_ADDRESS, signer)

    const tx = await nordle["requestCreateWord()"]({ gasLimit: 5_000_000 })
    console.log(tx.hash)
    console.log(await tx.wait())
}

main().catch((error) => {
    console.error(error)
    process.exit(1)
})
