import { ERC721 } from "generated"
import { transferHandler } from "./Transfer"

// import { rabbitMqService, connectRabbitMq } from "../../connection"

ERC721.Transfer.handler(({ context, event }) => transferHandler({ context, event }), {
  wildcard: true,
})
