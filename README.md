# Beranames Name Service (BNS)

Beranames Name Service (BNS) is a decentralized and secure naming service built on the Berachain blockchain 🐻⛓.

This project is a fork of the Ethereum Name Service (ENS) protocol, designed to provide decentralized domain name registration and resolution on the 🐻⛓ blockchain. By leveraging the robust architecture of ENS, this fork introduces customized functionalities while maintaining compatibility with existing ENS standards.

## Specifications

The BNS system comprises three main parts:

- The BNS registry
- Resolvers
- Registrars

The registry is a single contract that provides a mapping from any registered name to the resolver responsible for it, and permits the owner of a name to set the resolver address, and to create subdomains, potentially with different owners to the parent domain.

Resolvers are responsible for performing resource lookups for a name.

Registrars are responsible for allocating domain names to users of the system, and are the only entities capable of updating the BNS Registry.

## Registering a name

You can easily register a name using the [Beranames Service Portal](https://beranames.com/).

## Integrating BNS into your project

### Forward Resolution

You can integrate BNS into your project by following this two step resolution process:

1. **Find the resolver**: Every resolution process starts by querying the BNS registry to get the resolver address for the name.

```solidity
   BNS.resolver(bytes32 node) view returns (address)
```

where `node` is the [**namehash**](https://eips.ethereum.org/EIPS/eip-137#namehash-algorithm) (as specified in EIP 137#namehash-algorithm) of the domain name.

2. **Query the resolver**: Use the resolver to lookup the resource records associated with the name.

```solidity
   resolver.addr(bytes32 node) view returns (address)
```

#### Universal Resolver

As you have seen above, the resolver is the one responsible for resolving the domain name to the desired data.
The resolution though is a two step process, and as such, you can use the [**universal resolver**](https://docs.ens.domains/resolvers/universal#forward-resolution) to resolve the domain name to its address in a single rpc call. This is also the way most of the client libraries expect that a resolution should be done.

```solidity
   universalResolver.resolve(bytes calldata name, bytes calldata data) external view returns (bytes)
```

where:

- `name` is the dnsEncoded name to resolve.
- `data` is the ABI-encoded call data for the resolution function required - for example, the ABI encoding of `addr(namehash(name))` when resolving the `addr` record.

### Reverse Resolution

Reverse resolution is the process of resolving an address to a domain name. [EIP-181](https://eips.ethereum.org/EIPS/eip-181) specifies a TLD, registrar, and resolver interface for reverse resolution.

> Reverse BNS records are stored in the BNS hierarchy in the same fashion as regular records, under a reserved domain, `addr.reverse`. To generate the BNS name for a given account’s reverse records, convert the account to hexadecimal representation in lower-case, and append `addr.reverse`. For instance, the BNS registry’s address at `0x112234455c3a32fd11230c42e7bccd4a84e02010` has any reverse records stored at `112234455c3a32fd11230c42e7bccd4a84e02010.addr.reverse`.

#### Reverse Registrar

The owner of the `addr.reverse` domain is the reverse registrar that permits the caller to take ownership of the reverse record for their own address.
In order to take ownership of the reverse record for their own address, the caller can call the `claim` function of the reverse registrar with the desired name.

```solidity
   reverseRegistrar.claim(address owner) public returns (bytes32 node)
```

where `owner` is the address to claim the reverse record for.

Or the caller can claim the reverse record for any address by directly calling the `SetName` function of the reverse registrar.

```solidity
   reverseRegistrar.setName(string name) public returns (bytes32 node)
```

When called by account `x`, sets the resolver for the name `hex(x) + '.addr.reverse'` to a default resolver, and sets the name record on that name to the specified name. This method facilitates setting up simple reverse records for users in a single transaction.

#### Reverse Resolving

Once the reverse record is claimed, the caller can use the resolver to lookup the name associated with the address.

```solidity
   resolver.name(bytes32 node) view returns (string)
```

where `node` is the reverse record node obtained from the reverse registrar calling:

```solidity
   reverseRegistrar.node(address owner) view returns (bytes32)
```

### Universal Resolver

> TODO: Add universal resolver methods for reverse resolution.
