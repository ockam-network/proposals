```yaml
id: OP-0006
title: Enrollment Protocol
status: Draft
```

# Enrollment Protocol Overview

This proposal specifies an __enrollment protocol__ with varios entities functioning
as an enrollment service, another functioning as an enroller, and lastly an
enrollee. The enroller's purpose is to provide information to an enrollee about an
enrollment service such that the enrollee establishes secure communications with an
enrollment service without sending any unencrypted information. The enroller also
provides information to the enrollment service such that it can identify a valid enrollment request
from an enrollee and can safely ignore all others.

This protocol makes use of Signal's [X3DH](https://signal.org/docs/specifications/x3dh/)
to provide mutual authentication, forward secrecy, and deniability.


## Description

There are 3 entities in this protocol: an enrollment service, an enroller,
and enrollee. The service provides any enrolled entity with some functionality.
The enroller is a system or device under control of an onboarder that is used to authorize other devices to the service.
The enrollee is any system or device that wants to use the benefits provided by the service.

### Setup

The setup assumes a secure channel exists between the enroller and the service
established using another method like [XX Key agreement](../0003-key-agreement-xx).

To become an enroller, the service generates an enrollment bundle which consists
of three cryptographic keys:

1. Service's identity key *IK<sub>A</sub>*
1. Service's signed prekey *SPK<sub>A</sub>*
1. Service's one-time prekey *OPK<sub>A</sub>*

The bundle also contains an Ockam address *Addr* which an enrollee uses to contact the service.

## Definition

The process uses the following parameters:

| **Name** | **Definition** |
| ---------| --------------- |
| *curve* | X25519 |
| *hash* | A 256 bit hash function (e.g. SHA-256 or SHA3-256) |
| *info* | An ASCII string with the protocol name |
| *KDF* | HKDF with 32 0xFF bytes prepended to *IKM*, with *info* parameter and *salt* is 32 0x00 bytes |
| *HMAC* | HMAC-SHA256 |
| *XEdDSA* | [XEdDSA](https://signal.org/docs/specifications/xeddsa/) signature |
| *AEAD* | Authenticated encryption scheme like AES-256-GCM |
| \|\| | Concatenation of byte sequences |

### Protocol

The enroller is usually controlled by the same party as the enrollee. For example, a new robot (enrollee)
is installed in a factory and the enroller is a computer terminal (enroller).

When a new enrollee comes online, it establishes a secure channel with an enroller with [XX Key agreement](../0003-key-agreement-xx).
The enroller indicates to the enrollee to use the service by sending an enrollment bundle.

At this point the enroller doesn't need to do anything else.

### Enrollee 

The enrollee generates a one-time use keypair *EIK<sub>B</sub>*. 
The enrollee then calculates the X3DH key agreement as follows:

- DH1 = DH(EIK<sub>B</sub>, SPK<sub>A</sub>)
- DH2 = DH(EIK<sub>B</sub>, IK<sub>A</sub>)
- DH3 = DH(EIK<sub>B</sub>, OPK<sub>A</sub>)
- SK = KDF(DH1 || DH2 || DH3)

*DH1* and *DH2* provide mutual authentication. *DH3* provides forward secrecy.
After calculating *SK*, the enrollee deletes the private key for EIK<sub>B</sub> and DH outputs.

The enrollee calculates the state hash **h** = hash(*info* || [0xFF; 32] || DH1 || DH2 || DH3)

The enrollee then generates a keypair *IK<sub>B</sub>*. This key becomes the identity key for the enrollee.

The enrollee sends a message to the service to indicate enrollment that includes the following:

**Header**

- An ephemeral public key *EIK<sub>B</sub>*

**Body**
Body is encrypted with the calculated *SK* from X3DH, the AAD is the value of **Header** || *info* || *Addr* || state hash **h**

- IK<sub>B</sub>
- XEdDSA(IK<sub>B</sub>, EIK<sub>B</sub>)

EIK<sub>B</sub> serves as the nonce (or the first N bytes depending on the encryption IV size) and Hash(EIK<sub>B</sub>) serves as the message id. This provides integrity protection for EIK<sub>B</sub>

The message is sent to the service.

### Service

The service receives the message, derives SK the same way as the enrollee and performs the following checks:

1. Has it seen EIK<sub>B</sub>? If so, then reject the message.
1. Computes the same shared secret to decrypt the message using the corresponding secret keys for SPK<sub>A</sub>, IK<sub>A</sub>, OPK<sub>A</sub>. If decryption fails then reject the message.
1. Verifies XEdDSA(IK<sub>B</sub>, EIK<sub>B</sub>). If it fails the reject the message.

IK<sub>B</sub> is stored by the service because it serves as the long term identity key of the enrollee.

The service can continue to use SK to communicate with the enrollee until SK is rotated.

# Threat Model

The following are the various parts of the threat model:

- Protecting against external threats by using to standard cryptography to provide confidentiality, integrity, accountability, authentication 
- Protecting against passive attackers that may be listening to network traffic and active attackers tampering with network traffic by using AES-GCM
- Protecting against replay enrollments by using nonces and ephemeral keys


The following are not parts of the Vault threat model:

- Protecting against a malicious enroller that changes or alters the service's prekey bundle or the identity key of the enrollee.
- Protecting keys on the enrollee, enroller, and service more than the guarantees provided by the Vault. 
- Protecting against memory fault attacks
- Protecting against physical side channel attacks like voltage differential attacks.

## Reference

1. <span id="reference-3"></span>Marlinspike, M. and Perrin, T.,
The X3DH Key Agreement Protocol. <br/>
https://signal.org/docs/specifications/x3dh/x3dh.pdf

