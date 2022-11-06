import { ethers } from "hardhat"
import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { NORDLE_CONTRACT_ADDRESS } from "../constants"
import { ERC20__factory, Nordle, Nordle__factory } from "../typechain-types"
import { verify } from "../utils/verify"

// Goerli config
const LINK_TOKEN_ADDRESS = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB"
const ORACLE_ADDRESS = "0xCC79157eb46F5624204f47AB42b3906cAA40eaB7"
const VRF_COORDINATOR_ADDRESS = "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D"
const VRF_KEY_HASH =
    "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15"
// const jobId = '7da2702f37fd48e5b1b9a5715e3509b6'
// const vrfSubscriptionId = 6097
const VRF_SUBSCRIPTION_ID = 6108

const deployNordle: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
) {
    const { deployments, getNamedAccounts, network } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    const deployerSigner = await ethers.getSigner(deployer)

    // Withdraw link from prev contract
    console.log("Withdrawing LINK from prev Nordle...")
    const prevNordle: Nordle = Nordle__factory.connect(
        NORDLE_CONTRACT_ADDRESS,
        deployerSigner
    )
    const prevNordleWithdrawTx = await prevNordle.withdraw()
    await prevNordleWithdrawTx.wait(1)
    console.log("Withdrew LINK from prev Nordle!")

    // Deploy NordleWordBank contract
    console.log("Deploying NordleWordBank on ", network.name)

    const NordleWordBankDeployResponse = await deploy("NordleWordBank", {
        from: deployer,
        log: true,
        waitConfirmations: 3,
    })

    console.log("Deployed NordleWordBank to: ", NordleWordBankDeployResponse.address)

    // Deploy Nordle contract
    console.log("Deploying Nordle on ", network.name)

    let args: (string | number)[] = [
        LINK_TOKEN_ADDRESS,
        ORACLE_ADDRESS,
        VRF_COORDINATOR_ADDRESS,
        VRF_KEY_HASH,
        VRF_SUBSCRIPTION_ID,
        NordleWordBankDeployResponse.address,
    ]

    const NordleDeployResponse = await deploy("Nordle", {
        from: deployer,
        args,
        log: true,
        waitConfirmations: 3,
    })

    console.log("Deployed Nordle to: ", NordleDeployResponse.address)

    // Fund deployed contract
    console.log("Funding contract with LINK...")
    const fundingLinkAmount = ethers.utils.parseEther("1")
    const linkTokenContract = ERC20__factory.connect(
        LINK_TOKEN_ADDRESS,
        deployerSigner
    )
    const linkTransferTx = await linkTokenContract.transfer(
        NordleDeployResponse.address,
        fundingLinkAmount
    )
    await linkTransferTx.wait(1)
    console.log("Funded contract with LINK!")

    await verify(NordleDeployResponse.address, args)
}

export default deployNordle
deployNordle.tags = ["all", "Nordle"]
