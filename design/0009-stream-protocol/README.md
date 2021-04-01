# Stream service protocol

The purpose of this protocol is to allow implementations to use a unified stream
service in ockam hub to store messages for extended time and retrieve them when needed.

The main use-case would be to facilitate any kind of message exchange between clients
which might be offline for some time or not discoverable by each other.

## Base concepts

The stream service stores messages for a certain limited period of time (can be minutes, can be years)

Messages are stored in multiple ordered storages (streames), each stream has an identifier (address)

Streames are accessible via Ockam Routing messages

Messages are retrieved using a PULL model - to retrieve new messages the client has to "call" the stream API

## Protocol API

### Addresses

Stream service is registered with a service address, assume it's "stream_service"

Each stream is given it's own address in the context of the same node as the stream service.

Each stream MAY have a prefix "MAILBOX" or the stream service address prefix to its address

### Messages

#### Stream creation

CREATE message sent to the stream service address:

```
{
  onward_route: ... => stream_service,
  return_route: <CREATE_RETURN_ROUTE>,
  payload: <PAYLOAD>
}
```

Where `<PAYLOAD>` should contain the stream name and is encoded with the following BARE schema:

```
type CreateStreamRequest {
  stream_name: optional<string>
}
```

After stream is created, the MAILBOX WORKER should send an INIT response to original sender
using `<CREATE_RETURN_ROUTE>`:

```
{
  onward_route: <CREATE_RETURN_ROUTE>,
  return_route: [<stream_address>],
  payload: INIT
}
```

Where INIT payload has the following BARE format:
```
type Init {
  stream_name: string
}
```

`<stream_address>` SHOULD be created based on the `stream_name`, if it's provided

`<stream_address>` MAY have some prefix

If `stream_name` is not provided, the stream service SHOULD create a random stream address

Payload MAY contain some additional information about the stream

The client MUST use stream address from the return route

The stream service MUST be aware of created streames and their names

If a CREATE request comes with existing stream, the stream worker MUST send the INIT
response to the sender of the CREATE message

```
client       stream_service
  |                 |
  |  CREATE         |
  |---------------->|  create worker
  |                 | ----------------> stream_worker
  |                 |                         |
  |                      INIT                 |
  |<------------------------------------------|
  |                                           |
  |                                           |
maybe some other                              |
client                                        |
  |  CREATE         |                         |
  |---------------->| worker exists, notify   |
  |                 | ----------------------->|
  |                 |                         |
  |                      INIT                 |
  |<------------------------------------------|

```

Communication between stream service and stream worker is up to the implementation


**TODO:** stream cleanup/deletion API

#### Pushing/pulling messages

To push a message the client should send a message to the stream worker with the payload BARE encoded in the following format:

```
type PushRequest {
  request_id: uint
  data: data
}
```

When message is saved, the stream will respond with:

```
enum Status {
  OK
  ERROR
}
type PushConfirm {
  request_id: uint
  status: Status
  index: uint
}
```

The publisher client MAY re-send messages if it didn't get the Status: OK response.

Messages pushed with the same request id WILL ALL BE SAVED,
the purpose of the request id is delivery confirmation and not deduplication.

If a client send multiple messages with the same id - it SHOULD expect multiple confirm
responses for this id, but that makes reliable delivery challenging

The client SHOULD use different request_id for different messages

Index in the response identifies the saved message in the stream.
Each message in the stream MUST have unique index.

Index MAY be used to consume the messages and to check their consumption status

Index MUST be monotonically increasing

Index MUST be scoped per stream and NOT per publisher. Since there could be multiple
publishers, a publisher MAY receive non-uniform sequence (e.g. [1,2,5,7,8])


To retrieve N messages from the stream starting from index I, the client should send a message to the stream worker with payload BARE format:

```
type PullRequest {
  request_id: uint
  index: uint
  limit: uint
}
```

`index` MAY be 0, which means to start from the earliest message possible


The stream worker MUST send a PullResponse message with 0 - `limit` messages
to the requests return_route with the following payload format:

```
type PullResponse {
  request_id: uint
  messages: []StreamMessage
}

type StreamMessage {
  index: uint
  data: data
}
```

