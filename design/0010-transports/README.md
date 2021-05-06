# Ockam Transports

The Ockam framework allows the creation of distributed systems,
comprised of Nodes, that are connected to each other via a variety of
transport channels.

This proposal aims to specify and document what these transports are,
how they should behave, and what an external transport implemntation
must do to interoperate with existing tools.


## Fundamentals

An Ockam system can be expressed as an undirected graph, defined as an
ordered pair `G = (V, E)`, where `V` is a set of nodes (or Vertices),
and `E` is a set of transports (or Edges).  Any one transport `e ∈ E`
in this graph is unique, and specific for a particular *transport
channel* implementation.  A *transport channel* is any hardware medium
that allows the sending of messages.

Routing a message through this grapih from node `A` to node `C`, via a
middle node `B` uses the transports `e_AB`, and then `e_BC`.


## Address schema

Before being able to define the internals of how a transport
implementation works, we need to define the schema of Ockam addresses.

An address is a 2-tuple with an address type, and an arbitrary length
address field.  The schema can be expressed as follows.

```
Address {
  type: u8,
  data: Vec<u8>,
}
```

Address type ranges are broken down as follows.

- `0 - 15` -- Ockam internal reserved block
- `16 - 63` -- Partner add-on reserved block
- `64 - 255` -- User defined range

A third-party transport implementation MUST NOT use an address type
from the Ockam internal reserved block (`00000000` to `00001111`).

A third-party transport implementanion MAY use an address type from
the Partner add-on reserved block (`00010000` to `00111111`), given it
has followed the [following procedure]() (todo!).

The remaining range (`01000000` to `11111111`) can be freely used by
users with no additional communication with stakeholders in the Ockam
system.  No guarantees can be made for the inter-operability of
transports that use address types in this range.


## Anatomy of a transport implementation

A transport implementation is specific for a *transport channel* and
*address type*.  A transport implementation consists of several
components, which are broken down into their rational and specifics
below.

- A transport specific address identifier constant
- An address specific parser and generator for addresses
- A transport specific router implementation
- Transport specific connection worker implementations

The basic Ockam architecture allows the swapping of Node
implementations, according to the platform it is running on.  Because
of this a transport implementation MAY be specific to a node
implementation, if it is otherwise impossible to use.

**Example**

The `ockam_transport_tcp` crate heavily relies on the `tokio-rs`
runtime, which does not support a `no_std` environment.  Therefore,
`ockam_transport_tcp` can not be used with `ockam_node_no_std`.  This
is allowed under the transport specification.


### Address identifier constant

In order to allow users to create addresses specific to the transport
easily, a transport implementation MUST provide an address type
identifier in the root of its primary crate.  This allows users to use
the transport address types without being aware what ID they were
assigned.

**Example**

```rust
use ockam::Route;
use ockam_transport_tcp::TCP;

Route::new().append_t(TCP, "127.0.0.1:8080")
```


### Address specific parser & generator

A transport implementation MAY provide additional parsers & generators
for address schemas.  By default, the `ockam_core` crate provides
functionality to parse strings into address types, by converting UTF-8
strings to byte arrays.

**However**, address data MAY contain structured data, according to an
external scema.  If this functionality is required for a transport
address schema, it SHOULD provide better utilities to facilitate this
transformation.

**Example**

```rust
use serde::{Deserialize, Serialize};
use ockam_core::Address;

#[derive(Deserialize, Serialize)]
struct ComplexAddressType {
    a: String,
    b: usize,
    c: bool,
}

pub fn address<S: Into<String>(a: S, b: usize, c: bool) -> Address {
    // ...
}
```


### Transport router implementation

Every transport implementation MUST provide a router implementation.
A router is a special worker, which accepts the
`ockam_core::RouterMessage` message type, and registers itself with an
Ockam node via the context `register(...)` mechanism.

A router implementation MUST handle all events encoded in the
`RouterMessage` schema.  At this time, this includes the following
variants.

- Register -- allowing connection workers to register themselves
- Route -- Forwarding an incoming message to a connection worker

During the initialisation of the router worker it MUST call `register`
on the containing Ockam node.

During operation, a `Register` call MUST mutate the router state to
map a transport specific address type to a local worker address
(corresponding to the newly created connection worker).

During operation, a `Route` call MUST NOT mutate the router state, but
instead mutate the incoming message route to be forwarded.


**Example**

```rust
use ockam::{Context, RouterMessage, Worker};

struct MyRouter {
    /// Map Address type X to address type 0
    map: BTreeMap<Address, Address>
}

#[ockam::worker]
impl Worker for MyRouter {
    type Context = Context;
    type Message = RouterMessage;
    
    // ...
}
```

(todo: `unregister` message call!)


### Transport connection workers

Every transport implementation MUST provide connection worker
implementations.  It is recommended to use a split-worker design, with
one worker implementation handling incoming, and one implementation
handling outgoing traffic.

A transport provides bi-directional communication between two
neighbouring nodes, and thus a transport worker MUST be specific to a
peer.  Because of this fundamental assumption a connection worker
SHOULD NOT track further route, or graph layout information.


## Interactions between transport components

todo
