module TestFlowGraph
using Base.Test

using Catlab.Diagram
using OpenDiscCore.FlowGraph

# Raw flow graph
################

const py_data_dir = abspath(joinpath(
  @__DIR__, "..", "lang", "python", "opendisc", "integration_tests", "data"))

diagram = read_raw_graph_file(joinpath(py_data_dir, "pandas_read_sql.xml"))
@test [ get(box.value.annotation, nothing) for box in boxes(diagram) ] ==
      [ nothing, "python/pandas/read-sql-table" ]
@test [ get(wire.value.annotation, nothing) for wire in wires(diagram) ] ==
      [ "python/sqlalchemy/engine", "python/sqlalchemy/engine",
        "python/pandas/data-frame" ]

end
