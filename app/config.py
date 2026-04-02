from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "mysql+pymysql://flashsale:flashsale123@localhost:3306/flashsale"
    redis_host: str = "localhost"
    redis_port: int = 6379
    rate_limit_per_second: int = 10
    environment: str = "development"

    class Config:
        env_file = ".env"


settings = Settings()
