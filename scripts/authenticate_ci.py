#!/usr/bin/env python3
"""Authenticate the TestZeus CLI from environment variables only.

Secrets stay in the process environment (not argv), so they do not appear in
`ps` listings the way `testzeus login --password …` / `session-exchange --token …` would.
"""

from __future__ import annotations

import asyncio
import os
import sys


def _env(name: str) -> str:
    return os.environ.get(name, "").strip()


async def _login_with_password(email: str, password: str, profile: str) -> None:
    from testzeus_cli.config import get_client_config, update_config
    from testzeus_sdk import TestZeusClient

    config, _, _, _ = get_client_config(profile)
    base_url = config.get("base_url") or "https://pb.prod.testzeus.app"
    client = TestZeusClient(email=email, password=password, base_url=base_url)

    async with client:
        await client.ensure_authenticated()
        update_config(
            profile,
            {
                "api_url": client.base_url,
                "email": email,
                "token": client.token,
                "tenant_id": client.get_tenant_id(),
                "user_id": client.get_user_id(),
            },
        )
    print(f"Authenticated via email/password (profile: {profile}).", flush=True)


async def _session_exchange(token: str, profile: str) -> None:
    from testzeus_cli.config import get_client_config, update_config
    from testzeus_cli.utils.auth import decode_jwt_payload, initialize_client_with_token
    from testzeus_sdk import TestZeusClient

    config, _, _, _ = get_client_config(profile)
    base_url = config.get("base_url") or "https://pb.prod.testzeus.app"
    client = TestZeusClient(base_url=base_url)

    async with client:
        exchanged_user_id = ""
        exchanged_tenant_id = ""
        exchanged_email = ""
        fallback_mode = False
        try:
            result = await client.auth.exchange_session(token)
            session_token = result.session_token
            exchanged_user_id = result.user_id or ""
            exchanged_tenant_id = result.tenant_id or ""
            exchanged_email = result.email or ""
        except ValueError:
            claims = decode_jwt_payload(token) or {}
            session_token = token
            exchanged_user_id = str(claims.get("id") or claims.get("sub") or "")
            exchanged_tenant_id = str(claims.get("tenant") or "")
            exchanged_email = str(claims.get("email") or "")
            fallback_mode = True

        if exchanged_user_id:
            try:
                initialize_client_with_token(client, session_token, exchanged_tenant_id or None)
                user = await client.users.get_one(exchanged_user_id)
                if not exchanged_tenant_id:
                    exchanged_tenant_id = str(getattr(user, "tenant", "") or "")
                if not exchanged_email:
                    exchanged_email = str(getattr(user, "email", "") or "")
            except Exception:
                pass

        update_config(
            profile,
            {
                "api_url": base_url,
                "token": session_token,
                "user_id": exchanged_user_id,
                "tenant_id": exchanged_tenant_id,
                "email": exchanged_email,
                "session_id": profile,
                "source": "raw_ui_token" if fallback_mode else "exchanged_token",
                "auth_mode": "token",
            },
        )

    print(f"Authenticated via token (profile: {profile}).", flush=True)


def main() -> int:
    token = _env("TESTZEUS_TOKEN")
    email = _env("TESTZEUS_EMAIL")
    password = _env("TESTZEUS_PASSWORD")
    profile = _env("TESTZEUS_PROFILE") or ("ci" if token else "default")

    try:
        if token:
            asyncio.run(_session_exchange(token, profile))
            # Export profile for the shell shim via a small marker file path convention:
            # caller reads TESTZEUS_PROFILE from env (already set).
            return 0
        if email and password:
            asyncio.run(_login_with_password(email, password, profile))
            return 0
    except Exception as exc:
        # Never print credential values — message only.
        print(f"Authentication failed: {type(exc).__name__}: {exc}", file=sys.stderr, flush=True)
        return 1

    print(
        "Authentication required. Set TESTZEUS_TOKEN (preferred) or "
        "TESTZEUS_EMAIL + TESTZEUS_PASSWORD.",
        file=sys.stderr,
        flush=True,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
