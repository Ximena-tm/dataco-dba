"""Carga los CSV tal cual a staging, sin limpiar nada."""
import os
import re
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

load_dotenv()
url = URL.create(
    "postgresql+psycopg2",
    username=os.environ["POSTGRES_USER"],
    password=os.environ["POSTGRES_PASSWORD"],
    host="localhost", port=6543,
    database=os.environ["POSTGRES_DB"],
)
engine = create_engine(url)

def limpiar(nombre):
    return re.sub(r"\W+", "_", nombre.strip().lower()).strip("_")

def cargar(ruta, tabla, **opciones):
    df = pd.read_csv(ruta, **opciones)
    df.columns = [limpiar(c) for c in df.columns]
    df.to_sql(tabla, engine, schema="staging", index=False,
              if_exists="replace", chunksize=2000, method="multi")
    print(f"{tabla}: {len(df)} filas cargadas")

cargar("data/DataCoSupplyChainDataset.csv", "ventas", encoding="latin-1")
cargar("data/tokenized_access_logs.csv", "visitas")
