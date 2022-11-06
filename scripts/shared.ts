import { config as dotenvConfig } from "dotenv"
import { providers, Wallet } from "ethers"
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

export { signer }