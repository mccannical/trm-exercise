import httpx

from app.config import settings


class InfuraError(Exception):
    pass


async def get_balance_wei(client: httpx.AsyncClient, address: str) -> int:
    url = f"https://{settings.infura_network}.infura.io/v3/{settings.infura_api_key}"
    payload = {
        "jsonrpc": "2.0",
        "method": "eth_getBalance",
        "params": [address, "latest"],
        "id": 1,
    }

    try:
        response = await client.post(url, json=payload, timeout=10.0)
        response.raise_for_status()
    except httpx.HTTPError as exc:
        raise InfuraError(f"Infura request failed: {exc}") from exc

    body = response.json()
    if "error" in body:
        raise InfuraError(f"Infura returned an error: {body['error']}")

    return int(body["result"], 16)
