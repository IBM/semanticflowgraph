module TestWiring
using Base.Test

import Catlab.Diagram: Graphviz
using Catlab.Diagram: Wiring, GraphvizWiring
using OpenDiscCore: Doctrine, Wiring

# Monocl
########

A0, A, B0, B = Ob(Monocl, :A0, :A, :B0, :B)
f = Hom(:f, A, B)
g = Hom(:g, B, A)

diagram = to_wiring_diagram(f)
@test boxes(diagram) == [ Box(f) ]
@test input_ports(diagram) == [ A ]
@test output_ports(diagram) == [ B ]

coercion = coerce(SubOb(A0, A))
diagram = to_wiring_diagram(compose(coercion, f))
@test boxes(diagram) == [ Box(coercion), Box(f) ]
@test input_ports(diagram) == [ A0 ]
@test output_ports(diagram) == [ B ]

# Graphviz support.
diagram = to_wiring_diagram(compose(coerce(SubOb(A0,A)), construct(g)))
@test isa(to_graphviz(diagram), Graphviz.Graph)

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
