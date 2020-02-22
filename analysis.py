import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
import pandas as pd

load_dotenv(".env")
DB_URI = os.environ.get("SQLALCHEMY_DATABASE_URI")
engine = create_engine(DB_URI)
with open('script.sql', 'r') as f:
    SQL_SCRIPT = text(f.read())


def produce_analysis_csv():
    df = pd.read_sql(SQL_SCRIPT, engine)
    df.to_csv('analysis.csv', index=False)
    return df

if __name__ == "__main__":
    df = produce_analysis_csv()
    print (df.head())
