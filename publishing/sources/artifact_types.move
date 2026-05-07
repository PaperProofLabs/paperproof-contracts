// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_publishing::artifact_types;

use std::string::{Self as string, String};
const E_INVALID_ARTIFACT_TYPE: u64 = 5;
const E_OBJECT_ID_TOO_SHORT: u64 = 6;

const PREPRINT: u8 = 1;
const BLOG_POST: u8 = 2;
const TECHNICAL_REPORT: u8 = 3;
const DATASET: u8 = 4;
const SOFTWARE_RELEASE: u8 = 5;
const GENERIC_FILE: u8 = 6;

public fun preprint(): u8 { PREPRINT }
public fun blog_post(): u8 { BLOG_POST }
public fun technical_report(): u8 { TECHNICAL_REPORT }
public fun dataset(): u8 { DATASET }
public fun software_release(): u8 { SOFTWARE_RELEASE }
public fun generic_file(): u8 { GENERIC_FILE }

public fun assert_supported(artifact_type: u8) {
    assert!(
        artifact_type == PREPRINT ||
        artifact_type == BLOG_POST ||
        artifact_type == TECHNICAL_REPORT ||
        artifact_type == DATASET ||
        artifact_type == SOFTWARE_RELEASE ||
        artifact_type == GENERIC_FILE,
        E_INVALID_ARTIFACT_TYPE,
    );
}

public fun name(artifact_type: u8): String {
    if (artifact_type == PREPRINT) {
        string::utf8(b"preprint")
    } else if (artifact_type == BLOG_POST) {
        string::utf8(b"blog_post")
    } else if (artifact_type == TECHNICAL_REPORT) {
        string::utf8(b"technical_report")
    } else if (artifact_type == DATASET) {
        string::utf8(b"dataset")
    } else if (artifact_type == SOFTWARE_RELEASE) {
        string::utf8(b"software_release")
    } else if (artifact_type == GENERIC_FILE) {
        string::utf8(b"generic_file")
    } else {
        abort E_INVALID_ARTIFACT_TYPE
    }
}

public fun code(artifact_type: u8, epoch: u64, series_id: &sui::object::ID): String {
    assert_supported(artifact_type);
    let mut code = string::utf8(b"PaperProof-");
    string::append(&mut code, name(artifact_type));
    string::append(&mut code, string::utf8(b"-"));
    string::append(&mut code, epoch6_to_string(epoch));
    string::append(&mut code, string::utf8(b"-"));
    string::append(&mut code, id_hex_prefix_12(series_id));
    code
}

fun epoch6_to_string(epoch: u64): String {
    let mut n = epoch % 1000000;
    let mut divisor = 100000;
    let mut digits = vector::empty<u8>();

    while (divisor > 0) {
        let digit = (n / divisor) as u8;
        vector::push_back(&mut digits, 48 + digit);
        n = n % divisor;
        divisor = divisor / 10;
    };

    string::utf8(digits)
}

fun id_hex_prefix_12(series_id: &sui::object::ID): String {
    let bytes = series_id.to_bytes();
    assert!(vector::length(&bytes) >= 6, E_OBJECT_ID_TOO_SHORT);

    let mut hex = vector::empty<u8>();
    let mut i = 0;
    while (i < 6) {
        let byte = *vector::borrow(&bytes, i);
        vector::push_back(&mut hex, hex_digit(byte / 16));
        vector::push_back(&mut hex, hex_digit(byte % 16));
        i = i + 1;
    };

    string::utf8(hex)
}

fun hex_digit(n: u8): u8 {
    if (n < 10) {
        48 + n
    } else {
        87 + n
    }
}
