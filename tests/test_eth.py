import httpx
import pytest
import respx

from app.eth import InfuraError, get_balance_wei

ADDRESS = "0xC94770007dda54cF92009BFF0dE90c06F603a09f"
INFURA_URL = "https://mainnet.infura.io/v3/test-key"


@pytest.mark.asyncio
@respx.mock
async def test_get_balance_wei_success():
    respx.post(INFURA_URL).mock(
        return_value=httpx.Response(200, json={"jsonrpc": "2.0", "id": 1, "result": "0x4e1003b28d9280"})
    )

    async with httpx.AsyncClient() as client:
        balance = await get_balance_wei(client, ADDRESS)

    assert balance == int("0x4e1003b28d9280", 16)


@pytest.mark.asyncio
@respx.mock
async def test_get_balance_wei_http_error():
    respx.post(INFURA_URL).mock(return_value=httpx.Response(500))

    async with httpx.AsyncClient() as client:
        with pytest.raises(InfuraError):
            await get_balance_wei(client, ADDRESS)


@pytest.mark.asyncio
@respx.mock
async def test_get_balance_wei_rpc_error():
    respx.post(INFURA_URL).mock(
        return_value=httpx.Response(200, json={"jsonrpc": "2.0", "id": 1, "error": {"code": -32602, "message": "invalid params"}})
    )

    async with httpx.AsyncClient() as client:
        with pytest.raises(InfuraError):
            await get_balance_wei(client, ADDRESS)
