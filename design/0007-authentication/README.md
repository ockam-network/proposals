```yaml
id: OP-0007
title: Authentication Protocols
status: Draft
```

# Authentication Protocol

This proposal specifies the many possible authentication methods that can be used
to establish trust after a secure channel has been established. Channels by themselves
do not establish trust between parties. Trust is built from vetting processes,
attestations by familiar parties, and cryptographic means. Each offers pros and cons
and is left up to the entities and systems to decide what works for them. Authentication
can be performed once, in periodic intervals, or continuously.


## Description

The idea behind authentication is to build trust between parties. Authentication establishes
a party's identity i.e. who they are. When a channel is first created, there is zero trust in between the
communicating parties but also limited value. As value between parties increases, trust should
also by revealing more information about the identity. For example, a device may only initially 
send its manufacturer name to a collections database and what type of data it collects like water temperature.
A unique device ID or location could lead to potential privacy violations or security implications
and should only be shared once the device (or the device owner) has a higher level of assurance that
the database is secure enough and won't reveal that information to those not in confidence.

The database owner may provide a credential that certifies this higher level of assurance thereby
increasing the level of trust for the device. The device can then provide location data if desired
which allows the database to further trust its data since the location is now known. However, the
database cannot just accept the location data from the device unless another party attests that
credential that is also trusted by both parties.

### Setup

Each entity establishes a set of rules that indicate trust. Rules must describe:

1. What are the levels of trust, e.g. None, Low, Acceptable, Exceeds
1. What information is required to meet the levels of trust, e.g.
location, manufacturer, hardware enclaves, cryptographic primitives
1. Who are the acceptable parties such that if a signed credential by them is presented, it is trustworthy.
1. The epoch of how fresh the credential and information must be e.g. within the past year, one hour, five minutes.

The rules describe the who, what, when, how for authentication.

Information can either be self-attested or by another. Sensor data is as example of self-attested information.
The device hardware information is an example of information provided in a verifiable credential.

There are three non-mutually exclusive roles for authentication: *issuer*, *holder*, and *verifier*.

Issuers make claims about a *holder* by cryptographically signing information in a credential. A *holder*
uses the credential to prove to a *verifier* information about itself. The *verifier* must be able to trust
the *issuer* in order to trust the information presented in the credential.

How trust is established in the issuers is similar to how it is with a holder. This begs the question,
how is the root of trust established i.e. how is trust established in the first issuers if there are none?

The answer lies with the framework or system. 


## Definition

### Protocol

# Threat Model

## Reference

