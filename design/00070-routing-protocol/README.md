## Application Routing protocol:

The goal of this protocol is to facilitate two way communication between remote endpoints connected
by multiple delivery mechanisms.

Routing allows to send messages through multiple hops and trace a return path to send messages back

The routing protocol should allow communication by keeping track of the intended route of the message
and the path it went through, which it can use as a route to send the message back.

At the same time the intermediate nodes can change the path of the message routing in order to deliver
to the final destination.


### Definitions:

The protocol defines the following concepts:

- Address - a destination to send a message to

- Route - an ordered list of addresses specifying a path for a message to follow

- Message - a data structure containing routes and some payload

- Router - mechanism to route messages to addresses

- Worker - some running code able to handle messages, usually have associated address

### Destination types:

In order to route messages through different delivery mechanisms,
each address has the type field, and a serializable data field.

Address type specifies addressing schema, while data is type specific and points to a destination whithin the schema.

For example for the TCP type data can be an ip:port pair, for mqtt type it might be a topic.

Default address type is 0, such addresses are called "local".

A router SHOULD be able to register new types, defining new routing rules.

A router MUST be able to route to type 0 addresses (these considered local)

A router MAY drop messages if the address type is unknown.


### Message format:

```
{
  onward_route: Route,
  return_route: Route,
  payload: Opaque
}
```

Each message contains the onward route specifying a path the message should follow
and the return route, specifying the path a reply to the message should be sent to.

Payload contains binary data, the router MUST NOT change the payload 

When routing a message, the router MUST send it to the FIRST address in the onward route.


### Workers and message passing:

Workers are stateful message handlers

Workerd receive messages and can send them

In the received message, the first element of the onward route will be the worker
own address. There MAY be multiple own addresses for the same worker.

There are few patterns workers implement:

- Forwarding:
  To forward a message, a worker should route it further, with updated onward route and return route
  Onward route should have the worker own address removed
  Workers own address should be added to the return route

  These own addresses MAY be different

  Simple example with same own addresses for onward and return routes: 
  ```
  receive {onward_route: [forwarder, next], return_route: [sender]}
  ->
  send {onward_route: [next], return_route: [forwarder, sender]}
  ```

- Replying:
  To reply to a message, a worker routes a response with return route as an onward route and vice versa:
  ```
  receive {onward_route: [responder], return_route: [something, sender]}
  ->
  send {onward_route: [something, sender], return_route: [responder]}
  ```

In the complex message route, such as `[a, b, c]`,
non-final addresses (`a` and `b`) SHOULD forward the message,
while the final address `c` MAY reply to the message


## Network architecture:

?? This does not have to be a part of the routring protocol, it looks more like another mechanism implemented on top of it ??

Nodes and transports:

Since routing protocol requires any router to be able to route to type 0 addresses,
these addresses are called "local".

A set of workers on "local" addresses and a router is called `Node`

There MAY be multiple nodes in an Ockam system.

Each node SHOULD have its own router and routes MAY have different schemas registered.

All nodes in a system MUST have the same address types associated with same routing schemas
in order to communicate with these schemas
?? this is an interesting point, should all nodes have the same schemas ??

To communicate between nodes, routing MAY use non-local address types.

Workers which handle non-local message communication between nores, are called "Transports"

Transport is a set of two (or more) workers on two (or more) different Nodes,
which act like a single worker from a routing point of view:

For example a message from a node A:
```
{onward_route: [transportA, receiver], return_route: [sender]}
```  

Should be received on a node B as if it was forwarded:
```
{onward_route: [receiver], return_route: [transportB, sender]}
```

While communication between transportA and transportB is up to the transport protocol.

For example for the TCP protocol it will send a TCP message with the payload containing encoded Ockam message


## Open questions/discussion points:

In the current definition a worker receives its OWN address as a FIRST element in the onward route.
Since a worker may have different own addresses, maybe we should make it a separate field?
Current implementations rely on own address to be the same in the router and the worker state, which is rosky

In the current definition payload is opaque data, while Rust implementation is using typed payloads,
we should decide whether it should be binary data, a standard type or it can be any type.

Address types are currently only fixed for the local addresses and identified with an integer, which might cause
issues when different routers use different IDs for address schemas.



## Examples

### Forwarding and replies

Let's assume worker `A` wants to send a message to a replying worker `C`
through and intermediate forwarding worker `B`

**Here be picture**

```
[(A) -> (B) -> (C)]
     1      2

[(A) <- (B) <- (C)]
     4      3
```