`data` of the message MUST be the same as `data` sent in PushRequest

Indexes in the messages MAY NOT start with the requested index, but MUST NOT be lower than the requested index

**NOTE** for reliable delivery this needs to be changed somehow

Messaging process

```
publisher        stream
  |                 |
  |  PUSH           |
  |---------------->|
  |  PushConfirm    |
  |<----------------|
  |                 |
  |  PUSH           |
  |---------------->|
  |  PushConfirm    |
  |<----------------|
  |                 |
  |  PUSH           |
  |---------------->|
  |  PushConfirm    |
  |<----------------|
  |                 |
  |                 |                  consumer
  |                 |                      |
  |                 |    PULL(I, 3)        |
  |                 |<---------------------|
  |                 |    PullResponse      |
                    |--------------------->|

```

## Reliable delivery

The client may repeat the PULL request with the same index or with already received index to re-fetch the messages

When do cleanup messages is up to the stream service implementation.
It MAY guarantee some retention time AND/OR length of the queue, also it MAY delete messages at any time

In order to provide reliable delivery the client MUST keep track of received indexes, detect "holes" in delivery
and persist the last received index to resumer pulling.


## Addition: index management and reliable delivery

To allow clients to unload the responsibility for index management
and let clients restart and maybe lose their consumer state, there can be additional
index management system implemented.

Index management should keep an index per consumer/stream pair, allow to update it
and retrieve it.

Proposing the following API:

#### Addresses

Client index service should be registered with a custom name, e.g. "stream_index_service"

#### Creating/retrieving a stream index

The client sends message with the following payload:

```
type GetIndex {
  stream_name: string
  client_id: string
}
```

Response contains the following payload:

```
type Index {
  stream_name: string
  client_id: string
  index: optional<uint>
}
```

If the client did not have an index saved before, a new record MUST be created with an index 0

#### Updating an index

When client processed a message, it MAY save this message index using the following payload:

```
type SaveIndex {
  stream_name: string
  client_id: string
  index: uint
}
```

Index storage MUST be monototnic, if the current saved index is already higher than `SaveIndex`,
it MUST NOT be changed.

To provide reliable delivery, the client SHOULD NOT save a higher index
if it did not processed lower index messages yet.


### Putting it all together

In order to provide a reliable message delivery with stream service, there should be
the following services

- Stream service (name it "stream_service")
- Client index service (name it "stream_index_service")

Then to provide one-directional message flow from one client to another (aka "publisher" and "consumer")
we follow this process:

Assume we have the stream_name negotiated between publisher and consumer.

```
publisher       stream_service                                                 stream_index_service
  |                 |                                                                 |
  |  CREATE         |                                                                 |
  |---------------->|  create worker                                                  |
  |                 | -------------------> stream                                    |
  |                 |                         |                                       |
  |                      INIT                 |                                       |
  |<------------------------------------------|                                       |
  |                 |                         |                                       |
  |                 |                         |                                       |
  |                 |                         |                 consumer              |
  |                 |                         |                     |                 |
  |                 |          CREATE                               |                 |
  |                 | <---------------------------------------------|                 |
  |                 |          notify                               |                 |
  |                 | ----------------------->|                     |                 |
  |                                           |         INIT        |                 |
  |                                           |-------------------->|                 |
  |                                           |                     |                 |
  |               PUSH                        |                     |                 |
  |------------------------------------------>|                     |                 |
  |               PushConfirm                 |                     |                 |
  |<------------------------------------------|                     |                 |
  |                                           |                     |                 |
  |               PUSH                        |                     |                 |
  |------------------------------------------>|                     |                 |
  |               PushConfirm                 |                     |                 |
  |<------------------------------------------|                     |                 |
  |                                           |                     |                 |
  |               PUSH                        |                     |                 |
  |------------------------------------------>|                     |                 |
  |               PushConfirm                 |                     |                 |
  |<------------------------------------------|                     |                 |
  |                                           |                     |                 |
  |                                           |                     |  GetIndex       |
  |                                           |                     |---------------->|
  |                                           |                     |                 |
  |                                           |                     | Index(I)        |
  |                                           |                     |<----------------|
  |                                           |                     |                 |
  |                                           |    PULL(I, 3)       |                 |
  |                                           |<--------------------|                 |
  |                                           | PullResponse(I1-I3) |                 |
                                              |-------------------->|                 |
                                              |                     | SaveIndex(I3)   |
                                                                    |---------------->|

```

