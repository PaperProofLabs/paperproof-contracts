// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_publishing::artifact_types;

use std::string::{Self as string, String};

const E_INVALID_ARTIFACT_TYPE: u64 = 5;

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

public fun code(artifact_type: u8, number: u64): String {
    assert_supported(artifact_type);
    let mut code = string::utf8(b"PaperProof-");
    string::append(&mut code, name(artifact_type));
    string::append(&mut code, string::utf8(b"-"));
    string::append(&mut code, u64_to_string(number));
    code
}

fun u64_to_string(n: u64): String {
    if (n == 0) {
        return string::utf8(b"0")
    };

    let mut x = n;
    let mut digits_reversed = vector::empty<u8>();

    while (x > 0) {
        let digit = (x % 10) as u8;
        vector::push_back(&mut digits_reversed, 48 + digit);
        x = x / 10;
    };

    let len = vector::length(&digits_reversed);
    let mut i = len;
    let mut digits = vector::empty<u8>();

    while (i > 0) {
        i = i - 1;
        let b = *vector::borrow(&digits_reversed, i);
        vector::push_back(&mut digits, b);
    };

    string::utf8(digits)
}
