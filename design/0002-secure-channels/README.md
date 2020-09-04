```yaml
id: OP-0002
title: Secure Channels
status: Draft
```

# Secure Channels

This document specifies a protocol for two entities to establish and use
secure communication channels that prevents eavesdropping, tampering, and
forgery of messages en-route.

We assume that any message in this protocol could take a complex route that
may involve multiple transport connections which, in turn, may use various
transport protocols.

We also assume that the two communicating machines may not be online at the
same time and messages may be cached along the route and delivered at a
later time.

A channel is responsible for handling the following:

- Key management via [key agreement](../0003-key-agreement-xx) and subsequent key updates
- Encryption
- Decryption
- Passing encrypted data to a route(s)
- Decrypting incoming data from a route(s)

## Description

The first time a channel is created, it starts with new keys.

A channel uses an acceptable [key agreement](../0003-key-agreement-xx) to secure the connection.

A channel contains the following data output from a key agreement:

1. Local secret and public identity keys
2. Remote public identity key
3. Encryption/Decryption keys
4. Running hash of all messages and key's exchanged

A channel consists of these protocols: data protection like AEAD-AES-128-GCM or AEAD-X20-P1305 and the running hashing algorithm like BLAKE2s or SHA3-256, 
rekey frequency like EveryMessage, EveryXXMessages, Never (Testing purposes only) for the purpose of avoiding nonce reuse, reestablishment that 
changes the identity keys such as Annually, Monthly, EveryXXDays, and finally a reader and writer from which data is written after encryption an decrypted after a read.

To avoid configuration agility, channel creators can use prebuilt options that suite their needs. Each one
offers trade offs between how often encryption keys are changed, how often the identity keys are changed,
how it handles out of order messaging.

Channel's are named according to what options they contain. 

This proposal has the following recommended channel setups:

    
1. **Ephemeral channel** runs [key agreement](../0003-key-agreement-xx) everytime it is created. All keys and hashes are forgotten
when the channel is closed.
2. **Standard channel** runs [key agreement](../0003-key-agreement-xx) after a fixed amount of messages have been received to avoid
nonce reuse.

## Structure

```rust
use kex::KeyExchange;
use std::io;
use vault::{Vault, SecretKeyContext};

#[derive(Clone, Copy, Debug)]
pub enum RekeyMethod {
    EveryMessage,
    MaxMessageCount,    
    AtMessageCount(u16)
}

#[derive(Clone, Copy, Debug)]
pub enum Cipher {
    Aes128Gcm,
    Aes256Gcm,
    XChaCha20Poly1305,
}

#[derive(Clone, Copy, Debug)]
pub enum Hasher {
    Sha2,
    Sha3,  
    Blake2b,
}

pub trait Channel {
    fn encrypt<I: io::Read, W: io::Write>(input: I, output: W) -> Result<(), io::Error>;
    fn decrypt<I: io::Read, W: io::Write>(input: I, output: W) -> Result<(), io::Error>;
    fn key_exchange<I: io::Read, W: io::Write>(input: I, output: W) -> Result<(), Error>;
    fn close();
}

#[derive(Debug)]
pub struct ChannelState {
    encrypt_key: SecretKeyContext,
    decrypt_key: SecretKeyContext,
    state_hash: [u8; 32],
    vault: dyn Vault,
    cipher: Cipher,
    hash: Hasher,
    rekey: RekeyMethod,
    kex: KeyExchange,
}
```

## Discussion

We’re discussing the Ockam secure channels protocol in the following Github issues: [#33](https://github.com/ockam-network/proposals/issues/33)

## References

1. <span id="reference-1"></span>Canetti, R. and Krawczyk, H.,
Analysis of Key-Exchange Protocols and Their Use for Building Secure Channels. <br/>
https://ia.cr/2001/040
