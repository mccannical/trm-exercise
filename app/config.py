from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    infura_api_key: str
    infura_network: str = "mainnet"


settings = Settings()
