```yaml
id: OP-0007
title: Credentials Protocol
status: Draft
```

# Credentials Protocol

The credentials protocol enables parties to enhance trust between themselves. This document describes what can be derived from this protocol.

Credentials are presented from one party to another according to a required manifest in which case a relying party is either convinced to the truthfulness of the statements in the credential or not.

## Description

A **presentation manifest** is a set of rules and data that the Prover must submit for the Verifier for identification and authentication. It’s a data structure that must contain the following information: what credentials are acceptable, who is allowed to have issued those credentials, what claims must be sent from the credentials, and what is the proving system.

The presentation manifest may include rules like “any ocean sensor credential signed from issuers A, B, or C is acceptable.” In this case, the device needs to indicate by which issuer her credential was signed.

**Attributes** are information that has been digitally signed in a credential. The layout and definition of what attributes are in a credential is known as a schema.

**Credentials** are documents of data held by a *prover*, cryptographically signed and attested to be correct by an *issuer*, that can be presented and checked by another party the *verfier*.

**Proof** is the information (attributes--self attested or issuer attested) and cryptographic material used for identification and authentication. Any metadata about the proof like which issuer signed the credential, or other decisions the device followed to generate the proof is known as the **resolution**.

There are two protocols used with credentials: proving and issuing.

Proving happens when one party expects identification and authentication to be performed by the other according to a specific presetnation manifest.
The flow follows Figure 1 where dotted lines are optional, and solid lines are required.

![Figure1](proving.png)
Figure 1.

A device can request the presentation manifest from the verifier similar to requesting to sign in to a system. The verifier sends the presentation manifest to the device in order for the device to know what and how to identify and authenticate itself. The manifest could come pre installed which makes the first two interactions not necessary.

The last piece of information necessary for a credential to be validated is what cryptographic system was used to create the credential.

The simplest method to sign the credential is a digital signature which produces a single signature over all the claims. X.509 certificates are an example of this.

How devices obtain a credential is described in the Issuing protocol. Issuing is when one party receives a credential for identification and authentication. The flow follows Figure 2 where dotted lines are optional, and solid lines are required.

![issuing](issuing.png)
Figure 2

Issuance usually involves vetting the party receiving the credential such as physically connecting the device and manually clicking menus or agreeing to a EULA, or bringing the device in person to the issuing authority. The proving protocol could be used for this as well using other credentials the device already has.

The issuing authority might be the manufacturer in which case the device is just given the credential when it's created. Thus the first three steps are not always necessary. 

The issuer must decide what credential schema to use for credentials and what cryptographic proving system is used to validate the credential.

The issuer must decide the rules which define what process is needed in order to receive a credential.

The issuer must decide if the credential is revocable, expires, or both. If so, how is this demonstrated to verifiers in a trustworthy method? If it expires, for how long is the credential valid? What does revocation mean? Was the device compromised, malfunctioning, or was the credential data just incorrect?

## Reference

