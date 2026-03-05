Work in progress.

# Testing selective disclosure for RDF datasets

This repository implements a Zero-Knowledge (ZK) circuit in Noir that enables the selective disclosure of specific Resource Description Framework (RDF) terms from a signed dataset.

Public inputs are: (a) dicslosed terms and (b) their positional index within a triple. We can make the quad indices private, using merkle paths to verify membership of leaves in a merkle root.

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
