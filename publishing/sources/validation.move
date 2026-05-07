// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_publishing::validation;

use std::string::{Self as string, String};

const E_EMPTY_CONTENT_HASH: u64 = 10;
const E_EMPTY_BLOB_ID: u64 = 11;
const E_EMPTY_BLOB_OBJECT_ID: u64 = 12;
const E_EMPTY_CONTENT_TYPE: u64 = 13;
const E_EMPTY_TITLE: u64 = 14;
const E_EMPTY_AUTHOR_LIST: u64 = 17;
const E_TOO_MANY_KEYWORDS: u64 = 18;
const E_TOO_MANY_AUTHORS: u64 = 19;
const E_TOO_MANY_TAGS: u64 = 20;
const E_TEXT_TOO_LONG: u64 = 21;
const E_EMPTY_TEXT: u64 = 22;
const E_EMPTY_VECTOR_ITEM: u64 = 23;
const MAX_KEYWORDS: u64 = 10;
const MAX_AUTHORS: u64 = 20;
const MAX_TAGS: u64 = 20;
const MAX_TITLE_BYTES: u64 = 256;
const MAX_LONG_TEXT_BYTES: u64 = 4096;
const MAX_MEDIUM_TEXT_BYTES: u64 = 1024;
const MAX_SHORT_TEXT_BYTES: u64 = 256;
const MAX_VECTOR_ITEM_BYTES: u64 = 128;
const MAX_CONTENT_HASH_BYTES: u64 = 128;
const MAX_WALRUS_BLOB_ID_BYTES: u64 = 128;
const MAX_WALRUS_BLOB_OBJECT_ID_BYTES: u64 = 128;
const MAX_CONTENT_TYPE_BYTES: u64 = 64;

public fun content_fields(
    content_hash: &String,
    walrus_blob_id: &String,
    walrus_blob_object_id: &String,
    content_type: &String,
) {
    assert!(string::length(content_hash) > 0, E_EMPTY_CONTENT_HASH);
    assert!(string::length(content_hash) <= MAX_CONTENT_HASH_BYTES, E_TEXT_TOO_LONG);
    assert!(string::length(walrus_blob_id) > 0, E_EMPTY_BLOB_ID);
    assert!(string::length(walrus_blob_id) <= MAX_WALRUS_BLOB_ID_BYTES, E_TEXT_TOO_LONG);
    assert!(string::length(walrus_blob_object_id) > 0, E_EMPTY_BLOB_OBJECT_ID);
    assert!(string::length(walrus_blob_object_id) <= MAX_WALRUS_BLOB_OBJECT_ID_BYTES, E_TEXT_TOO_LONG);
    assert!(string::length(content_type) > 0, E_EMPTY_CONTENT_TYPE);
    assert!(string::length(content_type) <= MAX_CONTENT_TYPE_BYTES, E_TEXT_TOO_LONG);
}

public fun title(title: &String) {
    assert!(string::length(title) > 0, E_EMPTY_TITLE);
    assert!(string::length(title) <= MAX_TITLE_BYTES, E_TEXT_TOO_LONG);
}

public fun long_text(text: &String) {
    assert_non_empty_max(text, MAX_LONG_TEXT_BYTES);
}

public fun medium_text(text: &String) {
    assert_non_empty_max(text, MAX_MEDIUM_TEXT_BYTES);
}

public fun short_text(text: &String) {
    assert_non_empty_max(text, MAX_SHORT_TEXT_BYTES);
}

public fun authors(authors: &vector<String>) {
    assert!(vector::length(authors) > 0, E_EMPTY_AUTHOR_LIST);
    assert!(vector::length(authors) <= MAX_AUTHORS, E_TOO_MANY_AUTHORS);
    assert_vector_items(authors);
}

public fun keywords(keywords: &vector<String>) {
    assert!(vector::length(keywords) <= MAX_KEYWORDS, E_TOO_MANY_KEYWORDS);
    assert_vector_items(keywords);
}

public fun tags(tags: &vector<String>) {
    assert!(vector::length(tags) <= MAX_TAGS, E_TOO_MANY_TAGS);
    assert_vector_items(tags);
}

fun assert_non_empty_max(text: &String, max_bytes: u64) {
    assert!(string::length(text) > 0, E_EMPTY_TEXT);
    assert!(string::length(text) <= max_bytes, E_TEXT_TOO_LONG);
}

fun assert_vector_items(items: &vector<String>) {
    let mut i = 0;
    let len = vector::length(items);
    while (i < len) {
        let item = vector::borrow(items, i);
        assert!(string::length(item) > 0, E_EMPTY_VECTOR_ITEM);
        assert!(string::length(item) <= MAX_VECTOR_ITEM_BYTES, E_TEXT_TOO_LONG);
        i = i + 1;
    };
}
