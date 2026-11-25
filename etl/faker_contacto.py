"""Genera correo y telefono SINTETICOS para cada cliente.

El origen trae el correo enmascarado (XXXXXXXXX) y no trae telefono.
La semilla fija hace que la carga sea repetible: siempre sale lo mismo.
Los correos usan dominios reservados (example.com/.org/.net): no son reales.
"""
import os
from dotenv import load_dotenv
from faker import Faker
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

load_dotenv()
url = URL.create(
    "postgresql+psycopg2",
    username=os.environ["POSTGRES_USER"],
    password=os.environ["POSTGRES_PASSWORD"],
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "6543")),
    database=os.environ["POSTGRES_DB"],
)
engine = create_engine(url)

Faker.seed(2026)
fake = Faker("es_MX")
dominios = ["example.com", "example.org", "example.net"]

with engine.begin() as con:
    ids = [r[0] for r in con.execute(
        text("SELECT id_cliente FROM cliente ORDER BY id_cliente"))]
    filas = [
        {
            "id": i,
            "correo": f"{fake.user_name()}{i}@{fake.random_element(dominios)}",
            "telefono": fake.phone_number(),
        }
        for i in ids
    ]
    con.execute(
        text("UPDATE cliente SET correo = :correo, telefono = :telefono "
             "WHERE id_cliente = :id"),
        filas,
    )
print(f"clientes actualizados: {len(filas)}")
