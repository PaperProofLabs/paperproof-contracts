// Copyright (c) 2026 PaperProof Labs. All rights reserved.
// SPDX-License-Identifier: LicenseRef-PaperProof-Source-Available

module paperproof_shared_controller::controller_marketplace;

use std::string;
use sui::display;
use sui::package;
use sui::transfer;
use sui::transfer_policy::{Self as transfer_policy};

use paperproof_shared_controller::controller::ControllerNFT;

public struct CONTROLLER_MARKETPLACE has drop {}

fun init(otw: CONTROLLER_MARKETPLACE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    let mut nft_display = display::new<ControllerNFT>(&publisher, ctx);
    display::add(&mut nft_display, string::utf8(b"name"), string::utf8(b"PaperProof Controller NFT: {artifact_code}"));
    display::add(
        &mut nft_display,
        string::utf8(b"description"),
        string::utf8(b"Transferable control rights for PaperProof artifact series {artifact_code}."),
    );
    display::add(&mut nft_display, string::utf8(b"image_url"), string::utf8(b"{image_url}"));
    display::add(&mut nft_display, string::utf8(b"image"), string::utf8(b"{image_url}"));
    display::add(&mut nft_display, string::utf8(b"artifact_code"), string::utf8(b"{artifact_code}"));
    display::add(&mut nft_display, string::utf8(b"series_id"), string::utf8(b"{series_id}"));
    display::add(&mut nft_display, string::utf8(b"artifact_type"), string::utf8(b"{artifact_type_name}"));
    display::add(&mut nft_display, string::utf8(b"control_right"), string::utf8(b"{control_right}"));
    display::add(&mut nft_display, string::utf8(b"authority_mode"), string::utf8(b"{authority_mode_name}"));
    display::add(&mut nft_display, string::utf8(b"controller_nft_id"), string::utf8(b"{id}"));
    display::update_version(&mut nft_display);
    transfer::public_share_object(nft_display);

    let (policy, cap) = transfer_policy::new<ControllerNFT>(&publisher, ctx);
    transfer::public_share_object(policy);
    transfer::public_transfer(cap, tx_context::sender(ctx));

    publisher.burn();
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(CONTROLLER_MARKETPLACE {}, ctx);
}
