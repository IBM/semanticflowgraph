import pandas as pd
import sqlalchemy as sa

with tempfile.NamedTemporaryFile(suffix='.db') as f:
    # Prepare data: don't trace this!
    table = pd.DataFrame({'x': [0,1,2], 'y': [True,False,True]})
    conn = sa.create_engine('sqlite:///' + f.name)
    table.to_sql('my_table', conn)

    # Main program.
    conn = sa.create_engine('sqlite:///' + f.name)
    df = pd.read_sql_table('my_table', conn)
