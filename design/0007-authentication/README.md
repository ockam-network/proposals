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

The answer lies with the trust domain or system. These can be defined through standards or groups. HIPAA, PCI are standards that define how trust can be established for an entity that works in health records and credit cards.

The FDA regulates prescription drugs and provides the GS1 validation scheme for establishing trust in drug pedigree.

In the space of IoT, this is largely defined on where and howthe devices themselves will be used.

## Prior Art

Authentication centers around correctly identifying parties. Here we discuss the existing methods of identification and authentication.

### One off identity and trust

### PKI

### Federated identity and Single-Sign-On

### Self Sovereign Identity

## Definition

### Protocol

# Threat Model

## Reference

[Handshake.org](https://handshake.org/)
[Namecoin](https://www.namecoin.org/)
[Secure Scuttlebutt](https://scuttlebutt.nz/docs/)
[OWASP Top 10 Broken Authentication](https://owasp.org/www-project-top-ten/2017/A2_2017-Broken_Authentication)
[Forgot Password](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)
[NIST 800-63b](https://pages.nist.gov/800-63-3/sp800-63b.html#memsecret)
[Microsoft Windows Defender Credential Guard](https://docs.microsoft.com/en-us/windows/security/identity-protection/credential-guard/credential-guard-manage)
[OpenID Connect](https://openid.net/connect/)
[Federated Identity and Single SignOn](https://www.okta.com/identity-101/federated-identity-vs-sso/)
[SAML](http://docs.oasis-open.org/security/saml/Post2.0/sstc-saml-tech-overview-2.0.html)
[SAML Bypass Vulnerability](https://security.paloaltonetworks.com/CVE-2020-2021)
[OAuth](https://oauth.net/2/)
[Decentralized Identifiers](https://www.w3.org/TR/did-core/)
[Verifiable Credentials Data Model](https://www.w3.org/TR/vc-data-model/)
[DEP](https://docs.microsoft.com/en-us/windows/win32/memory/data-execution-prevention)
[ASLR](https://searchsecurity.techtarget.com/definition/address-space-layout-randomization-ASLR)
[Speculative Probing: Hacking Blind in the Spectre Era](https://download.vusec.net/papers/blindside_ccs20.pdf)
