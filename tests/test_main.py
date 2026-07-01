import httpx
import respx
from fastapi.testclient import TestClient

from app.main import app

ADDRESS = "0xC94770007dda54cF92009BFF0dE90c06F603a09f"
INFURA_URL = "https://mainnet.infura.io/v3/test-key"


def test_health():
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@respx.mock
def test_address_balance_success():
    respx.post(INFURA_URL).mock(
        return_value=httpx.Response(200, json={"jsonrpc": "2.0", "id": 1, "result": "0x4e1003b28d9280"})
    )

    with TestClient(app) as client:
        response = client.get(f"/address/balance/{ADDRESS}")

    assert response.status_code == 200
    assert response.json() == {"balance": int("0x4e1003b28d9280", 16) / 10**18}


def test_address_balance_malformed_address():
    with TestClient(app) as client:
        response = client.get("/address/balance/not-an-address")

    assert response.status_code == 422


@respx.mock
def test_address_balance_upstream_failure():
    respx.post(INFURA_URL).mock(return_value=httpx.Response(500))

    with TestClient(app) as client:
        response = client.get(f"/address/balance/{ADDRESS}")

    assert response.status_code == 502
