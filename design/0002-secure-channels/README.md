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

## Description

Channels encapsulate the following sub protocols:

1. Key agreement - establishes the cryptographic keys used for bootstrapping communication 
1. Key rotation - determines how often keys are changed and retired
1. Data protection - what algorithms are used to protect data confidentiality and integrity

Channels have two basic operations: send and receive. *Send* protects the message using the current cryptographic keys and data protection rules. *Receive* securely validates and unpacks a message. Once a message has been handled, the channel forwards the message to a specified router component.

### Key agreement

Channels can use any supported key agreement method. Key agreements authenticate the communicating parties and establish the initial encryption keys. Both parties must use the same key agreement methods otherwise the channel cannot be established.

### Key rotation

Key rotation rules determine the lifecycle of the keys: how long is the key used and how is it changed? For example, the rules may specify the key should be changed every 8000 messages, with every message, every day, etc. The rules can specify to retain previous keys in case of out of order message arrival for a certain period of time. The rules specify how the next key is determined so the channel can continue to operate after a key rotation event. One method that [Signal][dratchet] uses is to send the next public key with each message and change the key every time. Another could be to use the current session state and key and derive the next key when a condition is met.

### Data protection

Data protection specifies how the messages are encrypted and decrypted. Channels use Authenticated Encryption with Addtional Data (AEAD) schemes which encrypt the messages to ciphertexts and also verify the ciphertext and not been changed. Decryption will fail if any changes have occurred such as from tampering or corruption. Channels currently support AES-128-GCM and AES-256-GCM which are both compliant with [NIST][nistgcm].

## References

1. <span id="reference-1"></span>Canetti, R. and Krawczyk, H.,
Analysis of Key-Exchange Protocols and Their Use for Building Secure Channels. <br/>
https://ia.cr/2001/040
1. <span id="reference-2"></span>Perrin, T. and Marlinspike, M. [The Double Ratchet Algorithm][dratchet]
1. <span id="reference-3"></span>NIST, [Recommendation for Block Cipher Modes of Operation: Galios/Counter Mode (GCM) and GMAC][nistgcm]

[//]: # (reference links)

[dratchet]: https://signal.org/docs/specifications/doubleratchet/doubleratchet.pdf
[nistgcm]: https://csrc.nist.gov/publications/detail/sp/800-38d/final
