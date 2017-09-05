import pandas as pd
import sqlalchemy as sa

db = sa.create_engine('sqlite:///datasets/iris.sqlite')
df = pd.read_sql_table('iris', db)
