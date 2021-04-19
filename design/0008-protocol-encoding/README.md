## Protocol encoding for message payloads

### The problem

In order to send structured messages and be able to create APIs between
different implementations, we use the BARE encoding: https://baremessages.org/

This format encodes messages based on schemas and relies on both ends to have
the same schema.

If there are multiple types of schemas to use, BARE provides a "union type",
which contains an integer type tag based on a "union schema"

If there are multiple independent services and protocols it becomes hard to combine
them into a single "union schema" as they have to be aware of each other schemas.

This would apply to other structured binary encoding formats as well.

### Proposal

In order to tell different protocol messages, each message should use the same
BasePayload encoding, which will include a protocol tag to specify which protocol
should be used and a binary `data` field:

```
type BasePayload {
  protocol: string
  data: data
}
```

In the message, this payload will be encoded as a binary.
The message schema in this case would be:

```
type Message {
  onward_route: []Address
  return_route: []Address
  version: uint
  payload: data
}
```

This allows implementations to choose the right schema to use with this data before
trying to decode the data.

The API libraries can provide the protocol-schema specification to use in the matching code.

#### Protocol mapping spec

Each protocol specifies a name and a two schemas for request and response:

```
name: string
request: schema
response: schema
```

Then an implementation should choose which schema (request or response) it should use
to decode messages and which to encode.

A worker which decodes requests and encodes responses is called a "server"
A worker which encodes requests and decodes responses is called a "client"


When a worker needs to process messages from multiple protocols, it defines
a "protocol mapping", specifying which protocols it uses as a "client" and which
as a "server":

Elixir code to define protocol mapping to decode `response` from `Protocol.To.Call`
and `Other.Protocol.To.Call` and `request` from `Protocol.To.Handle`

```elixir
  def protocol_mapping() do
    Ockam.Protocol.mapping([
      {:client, Protocol.To.Call},
      {:client, Other.Protocol.To.Call}
      {:server, Protocol.To.Handle}
    ])
  end
```

### Example definitions

Let's say we have a service which tells us if a number is higher than 10
It will accept integers and return `TRUE` or 'FALSE'

The BARE schemas used will be following:

```
type Request uint

enum Bool {
  TRUE
  FALSE
}

type Response Bool
```

And the protocol name would be "more_than_10"

In Elixir the protocol is defined as follows:

```elixir
defmodule Ockam.Protocol.MoreThan10
  @behaviour Ockam.Protocol

  def protocol() do
    %Ockam.Protocol{
      name: "more_than_10",
      request: :uint,
      response: {:enum, [true, false]}
    }
  end
end
```

Then the service can define the protocol mapping and handle messages:

```elixir
defmodule Ockam.Service.MoreThan10 do

  ...

  def protocol_mapping() do
    Ockam.Protocol.mapping([
      {:server, Ockam.Protocol.MoreThan10}
    ])
  end

  ### Message handling
  def handle_message(%{payload = payload}, _state) do
    case MessageProtocol.decode_payload(payload, protocol_mapping()) do
      {:ok, "more_than_10", i} when is_integer(i) ->
        response = i > 10 ## Booleans are atoms in elixir so this is valid
        encode_response("more_than_10", response)
      _ ->
        ## Unmatched message
        ...
    end
  end
end
```

The client:

```elixir
defmodule My.Client.Worker do

  ...

  def protocol_mapping() do
    Ockam.Protocol.mapping([
      {:client, Ockam.Protocol.MoreThan10}
    ])
  end

  ### Message handling
  def handle_message(%{payload = payload}, _state) do
    case MessageProtocol.decode_payload(payload, protocol_mapping()) do
      {:ok, "more_than_10", :true} ->
        ## TRUE response
        ...
      {:ok, "more_than_10", :false} ->
        ## FALSE response
        ...
      _ ->
        ## Unmatched message
        ...
    end
  end
end

```
