"""
groq_client.py — Thin wrapper around the Groq Python SDK for FitBuddy.

Responsibilities:
- Manage a single Groq client instance (lazily initialised).
- Call the Groq Chat Completions API with JSON mode enabled.
- Parse and return the raw JSON string from the LLM response.
- Raise typed exceptions that the FastAPI route handlers map to HTTP errors.
"""

from __future__ import annotations

import json
import logging
import os
import re
from typing import Any

import groq as groq_sdk

logger = logging.getLogger(__name__)


class GroqClientError(Exception):
    """Raised when the Groq API call itself fails (network, auth, rate-limit)."""
    def __init__(self, message: str, code: str = "groq_api_error"):
        super().__init__(message)
        self.code = code


class GroqParseError(Exception):
    """Raised when the LLM response cannot be parsed into valid JSON."""
    def __init__(self, message: str, raw: str = ""):
        super().__init__(message)
        self.raw = raw
        self.code = "parse_error"


# Module-level singleton — created once on first use.
_client: groq_sdk.Groq | None = None
_cached_api_key: str | None = None


def reset_client() -> None:
    """Reset the cached Groq client (useful for testing or config updates)."""
    global _client, _cached_api_key
    _client = None
    _cached_api_key = None


def _get_client() -> groq_sdk.Groq:
    """Return (or lazily create) the shared Groq client."""
    global _client, _cached_api_key
    api_key = os.environ.get("GROQ_API_KEY", "").strip()
    if not api_key:
        raise GroqClientError(
            "GROQ_API_KEY environment variable is not set.",
            code="missing_api_key",
        )
    if _client is None or _cached_api_key != api_key:
        timeout_seconds = float(os.environ.get("GROQ_TIMEOUT_SECONDS", "30.0"))
        _client = groq_sdk.Groq(api_key=api_key, timeout=timeout_seconds)
        _cached_api_key = api_key
    return _client


def _model() -> str:
    """Resolve the Groq model name from the environment, with a safe modern default."""
    return os.environ.get("GROQ_MODEL", "llama-3.1-8b-instant").strip()


def _extract_json(text: str) -> str:
    """
    Best-effort extraction of a JSON object from an LLM response string.

    Groq JSON mode should return clean JSON, but this handles edge cases where
    the model wraps the response in markdown fences.
    """
    text = text.strip()

    # Fast path: already valid JSON
    if text.startswith("{") or text.startswith("["):
        return text

    # Strip markdown code fences (```json ... ``` or ``` ... ```)
    fenced = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if fenced:
        return fenced.group(1).strip()

    # Last resort: find the first { and last }
    start = text.find("{")
    end   = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return text[start : end + 1]

    raise GroqParseError("No JSON object found in LLM response.", raw=text)


def call_groq(
    system_prompt: str,
    user_message: str,
    *,
    max_tokens: int = 4096,
    temperature: float = 0.7,
) -> dict[str, Any]:
    """
    Send a chat completion request to Groq and return the parsed JSON dict.

    Args:
        system_prompt: The system-turn instruction setting role and output schema.
        user_message:  The user-turn content with the specific request context.
        max_tokens:    Token limit for the completion (default 4096).
        temperature:   Sampling temperature (0 = deterministic, 1 = creative).

    Returns:
        Parsed JSON dict from the LLM response.

    Raises:
        GroqClientError: API call failed (auth, rate-limit, timeout, etc.)
        GroqParseError:  Response received but not valid JSON.
    """
    client = _get_client()
    model  = _model()

    logger.info("Calling Groq model=%s max_tokens=%d", model, max_tokens)

    try:
        completion = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": user_message},
            ],
            max_tokens=max_tokens,
            temperature=temperature,
            response_format={"type": "json_object"},
        )
    except groq_sdk.RateLimitError as exc:
        logger.warning("Groq rate limit exceeded: %s", exc)
        raise GroqClientError(str(exc), code="model_overloaded") from exc
    except groq_sdk.APITimeoutError as exc:
        logger.error("Groq request timed out: %s", exc)
        raise GroqClientError("Groq request timed out. Please try again.", code="groq_api_error") from exc
    except groq_sdk.APIConnectionError as exc:
        logger.error("Groq connection error: %s", exc)
        raise GroqClientError("Failed to connect to Groq API.", code="groq_api_error") from exc
    except groq_sdk.AuthenticationError:
        logger.error("Groq authentication error — verify GROQ_API_KEY environment variable")
        raise GroqClientError(
            "Groq API key is invalid or missing.", code="groq_api_error"
        )
    except Exception as exc:
        logger.exception("Unexpected Groq error: %s", exc)
        raise GroqClientError(str(exc), code="groq_api_error") from exc

    raw_content = completion.choices[0].message.content or ""
    logger.debug("Groq raw response (%d chars): %.500s", len(raw_content), raw_content)

    try:
        json_str = _extract_json(raw_content)
        return json.loads(json_str)
    except (json.JSONDecodeError, GroqParseError) as exc:
        raise GroqParseError(
            f"LLM returned non-JSON content: {exc}",
            raw=raw_content,
        ) from exc


def current_model() -> str:
    """Return the active model name (used by the health endpoint)."""
    return _model()