## Partitioned stream

Stream abstraction operates on a single sequence of indexes.

Most streaming backends like Kinesis or Kafka support logical grouping of multiple
streams using partitions.

Partitions are multiple indexed streams identified by parition number whithin shared identity,
called stream or topic.

Because each parition follows similar structure as a single Ockam stream, streams
can be used as partitions in this model.
To achieve that, parition number can be added to the stram instance.

Protocol extension to use to create partitioned streams:

### Create partitioned stream

```
type CreatePartitionedStreamRequest {
  stream_name: optional<string>
  partitions: uint
}
```

```
type CreatePartitionedStreamResponse {
  stream_name: string
  partition: uint
}
```

Stream service MUST create multiple stream instances, one for each partition.
Each partition instance MUST send CreatePartitionedStreamResponse

Client SHOULD associate partition number with return route to push/pull messages to
different partitions.

### Partitioned stream index

Index API can use partitions:

Request:

```
type GetPartitionIndex {
  client_id: string
  stream_name: string
  partition: uint
}

type SavePartitionIndex {
  client_id: string
  stream_name: string
  partition: uint
  index: uint
}

type Request (GetIndex | SaveIndex)
```

Response:

```
type PartitionIndex {
  client_id: string
  stream_name: string
  partition: uint
  index: optional<uint>
}
```


## Payload BARE specs

The Stream protocol is using [protocol encoding](../0008-protocol-encoding/README.md) to encode message payloads

### Base payload

```
type BasePayload {
  protocol: string
  data: data
}
```

Each message has a protocol name tag. Data is encoded with the protocol specs:

### Protocols

#### Create stream

Protocol name: `stream_create`

Request:

```
type Request {
  stream_name: optional<string>
}
```

Response:

```
type Init {
  stream_name: string
}
```

#### Push

Protocol name: `stream_push`

Request:

```
type PushRequest {
  request_id: uint
  data: data
}
```

Response:

```
enum Status {
  OK
  ERROR
}

type PushConfirm {
  request_id: uint
  status: Status
  index: uint
}
```

#### Pull

Protocol name: `stream_pull`

Request:

```
type PullRequest {
  request_id: uint
  index: uint
  limit: uint
}
```

Response:

```
type PullResponse {
  request_id: uint
  messages: []StreamMessage
}

type StreamMessage {
  index: uint
  data: data
}
```

#### Index

Index protocol is used by the index service

Protocol name: `stream_index`

Request:

```
type GetIndex {
  client_id: string
  stream_name: string
}

type SaveIndex {
  client_id: string
  stream_name: string
  index: uint
}

type Request (GetIndex | SaveIndex)
```

Response:

```
type Index {
  client_id: string
  stream_name: string
  index: optional<uint>
}
```

#### Create partitioned stream

Create multiple streams with the same stream name and different partition ids

Protocol name: `stream_create_partitions`

Request:

```
type Request {
  stream_name: optional<string>
  partitions: uint
}
```

Response:

```
type Init {
  stream_name: string
  partition: uint
}
```

#### Partitioned index

Protocol name: `stream_index`

Request:

```
type GetIndex {
  client_id: string
  stream_name: string
  partition: uint
}

type SaveIndex {
  client_id: string
  stream_name: string
  partition: uint
  index: uint
}

type Request (GetIndex | SaveIndex)
```

Response:

```
type Index {
  client_id: string
  stream_name: string
  partition: uint
  index: optional<uint>
}
```

### Error

Protocol name `error`

Response:

```
type Error {
  reason: string
}

```

### Stream services support the following protocols

Stream service:

Request: `stream_create:request`
Response: `error:response`

Stream instance:

Request: `stream_pull:request`, `stream_push:request`
Response: `stream_create:response`, `stream_pull:response`, `stream_push:response`, `error:response`

Stream index service:

Request: `stream_index:request`
Response: `stream_index:response`


