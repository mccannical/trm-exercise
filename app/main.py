from contextlib import asynccontextmanager
from typing import Annotated

import httpx
from fastapi import FastAPI, HTTPException, Path

from app.eth import InfuraError, get_balance_wei

WEI_PER_ETH = 10**18


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with httpx.AsyncClient() as client:
        app.state.http_client = client
        yield


app = FastAPI(lifespan=lifespan)

EthAddress = Annotated[str, Path(pattern=r"^0x[a-fA-F0-9]{40}$")]


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/address/balance/{address}")
async def address_balance(address: EthAddress):
    try:
        balance_wei = await get_balance_wei(app.state.http_client, address)
    except InfuraError:
        raise HTTPException(status_code=502, detail="Failed to fetch balance from Infura")

    return {"balance": balance_wei / WEI_PER_ETH}
