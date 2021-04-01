## Stream transport

This proposal describes a way to achieve bi-directional communication between
workers via streams.

In order to do that, a new transport type is implemented using streams as a delivery
method.

## Basics

Stream protocol defines unidirectional communication between workers and requires
them to do requests to the stream service using ockam routing messages.

This is done in order to achieve reliable delivery of messages and use existing
messaging systems, which mostly implement unidirectional communication.

Meanwhile transports are an abstraction in the ockam nodes architecture, which
allows to set up bi-directional communication over some delivery methods.

We can think of the stream protocol in this case as a delivery method for the transport.

### Splitting the streams

In messaging systems two main ways to achieve bidirectional communication are either
use separate streams for outgoing and returning messages or use tagged messages
and filter on consumption.

This proposal describes the first approach as it's easier to reason about two separate
streams and saves some messaging bandwidth.

## Definitions

### Protocol addresses

To implement bi-directional transport, each address in a message should contain
two components: a stream to send messages to and to receive them from.

Some special convention may be used for that, but that makes integration with external
systems harder.

Instead the address is defined as following:

```
type StreamAddress {
  onward_stream: string
  return_stream: string
}
```

Where `onward_stream` is a stream to send the message to, and `return_stream`
is the stream is the stream which should be used to send responses.

When sending messages to the stream, the transport MUST add REVERSED stream address to the
return route of the sent message.

### Sending messages

The transport MUST use the stream protocol to send a message to the `onward_stream`.
The transport MUST create the onward stream if it didn't exist before

The transport SHOULD create the return stream and start fetching messages for it
when sending messages.

Stream protocol expect binary data and messages MUST be encoded with the wire protocol,
same as for sending TCP messages.

### Receiving messages

Stream consumer SHOULD fetch messages periodically or by external event.

Consumer SHOULD decode stream messages content into routed messages

Because sending messages already updating the address, there should be no need to
update the routes

Consumer MAY be configured to send messages to some specific address, but SHOULD
update routes to keep address tracing in there consistent.

### Subscriptions

Subscription or a consumer is a worker, fetching messages periodically from a stream
using the stream protocol.

In order to communicate with stream transports nodes MUST be subscribed to the streams
they're communicating with.

The transport MAY create a subscription when processing a message sent with stream transport.

## Establishing a session using stream transport


Assume we have two nodes, node A and node B, which want to communicate using the
stream protocol

First, we need to assign some stream names for A->B and B->A communication, let's
call them `stream_a` and `stream_b`

Assume that both nodes know a route to a stream service they can communicate with and
a stream transport set up to talk to that service.

One node needs to subscribe to it's stream first, let's say it's node B

```
 B           B:transport    consumer:stream_b  stream_service
 | subscribe      |              |                |
 |--------------->|  create      |                |
 |                | -----------> | create_stream  |
 |                |              | -------------->|
 |                |              | <--------------|
 |                |              |                |
 |                |              | fetch          |
 |                |              |--------------->|
 |                |              |<---------------|

```


Then the node A can send a message to node B using the transport and address

`{onward_stream: "stream_b", return_stream: "stream_a"}`

The transport would create a consumer to receive responses:

```
 A           A:transport    consumer:stream_a  stream_service
 | route          |              |                 |
 |--------------->|  create      |                 |
 |                | -----------> | create_stream   |
 |                |              | --------------> |
 |                |              | <-------------- |
 |                |
 |                |             push:stream_b
 |                | -----------------------------> |
 |                |
 |                |              |
 |                |              |
 |                |              |                 |
 |                |              | fetch           |
 |                |              |---------------> |
 |                |              |<--------------- |

```


The message would be fetched by the consumer for B and delivered to the onward route:

```
stream_service   consumer:stream_b         B
 | fetch              |                    |
 |<-------------------|                    |
 |------------------->|                    |
 |                    | forward_message    |
 |                    | -----------------> |
```

Then B can use the traced return_route to send messages back to A.

#### Tracing the message route and encoding:

```
Node A:

A -> A:transport:
onward_route: [StreamAddress{onward_stream: stream_b, return_stream: stream_a}, B]
return_route: [A]

The transport reverts the stream address on send:

A:transport: forwarded_message
onward_route: [B]
return_route: [StreamAddress{onward_stream: stream_a, return_stream: stream_b}, A]

A:transport: stream push
onward_route: [stream_b_address]
return_route: [A:transport]
payload: encoded forwarded_message

Node B:

request:
consumer:stream_b: stream fetch
onward_route: [stream_b_address]
return_route: [consumer:stream_b]

consumer:stream_b: stream fetch response
onward_route: [consumer:stream_b]
return_route: [stream_b_address]
payload: encoded forwarded_message

B: receives forwarded_message
onward_route: [B]
return_route: [StreamAddress{onward_stream: stream_a, return_stream: stream_b}, A]
```


#### Putting it together

```
 B           B:transport    consumer:stream_b  stream_service
 | subscribe      |              |                |
 |--------------->|  create      |                |
 |                | -----------> | create_stream  |
 |                |              | -------------->|
 |                |              | <--------------|
 |                |              |                |
 |                |              | fetch          |
 |                |              |--------------->|
 |                |              |<---------------|
 |                |              |                |              consumer:stream_a    A:transport      A
 |                |              |                |                   |                   |      route |
 |                |              |                |                   |                   |<-----------|
 |                |              |                |                   |       create      |            |
 |                |              |                |                   |<------------------|            |
 |                |              |                | create stream     |                   |            |
 |                |              |                |<------------------|                   |            |
 |                |              |                |------------------>|                   |            |
 |                |              |                |                                       |            |
 |                |              |                |         push:stream_b (encoded)       |            |
 |                |              |                |<--------------------------------------|            |
 |                |              | fetch          |                                       |            |
 |                |              |--------------->|                   |                   |            |
 |                |              |<---------------|                   |                   |            |
 |                               |                |                   |                   |            |
 |         forward (decoded)     |                |                   |                   |            |
 |<------------------------------|                |                   |                   |            |
 |                               |                |                   |                   |            |
 |                |              |                |                   |                   |            |
 | reply          |              |                |                   |                   |            |
 |--------------->|              |                |                   |                   |            |
 |                |                               |                   |                   |            |
 |                |   puss:stream_a               |                   |                   |            |
 |                |------------------------------>|                   |                   |            |
 |                |              |                |   fetch           |                   |            |
 |                |              |                |<------------------|                   |            |
 |                |              |                |------------------>|                   |            |
 |                |              |                |                   |                                |
 |                |              |                |                   |   forward (decoded)            |
 |                |              |                |                   |------------------------------->|
 |                |              |                |                   |                                |

```