```yaml
id: OP-0006
title: Enrollment Key Agreement
status: Draft
```

# Enrollment Key Agreement

This proposal specifies a __key agreement protocol__ for an entity functioning
as an enrollment service, another functioning as an enroller, and lastly an
enrollee. The enroller's role is to provide information to an enrollee about the
enrollment service such that the enrollee can compute an encryption key
and communicate with an enrollment service without sending any information
in the clear. The enroller also provides information to the enrollment service
such that it knows a valid enrollment request from an enrollee and can safely
ignore all others.

This protocol makes use of Signal's [X3DH](https://signal.org/docs/specifications/x3dh/)
to provide mutual authentication, forward secrecy, and deniability.


## Description

There are 3 entities in this protocol: an enrollment service, an enroller,
and enrollee. The service provides any enrolled entity with some functionality
that will be consumed. The enroller is a system or device under control of
an onboarder that is used to authorize other devices to the service.
The enrollee is any system or device that wants to consume the benefits provided
by the service.

### Setup

The setup assumes a secure channel exists between the enroller and the service
established using another method like [Noise XX Key agreement](../0003-key-agreement-xx).

To become an enroller, the service generates an enrollment bundle which consists
of three cryptographic keys:

1. Service's identity key *IK<sub>A</sub>*
1. Service's signed prekey *SPK<sub>A</sub>*
1. Service's one-time prekey *OPK<sub>A</sub>*

The bundle also contains an Ockam address *Addr* an enrollee uses to indicate a new enrollment.

## Definition

The process uses the following parameters:


| **Name** | **Definition** |
| ---------| --------------- |
| *curve* | X25519 |
| *hash* | A 256 bit hash function (e.g. SHA-256 or SHA3-256) |
| *info* | An ASCII string with the protocol name |
| *KDF* | HKDF with 32 0xFF bytes prepended to *IKM*, with *info* parameter and *salt* is 32 0x00 bytes |
| *HMAC* | HMAC-SHA256 |
| *XEdDSA | [XEdDSA](https://signal.org/docs/specifications/xeddsa/) signature |
| *AEAD* | Authenticated encryption scheme like AES-256-GCM |
| \|\| | Concatenation of byte sequences |

### Protocol

The enroller is usually controlled by the same party as the enrollee. For example, a new robot (enrollee)
is installed in a factory and the enroller is a computer terminal (enroller).

When a new enrollee comes online, it establishes a secure channel with an enroller.
The enroller indicates to the enrollee to use the service by sending an enrollment bundle.

### Enrollee 

The enrollee then sends a public key *EIK<sub>B</sub>* to the enroller. The enroller forwards
this key to the service to indicate this enrollee is allowed to enroll and blessed by this enroller.

At this point the enroller ceases to be a part of the communication.

The enrollee calculates the X3DH key agreement as follows:

- DH1 = DH(EIK<sub>B</sub>, SPK<sub>A</sub>)
- DH2 = DH(EK<sub>B</sub>, IK<sub>A</sub>)
- DH3 = DH(EK<sub>B</sub>, SPK<sub>A</sub>)
- DH4 = DH(EK<sub>B</sub>, OPK<sub>A</sub>)
- SK = KDF(DH1 || DH2 || DH3 || DH4)

*DH1* and *DH2* provide mutual authentication. *DH3* and *DH4* provide forward secrecy.
After calculating *SK*, the enrollee deletes the private key for EK<sub>B</sub> and DH outputs.

The enrollee then generates a keypair *IK<sub>B</sub>*. This key becomes the identity key for the enrollee.

The enrollee sends a message to the service to indicate enrollment that includes the following:

**Header**

- An ephemeral public key *EK<sub>B</sub>*
- Hash(EIK<sub>B</sub>)

**Body**
Body is encrypted with the calculated *SK* from X3DH, the AD is the value of **Header** || *info* || *Addr*

- IK<sub>B</sub>
- XEdDSA(IK<sub>B</sub>, EIK<sub>B</sub>)

EK<sub>B</sub> serves as the nonce (or the first N bytes depending on the encryption IV size) and Hash(EIK<sub>B</sub>) serves as the message id.

The message is sent to the service.

### Service

The service receives the message, derives SK the same way as the enrollee and performs the following checks:

1. Has it seen EK<sub>B</sub>? If so, then reject the message.
1. Does it have an expected enrollee id = Hash(EIK<sub>B</sub>)? If not, then reject the message.
    1. It can check this quickly by keeping a hash table of received EIK's from pending enrollees.
1. Computes the same shared secret to decrypt the message. If decryption fails then reject the message.
1. Verifies XEdDSA(IK<sub>B</sub>, EIK<sub>B</sub>). If it fails the reject the message.

If all checks pass, the service deletes EIK<sub>B</sub> and replaces it with IK<sub>B</sub>.
This serves as the long term identity key of the enrollee.

The service can continue to use SK to communicate with the enrollee until SK is rotated.

The internal state hash for subsequent noise channels **h** = HMAC(SK, *info*)

## Reference

1. <span id="reference-3"></span>Marlinspike, M. and Perrin, T.,
The X3DH Key Agreement Protocol. <br/>
https://signal.org/docs/specifications/x3dh/x3dh.pdf
