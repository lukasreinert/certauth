# CertAuth
Generate your own certificate authority based on [NSA Suite B](https://de.wikipedia.org/wiki/NSA_Suite_B_Cryptography) PKI requirements.

## Features
* 3-Tier CA Hierarchy
* Support for CRL
  * including automated daily updates with the option to also copy it into a published folder
* Support for OSCP
  * Only in certificates, not further implemented


## Installation
For security reasons I recommend to clone the scripts into a secured environment where idealy only you have access to. If you plan to publish the CRLs (certificate revocation list) or OSCP (online certificate status protocol) I highly recommend to create an own server for this. However, it's up to you to find a secure way of deploying your CA.


## Usage
The script is meant to be somewhat interactive, so it gives you feedback on the current step and what it wants from you. For these purposes I also mostly included example inputs to which empty inputs will also fallback.


## The idea behind
I wanted to create own certificates for some local web applications but didn't want to always import them so by browser knows that it can trust those pages. Additionally I wanted to learn more about how a certificate authority can be built and that was the point I started to build my own. Of course, everything must be automated and here it is: An automated way to build you own CertAuth.


## Resources
The knowledge for CertAuth mostly comes from [this blog series](https://community.f5.com/kb/technicalarticles/building-an-openssl-certificate-authority---creating-your-root-certificate/279520) in which every step is explained in more detail. However, they only provide the needed commands and some background knowledge. For the automation I use sed for find & replace to generate configs for all the CAs. Anything else is a ragout of what I've learned so far about bash.
