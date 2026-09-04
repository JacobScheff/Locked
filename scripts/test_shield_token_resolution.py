#!/usr/bin/env python3
"""Mirrors ShieldTokenResolution.resolve so we can verify per-app lock math."""


def resolve(locked_names, token_by_name, stored_tokens, known_named_tokens):
    tokens = {token_by_name[name] for name in locked_names if name in token_by_name}
    for token in stored_tokens:
        if token not in known_named_tokens:
            tokens.add(token)
    return tokens


def expect(actual, expected, label):
    if actual != expected:
        raise SystemExit(f"{label}: expected {expected!r}, got {actual!r}")
    print(f"ok  {label}")


def main():
    instagram, tiktok, youtube, unnamed = "ig", "tt", "yt", "anon"

    token_by_name = {"Instagram": instagram, "TikTok": tiktok, "YouTube": youtube}
    known = set(token_by_name.values())

    expect(
        resolve(["Instagram"], token_by_name, {instagram, tiktok, youtube}, known),
        {instagram},
        "locking one named app shields only that app",
    )
    expect(
        resolve(["Instagram", "TikTok"], token_by_name, {instagram, tiktok, youtube}, known),
        {instagram, tiktok},
        "two locked apps stay independently shielded",
    )
    expect(
        resolve(["TikTok"], token_by_name, {instagram, tiktok, youtube}, known),
        {tiktok},
        "unlocking one named app drops only that token",
    )
    expect(
        resolve([], token_by_name, {instagram, tiktok, youtube}, known),
        set(),
        "unlocking every named app clears known leftover tokens",
    )
    expect(
        resolve(["Instagram"], token_by_name, {instagram, unnamed}, known),
        {instagram, unnamed},
        "unnamed picker tokens stay locked until explicitly unlocked",
    )
    expect(
        resolve([], token_by_name, {unnamed}, known),
        {unnamed},
        "unnamed tokens survive after all named apps are unlocked",
    )
    expect(
        resolve(["Instagram"], token_by_name, set(), known),
        {instagram},
        "missing stored tokens still resolve from the name map",
    )
    expect(
        resolve(["Missing"], token_by_name, set(), known),
        set(),
        "a lock without a token does not invent substitutes",
    )
    print("all shield resolution checks passed")


if __name__ == "__main__":
    main()