The messages would look like the following:
1:
```
{
  onward_route: B -> C,
  return_route: A
}
```

2:
```
{
  onward_route: C,
  return_route: B -> A
}
```

3:
```
{
  onward_route: B -> A,
  return_route: C
}
```

4:
```
{
  onward_route: A,
  return_route: B -> C
}
```


### Transports and nodes

Now let's take workers on different nodes, when worker `A1` on node `A`
wants to send a messge to a replying worker `C1` on node `C`:

**Here be picture**

```
[(A1) -> (TransportA)] -> [(TransportC) -> C1]
      1                2                3

[(A1) <- (TransportA)] <- [(TransportC) <- C1]
      6                5                4
```

The messages would look like:

1:
```
{
  onward_route: {type: TransportType, data: AddressOfC} -> C1
  return_route: A1
}
```

2:
this message is transport specific and is not defined by this protocol,
but it needs all the information to construct a message 3
let's imagine the following transport format:
```
or:C1,rr:A1,payload:...
```

3:
```
{
  onward_route: C1
  return_route: {type: TransportType, data: AddressOfA} -> A1
}
```

3:
```
{
  onward_route: {type: TransportType, data: AddressOfA} -> A1
  return_route: C1
}
```

5: same as for message 2

3:
```
{
  onward_route: A1
  return_route: {type: TransportType, data: AddressOfC} -> C1
}
```

### Session establishment

While workers can forward messages, they can also modify the routes in the forwarded messages arbitrarily.

This allows for creation of new workers and registration of new addresses while processing a message.

This can be used to establish transport connections, secure channels and other types of user sessions between two endpoints

Let's take a TCP transport as an example:

Worker `A1` on node `A` wants to establish communication with a worker `C1` on node `C` using the TCP connection.

It can send a message to the TCP client worker to connect to node `C` and establish connection to `C1`:

**Here be picture**

```
[(A1) -> (TCPClientA) -> (TCPClientConnectionA1)] -> [(TCPServerConnectionC1) -> (C1)]
      1               2                           3                           4                          
[(A1) <- (TCPClientConnectionA1)] <- [(TCPServerConnectionC1) <- (C1)]
      7                           6                           5
```

The TCP client would create a new TCP connection worker, TCP server (not a worker in this case) would create the server
worker. After that connection workers would act like a transport and will have some identity associated with them,
which identifies a session.

The messages look like the following:

1:
```
{
  onward_route: {type: #TCP, data: AddressOfC} -> C1
  return_route: A1
}
```

2:
```
{
  onward_route: TCPClientConnectionA1 -> C1
  return_route: A1
}
```

3:
this would be TCP transport specific

4:
```
{
  onward_route: C1
  return_route: TCPServerConnectionC1 -> A1
}
```

5:
```
{
  onward_route: TCPServerConnectionC1 -> A1
  return_route: C1
}
```

6:
transport specific

7:
```
{
  onward_route: A1
  return_route: TCPClientConnectionA1 -> C1
}
```

This way using the TCP conneciton identity `TCPClientConnectionA1` and `TCPServerConnectionC1`
these two workers have a communication session between them


### Complex server-side routing

As an example, let's assume a device is sending a message to a mobile phone.
The device does not know how to reach the phone and needs to run the message through some server.

Let's assume a device `Dev` is sending a message to the phone `Phone`

The device would know that it needs to communicate through the device server
and it needs to reach a phone.

It will send a message: 

1

```
{
  onward_route: DevServer -> Phone,
  return_route: Dev
}
```

The device server can then modify the onward route to route the message through some message broker
to a service, which can locate a specific device to send the message to.
It can also modify the return route to add the device identity to it:

2

```
{
  onward_route: Broker -> PhoneRegistry -> Phone
  return_route: DevServer -> Dev1
}
```

The phone registry can then communicate with the phone:

3

```
{
  onward_route: Phone1
  return_route: PhoneRegistry -> Broker -> DevServer -> Dev1
}

``` 

After that the phone would be able to send the message back to the device using
the established return route:

4

```
{
  onward_route: PhoneRegistry -> Broker -> DevServer -> Dev1
  return_route: Phone1
}

``` 

**Here be picture**

```
[(Dev1)] -> [(DevServer)] -> [(Broker)] -> [(PhoneRegistry)] -> [(Phone1)]
         1                2                                  3

[(Dev1)] <- [(DevServer)] <- [(Broker)] <- [(PhoneRegistry)] <- [(Phone1)]
                                                             4
```