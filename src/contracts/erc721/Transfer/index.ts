import type { eventLog, handlerContext, ERC721_Transfer_eventArgs, NftTransfers } from "generated"
import { CHAIN_ID_TO_CHAIN_NAME } from "../../../constants/common"

export async function transferHandler({
  context,
  event,
}: {
  context: handlerContext
  event: eventLog<ERC721_Transfer_eventArgs>
}): Promise<void> {
  try {
    const { block, chainId, params, srcAddress, transaction } = event
    const { from, to, tokenId } = params

    const transfer: NftTransfers = {
      id: `${chainId}_${srcAddress}_${tokenId.toString()}_${block.number}`,
      chain: CHAIN_ID_TO_CHAIN_NAME[chainId as keyof typeof CHAIN_ID_TO_CHAIN_NAME],
      contract_address: srcAddress,
      from_address: from,
      to_address: to,
      caller_address: transaction.from ?? from,
      token_id: tokenId,
      quantity: BigInt(1),
      created_at: new Date(block.timestamp * 1000),
      updated_at: new Date(block.timestamp * 1000),
      block_number: block.number,
      block_timestamp: block.timestamp,
      transaction_hash: transaction.hash,
    }

    await context.NftTransfers.set(transfer)

    context.log.info(`NftTransfers event processed: ${srcAddress}`)
  } catch (error) {
    context.log.error(`Error processing NftTransfers event: ${error}`)
    throw error
  }
}
