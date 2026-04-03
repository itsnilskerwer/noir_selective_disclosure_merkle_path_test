Work in progress. Not production-ready.

Noir prototype for selective disclosure over a signed Poseidon Merkle commitment.

# Testing selective disclosure for RDF datasets

This repository implements a Zero-Knowledge (ZK) circuit in Noir that enables the selective disclosure of specific Resource Description Framework (RDF) terms from a signed dataset. This directory is the Merkle-path variant of `noir_selective_disclosure_test`. Instead of proving over an entire private dataset inside the circuit, the prover supplies only the private 5-term tuple that justifies each disclosure, together with a Merkle authentication path into a signed root.

## What the circuit proves today

The circuit in `src/main.nr` is currently fixed to:

- `K = 3` disclosed term hashes
- tuple width `5`
- `TREE_DEPTH = 2`, so Merkle witnesses target a fixed ordered binary tree with 4 leaf positions

Public inputs:

- `pub_key_x: [u8; 32]`
- `pub_key_y: [u8; 32]`
- `disclosed_terms: [Field; 3]`
- `disclosed_position_indices: [Field; 3]`

Private witness inputs:

- `root: Field`
- `signature: [u8; 64]`
- `relevant_private_terms: [[Field; 5]; 3]`
- `merkle_paths: [[Field; 2]; 3]`
- `merkle_indices: [Field; 3]`

For each disclosed term `k`, the proof establishes:

1. the issuer public key verifies a secp256k1 ECDSA signature over `root.to_be_bytes()`
2. `disclosed_terms[k]` equals `relevant_private_terms[k][disclosed_position_indices[k]]`
3. hashing `relevant_private_terms[k]` with Poseidon-5 and walking `merkle_paths[k]` at `merkle_indices[k]` recomputes the same private `root`

In practical terms, the verifier learns that each disclosed term hash appears at the claimed position inside some tuple belonging to an issuer-signed Merkle commitment.

## Findings

- the leaf index is private, so the verifier does not learn which row of the 4-leaf commitment contained the disclosed term
- the full dataset is not supplied to the circuit
- different disclosures may reuse the same private tuple and Merkle path, or come from different leaves; that linkage is not public

The sample witness in `Prover.toml` demonstrates this:

- disclosures `0` and `1` reuse the same private tuple and the same private Merkle index `0`
- disclosure `2` uses a different private tuple at private Merkle index `1`
- the public position indices are `[0, 1, 1]`, meaning subject for the first disclosure and predicate for the second and third

## Merkle witness format

The witness format matters when preparing `Prover.toml`:

- each leaf is `Poseidon5([subject, predicate, object_value, object_suffix, graph])`
- `merkle_paths[k][0]` is the sibling at the leaf level
- `merkle_paths[k][1]` is the sibling at the next level toward the root
- `merkle_indices[k]` is interpreted with `to_le_bits()`, so the path logic uses little-endian index bits

For this depth-2 circuit, the Merkle commitment is an ordered 4-leaf tree. If witness generation uses a different leaf ordering, path level ordering, or index-bit convention, verification will fail.

## Public input ordering

Barretenberg flattens the public inputs in a fixed order. In `target/proof/public_inputs_fields.json`, the current circuit emits:

1. the 32 byte elements of `pub_key_x`
2. the 32 byte elements of `pub_key_y`
3. the 3 field elements of `disclosed_terms`
4. the 3 field elements of `disclosed_position_indices`

That is the full public statement. The following values remain private and do not appear in the verifier input file:

- `root`
- `signature`
- `relevant_private_terms`
- `merkle_paths`
- `merkle_indices`

As a result, reordering `disclosed_terms` or `disclosed_position_indices` changes the statement being proved. The verifier still learns disclosure order and term position within the matching tuple, even though the Merkle leaf index stays hidden.

## Expected preprocessing

This circuit assumes preprocessing happens outside Noir:

1. canonicalize and sort the RDF-derived data externally
2. encode each RDF term as a `Field` externally
3. hash each 5-term tuple with Poseidon-5
4. build the ordered depth-2 Poseidon Merkle root externally
5. sign the raw 32-byte big-endian root bytes that Noir checks with `std::ecdsa_secp256k1::verify_signature`
6. prepare one private tuple, Merkle path, and Merkle index per disclosed term

The circuit does not perform RDF parsing, canonicalization, or term hashing on its own.

## How to run

```bash
nargo execute
```

```bash
bb prove -b ./target/noir_selective_disclosure_merkle_path_test.json -w ./target/noir_selective_disclosure_merkle_path_test.gz --write_vk -o ./target/proof --output_format bytes_and_fields 
```

Note: public_inputs_fields.json will contain public inputs in the exact same order with which the Prover decided to create the circuit.

```bash
bb verify -p ./target/proof/proof -k ./target/proof/vk -i ./target/proof/public_inputs
```

## Known limitations: A note on Ordering of public inputs

THe order of disclosed terms, as well as the order of disclosed positions of respective disclosed terms is fixed. THe Verifier cannot re-order these public inputs arbitrarily when trying to verify the proof.

## TODO

Find a way to arbitrarily order disclosed terms.
