import { NORDLE_CONTRACT_ADDRESS } from "../constants"
import { Nordle, Nordle__factory } from "../typechain-types"
import { config as dotenvConfig } from "dotenv"
import { utils, providers, BigNumber, Wallet } from "ethers"
import { resolve } from "path"

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "../.env"
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) })

const mnemonic: string | undefined = process.env.MNEMONIC
if (!mnemonic) {
    throw new Error("Please set your MNEMONIC in a .env file")
}

const provider = new providers.JsonRpcProvider(
    "https://rpc.ankr.com/eth_goerli"
)
const wallet = Wallet.fromMnemonic(mnemonic)
const signer = wallet.connect(provider)

async function main() {
    const nordle = Nordle__factory.connect(NORDLE_CONTRACT_ADDRESS, signer)

    // Mint two tokens: Token0 = flying, Token1 = unicorn
    const wordsToMint = ["unicornflying", "unicornrainbows"]

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
