use dep::std;
use dep::poseidon::poseidon::bn254;

global N: u32 = 4;  // max number of dataset quads used in proof
global K: u32 = 3;  // number of disclosed terms in this example
global TREE_DEPTH: u32 = 2;

// Example disclosed triples/tuples:

// Quad 0: (s0_disclosed, p0_disclosed, o0_val_hidden, o0_suf_hidden, g0_hidden_),
// Quad 1: (s1_hidden, p1_disclosed, o1_val_hidden, o1_suf_hidden, g1_hidden),

// ==========================================
// HASH / MERKLE HELPERS
// ==========================================

fn merkle_step(left: Field, right: Field) -> Field {
    bn254::hash_2([left, right])
}

/* fn hash_leaf(q: [Field; 5]) -> Field {
    bn254::hash_5(q)
} */

fn hash_leaf(s: Field, p: Field, o_val: Field, o_suf: Field, g: Field) -> Field {
    bn254::hash_5([s, p, o_val, o_suf, g])
}

fn verify_merkle_path(leaf: Field, idx: Field, path: [Field; TREE_DEPTH]) -> Field {
    let mut current = leaf;

    // let mut i_idx = idx;
    // Convert index to a boolean array to cleanly determine left/right children
    let idx_bits: [u1; TREE_DEPTH] = idx.to_le_bits();

    for i in 0..TREE_DEPTH {
        let sibling = path[i];
        let is_right = idx_bits[i] as Field; // 1 if current is right child, 0 if left
        
        // If current is right (1), left gets sibling, right gets current.
        // If current is left (0), left gets current, right gets sibling.
        let left  = (1 - is_right) * current + is_right * sibling;
        let right = is_right * current + (1 - is_right) * sibling;
        
        current = bn254::hash_2([left, right]);
    }
    current
} 

/* fn verify_merkle_path(leaf: Field, idx: Field, path: [Field; TREE_DEPTH]) -> Field {
    let mut current = leaf;
    
    for i in 0..TREE_DEPTH {
        let sibling = path[i];
        
        // MSB first: extract bit TREE_DEPTH-1-i
        let bit_pos = TREE_DEPTH as u32 - 1 - (i as u32);
        let is_right = ((idx >> (bit_pos as u32)) & 1u32) as Field;
        
        let left  = (1 - is_right) * current + is_right * sibling;
        let right = is_right * current + (1 - is_right) * sibling;
        
        current = merkle_step(left, right);
    }
    current
} */

// ==========================================
// MAIN CIRCUIT
// ==========================================

fn main(
    // Issuer PUBLIC KEY
    pub_key_x: pub [u8; 32],
    pub_key_y: pub [u8; 32],

    // isclosed term hashes + their position index in their quad
    disclosed_terms: pub [Field; K],
    disclosed_position_indices: pub [Field; K],  // 0..4 for s,p,o_val,o_suf,g

    // PRIVATE
    root: Field,
    signature: [u8; 64],

    // Per disclosed term k:
    // relevant_leaves: [Field; K],
    relevant_private_terms: [[Field; 5]; K],           // quad[k] contains disclosed_terms[k]
    merkle_paths: [[Field; TREE_DEPTH]; K],   // path proving the matching quad that contains disclosed term [k] is member of dataset
    merkle_indices: [Field; K],               // quad 0, 0, 1,    the leaf positions in merkle tree
    // quad_indices: [u32; K]                  // which quad[k] contains disclosed term k
) {
    // 1. Verify ECDSA on root
    let root_bytes: [u8; 32] = root.to_be_bytes();
    let ok = std::ecdsa_secp256k1::verify_signature(
        pub_key_x, pub_key_y, signature, root_bytes
    );
    assert(ok);

    // 2. For each disclosed term k:
    for k in 0..K {

        std::println("");
        std::println("--- Checking Term ---");
        std::println(k);


        // 2a. Position integrity
        let pos_idx = disclosed_position_indices[k] as u32;
        // let m_idx = merkle_indices[k] as u32;
        // let q_idx = quad_indices[k];
        assert(pos_idx < 5);
        // assert(m_idx < 4);
        // assert(q_idx < N);

        // assert(relevant_quads[k][pos_idx] == disclosed_terms[k]);
        let mut term_matched = false;
        for i in 0..5 {
            if i == pos_idx {
                assert(relevant_private_terms[k][i] == disclosed_terms[k]);
                term_matched = true;
            }
        }
        /* std::println("2. Term Match Valid:");
        std::println(term_matched); // MUST BE TRUE */

        // 2b. Membership: quad[k] is member of signed dataset
        let q = relevant_private_terms[k];
        let leaf = hash_leaf(q[0], q[1], q[2], q[3], q[4]);
        // let leaf = hash_leaf(relevant_private_terms[k]);
        // let leaf = relevant_leaves[k];
        println(leaf);
        // let computed_root = verify_merkle_path(leaf, m_idx, merkle_paths[k]);
        let computed_root = verify_merkle_path(leaf, merkle_indices[k], merkle_paths[k]);
        assert(computed_root == root);

// Debugging
       /*  
               std::println("3. Root Match Valid:");
        std::println(computed_root == root); // MUST BE TRUE
        if computed_root != root {
            std::println("  -> EXPECTED ROOT:");
            std::println(root);
            std::println("  -> COMPUTED ROOT:");
            std::println(computed_root);
        }*/
    } 
    
}