## Bi directional streams using workers

This proposal describes use of Ockaam streams to set up bi-directional communication
between Ockam NODES.

With this approach a single node can use multiple streams, but multiple nodes SHOULD NOT
use the same stream

### Goals

1. Application workers can exchange messages
1. Application worker ONLY use Ockam Routing protocol
1. Messages can be persisted and re-delivered after network outages

## Background

In order to establish bidirectional communication between ockam workers,
ockam routing protocol is using route tracing.

Each communication hop should produce a return route, which should be usable to
route the message back.

To use unidirectional channels (like streams) to deliver messages, a message on
the channel should contain an other channel ID to produce a response.

Since the return stream information is in the messages, there may be different
return streams in those.

## Routing

This proposal describes routing to NODES, meaning that messages will be routed
on receiving nodes using the Ockam Routing protocol.

This is done to simplify route tracing.

Stream APIs in this proposal are accessed using LOCAL worker addresses.

Example sending a message through stream:

```
onward_route: ["bds_publisher_local_address_on_remote", "remote_destination"]
return_route: ["sender"]
```

Assuming publishers and consumers are properly set up, the response might be:

```
onward_route: ["bds_publisher_local_address_on_sender", "sender"]
return_route: ["remote_destination"]
```

## Stream Client API

Stream client consists of Consumer workers and Publisher workers, which can be set
up to receive/send message to a stream.

Consumer constantly fetches messages using the stream API.
Publishers send messages using the stream API on demand.

Assumption is that we can attach additional logic to consumer and publisher either
via additional workers or functions.

## Bidirectional stream client API

Bidirectional stream client is implemented on top of Stream Client and implements
additional message processing for Consumers and Publishers

### BiDirectional Publisher

Publisher is a worker, which has a local address. Application workers use publisher
address to send messages through streams.

Publisher state contains a stream to send messages to and a return stream to add to
message metadata

When handling an ockam message, the publisher encodes the message as binary together
with return stream and sends it as a stream protocol payload

### BiDirectional consumer

Bidirectional consumer implements a message handling logic to Stream Consumer

1. Decode stream payload
1. Ensure return stream publisher exists
1. Add return stream publisher to return route of the message
1. Route message to the onward route on the local node

To create return stream publisher, consumer needs to have some sort of registry,
to map return stream to local publisher name

### Setting up communication

SERVER:
1. Create consumer for stream "SERVER_STREAM"

CLIENT:
1. Create consumer for stream "CLIENT_STREAM"
1. Create publisher for stream "SERVER_STREAM" and return stream "CLIENT_STREAM"
1. Send messages to through publisher address in the route


### Message exchange:


```
SERVER                       consumer:SERVER   stream_service
 | create (subscribe)              |                 |
 |-------------------------------> |                 |
 |                                 | create_stream   |
 |                                 | --------------->|
 |                                 | <---------------|
 |                                 |                 |
 |                                 | fetch           |
 |                                 |---------------->|
 |                                 |<----------------|
 |                                 |                 |                publisher:CLIENT   consumer:CLIENT            CLIENT
 |                                 |                 |                       |                 |                      |
 |                                 |                 |                       |                 |  create              |
 |                                 |                 |                       |                 |<---------------------|
 |                                 |                 |                       |                 |                      |
 |                                 |                 |                       |        create                          |
 |                                 |                 |                       | <------------------------------------- |
 |                                 |                 |                       |                                        |
 |                                 |                 |                       |        send                            |
 |                                 |                 |                       | <------------------------------------- |
 |                                 |                 |                       |                                        |
 |                                 |                 | push:SERVER(encoded)  |                 |                      |
 |                                 |                 | <-------------------- |                 |                      |
 |                                 |                 |                       |                 |                      |
 |                                 | fetch           |                       |                 |                      |
 |                                 |---------------->|                       |                 |                      |
 |                                 |<----------------|                       |                 |                      |
 |         publisher:SERVER        |                 |                       |                 |                      |
 |               |    ensure       |                 |                       |                 |                      |
 |               |<--------------- |                 |                       |                 |                      |
 |               |   address       |                 |                       |                 |                      |
 |               |---------------> |                 |                       |                 |                      |
 |                                 |                 |                       |                 |                      |
 |                                 |                 |                       |                 |                      |
 | forward (rr:+address)           |                 |                       |                 |                      |
 |<--------------------------------|                 |                       |                 |                      |
 |                                 |                 |                       |                 |                      |
 |               |                                   |                       |                 |                      |
 |  send (reply) |                                   |                       |                 |                      |
 |-------------->| push:CLIENT(encoded)              |                       |                 |                      |
 |               |---------------------------------->|                                         |                      |
 |                                                   |                  fetch                  |                      |
 |                                 |                 |<----------------------------------------|                      |
 |                                 |                 |---------------------------------------->|                      |
 |                                 |                 |                                         |                      |
 |                                 |                 |                       |  ensure         |                      |
 |                                 |                 |                       | <-------------- |                      |
 |                                 |                 |                       | address         |                      |
 |                                 |                 |                       | --------------> |                      |
 |                                 |                 |                                         | forward(rr:+address) |
 |                                 |                 |                                         | -------------------->|
 |                                 |                 |                                         |                      |

```



