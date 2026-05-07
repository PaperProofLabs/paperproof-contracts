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

const MAX_KEYWORDS: u64 = 10;
const MAX_AUTHORS: u64 = 20;
const MAX_TAGS: u64 = 20;

public fun content_fields(
    content_hash: &String,
    walrus_blob_id: &String,
    walrus_blob_object_id: &String,
    content_type: &String,
) {
    assert!(string::length(content_hash) > 0, E_EMPTY_CONTENT_HASH);
    assert!(string::length(walrus_blob_id) > 0, E_EMPTY_BLOB_ID);
    assert!(string::length(walrus_blob_object_id) > 0, E_EMPTY_BLOB_OBJECT_ID);
    assert!(string::length(content_type) > 0, E_EMPTY_CONTENT_TYPE);
}

public fun title(title: &String) {
    assert!(string::length(title) > 0, E_EMPTY_TITLE);
}

public fun authors(authors: &vector<String>) {
    assert!(vector::length(authors) > 0, E_EMPTY_AUTHOR_LIST);
    assert!(vector::length(authors) <= MAX_AUTHORS, E_TOO_MANY_AUTHORS);
}

public fun keywords(keywords: &vector<String>) {
    assert!(vector::length(keywords) <= MAX_KEYWORDS, E_TOO_MANY_KEYWORDS);
}

public fun tags(tags: &vector<String>) {
    assert!(vector::length(tags) <= MAX_TAGS, E_TOO_MANY_TAGS);
}
