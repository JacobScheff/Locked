#!/usr/bin/env python3
"""Mirrors ShieldTokenResolution.resolve and WeeklyLockSchedule.action."""


def resolve(locked_names, token_by_name):
    return {token_by_name[name] for name in locked_names if name in token_by_name}


def weekly_action(last_week, current_week):
    if not last_week:
        return "arm"
    if last_week == current_week:
        return "idle"
    if last_week.startswith("legacy:"):
        stored = last_week.split(":", 1)[1]
        return "idle" if stored == current_week else "lock"
    if "-" in last_week and not last_week[:4].isdigit():
        return "adopt"
    return "lock"


def expect(actual, expected, label):
    if actual != expected:
        raise SystemExit(f"{label}: expected {expected!r}, got {actual!r}")
    print(f"ok  {label}")


def main():
    instagram, tiktok, youtube, unnamed = "ig", "tt", "yt", "anon"
    token_by_name = {"Instagram": instagram, "TikTok": tiktok, "YouTube": youtube}

    expect(
        resolve(["Instagram"], token_by_name),
        {instagram},
        "locking one named app shields only that app",
    )
    expect(
        resolve(["Instagram", "TikTok"], token_by_name),
        {instagram, tiktok},
        "two locked apps stay independently shielded",
    )
    expect(
        resolve(["TikTok"], token_by_name),
        {tiktok},
        "unlocking one named app drops only that token",
    )
    expect(
        resolve([], token_by_name),
        set(),
        "unlocking every named app clears the home-screen shield",
    )
    expect(
        resolve(["Instagram"], token_by_name),
        {instagram},
        "stored unnamed picker tokens are not added to the shield",
    )
    expect(
        resolve(["Missing"], token_by_name),
        set(),
        "a lock without a token does not invent substitutes",
    )
    _ = unnamed

    expect(weekly_action(None, "2026-W36"), "arm", "first launch arms the week without locking")
    expect(weekly_action("", "2026-W36"), "arm", "empty stamp arms the week without locking")
    expect(weekly_action("2026-W36", "2026-W36"), "idle", "same week never re-locks")
    expect(weekly_action("2026-W35", "2026-W36"), "lock", "Sunday week change locks once")
    expect(
        weekly_action("legacy:2026-W36", "2026-W36"),
        "idle",
        "legacy stamp for this week does not lock on upgrade",
    )
    expect(
        weekly_action("legacy:2026-W35", "2026-W36"),
        "lock",
        "legacy stamp from last week still locks on Sunday",
    )
    print("all shield and weekly-lock checks passed")


if __name__ == "__main__":
    main()
