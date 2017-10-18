module TestFlowGraph
using Base.Test

using Catlab.Diagram
using OpenDiscCore

const pkg_dir = abspath(joinpath(@__DIR__, "..", ".."))
const py_data_dir = joinpath(pkg_dir,
  "lang", "python", "opendisc", "integration_tests", "data")

# Raw flow graph
################

function read_py_raw_graph(name::String)
  read_raw_graph_file(joinpath(py_data_dir, "$name.xml"))
end

# Deserialize raw flow graph from GraphML.
diagram = read_py_raw_graph("pandas_read_sql")
@test nboxes(diagram) == 2
b1, b2 = boxes(diagram)
@test isnull(b1.value.annotation)
@test get(b2.value.annotation) == "python/pandas/read-sql-table"
@test [ get(p.annotation) for p in output_ports(b1) ] ==
  [ "python/sqlalchemy/engine" ]
@test [ get(p.annotation) for p in input_ports(b2)[1:2] ] ==
  [ "python/builtins/str", "python/sqlalchemy/engine" ]
@test [ get(p.annotation) for p in output_ports(b2) ] ==
  [ "python/pandas/data-frame" ]

# Semantic flow graph
#####################

db = OntologyDB()

# Read SQL table using pandas and SQLAlchemy.
raw = read_py_raw_graph("pandas_read_sql")
semantic = to_semantic_graph(db, raw; elements=false)
d = WiringDiagram([], concepts(db, ["table"]))
engine = add_box!(d, Box([], concepts(db, ["sql-database"])))
cons = add_box!(d, construct(pair(concept(db, "sql-table-database"),
                                  concept(db, "sql-table-name"))))
read = add_box!(d, concept(db, "read-table"))
add_wires!(d, [
  (engine, 1) => (cons, 1),
  (cons, 1) => (read, 1),
  (read, 1) => (output_id(diagram), 1),
])
@test semantic == d

# K-means clustering on the Iris dataset using sklearn.
raw = read_py_raw_graph("sklearn_clustering_kmeans")
semantic = to_semantic_graph(db, raw; elements=false)
d = WiringDiagram([], concepts(db, ["array"]))
filename = add_box!(d, construct(concept(db, "filename")))
read = add_box!(d, concept(db, "read-tabular-file"))
kmeans = add_box!(d, construct(concept(db, "k-means")))
transform = add_box!(d, Box(concepts(db, ["table"]), concepts(db, ["array"])))
fit = add_box!(d, concept(db, "fit"))
clusters = add_box!(d, concept(db, "clustering-model-clusters"))
add_wires!(d, [
  (filename, 1) => (read, 1),
  (read, 1) => (transform, 1),
  (kmeans, 1) => (fit, 1),
  (transform, 1) => (fit, 2),
  (fit, 1) => (clusters, 1),
  (clusters, 1) => (output_id(d), 1),
])
@test semantic == d

# Compare sklearn clustering models using a cluster similarity metric.
# FIXME: The boxes are added to `d` in the exact order of `semantic`. That
# won't be necessary when we implement graph isomorphism for wiring diagrams.
raw = read_py_raw_graph("sklearn_clustering_metrics")
semantic = to_semantic_graph(db, raw; elements=false)
clustering_fit = Hom("fit",
  otimes(concept(db, "clustering-model"), concept(db, "data")),
  concept(db, "clustering-model"))
d = WiringDiagram([], concepts(db, ["array", "k-means", "agglomerative-clustering"]))
make_data = add_box!(d, Box([], concepts(db, ["array", "array"])))
kmeans_fit = add_box!(d, clustering_fit)
agglom = add_box!(d, construct(concept(db, "agglomerative-clustering")))
agglom_clusters = add_box!(d, concept(db, "clustering-model-clusters"))
agglom_fit = add_box!(d, clustering_fit)
score = add_box!(d, Box(concepts(db, ["array", "array"]), []))
kmeans = add_box!(d, construct(concept(db, "k-means")))
kmeans_clusters = add_box!(d, concept(db, "clustering-model-clusters"))
add_wires!(d, [
  (make_data, 1) => (kmeans_fit, 2),
  (make_data, 1) => (agglom_fit, 2),
  (make_data, 2) => (output_id(d), 1),
  (kmeans, 1) => (kmeans_fit, 1),
  (kmeans_fit, 1) => (kmeans_clusters, 1),
  (kmeans_fit, 1) => (output_id(d), 2),
  (kmeans_clusters, 1) => (score, 1),
  (agglom, 1) => (agglom_fit, 1),
  (agglom_fit, 1) => (agglom_clusters, 1),
  (agglom_fit, 1) => (output_id(d), 3),
  (agglom_clusters, 1) => (score, 2),
])
@test semantic == d

# Errors metrics for linear regression using sklearn.
raw = read_py_raw_graph("sklearn_regression_metrics")
semantic = to_semantic_graph(db, raw; elements=false)
d = WiringDiagram([], [])
filename = add_box!(d, construct(concept(db, "filename")))
data_x = add_box!(d, Box(concepts(db, ["table"]), concepts(db, ["table"])))
data_y = add_box!(d, Box(concepts(db, ["table"]), concepts(db, ["column"])))
ols = add_box!(d, construct(concept(db, "least-squares")))
fit = add_box!(d, concept(db, "fit-supervised"))
predict = add_box!(d, concept(db, "predict"))
error_l1 = add_box!(d, concept(db, "mean-absolute-error"))
error_l2 = add_box!(d, concept(db, "mean-squared-error"))
read = add_box!(d, concept(db, "read-tabular-file"))
add_wires!(d, [
  (filename, 1) => (read, 1),
  (read, 1) => (data_x, 1),
  (read, 1) => (data_y, 1),
  (ols, 1) => (fit, 1),
  (data_x, 1) => (fit, 2),
  (data_y, 1) => (fit, 3),
  (fit, 1) => (predict, 1),
  (data_x, 1) => (predict, 2),
  (data_y, 1) => (error_l1, 1),
  (predict, 1) => (error_l1, 2),
  (data_y, 1) => (error_l2, 1),
  (predict, 1) => (error_l2, 2),
])
@test semantic == d

# Linear regression on an R dataset using statsmodels.
raw = read_py_raw_graph("statsmodels_regression")
semantic = to_semantic_graph(db, raw; elements=false)
d = WiringDiagram([], concepts(db, ["linear-regression"]))
ols = add_box!(d, construct(concept(db, "least-squares")))
read_get = add_box!(d, Box(concepts(db, ["data"]), concepts(db, ["table"])))
eval_formula = add_box!(d, concept(db, "evaluate-formula-supervised"))
fit = add_box!(d, concept(db, "fit-supervised"))
read = add_box!(d, concept(db, "read-table"))
r_data = add_box!(d, construct(pair(concept(db, "r-dataset-name"),
                                    concept(db, "r-dataset-package"))))
add_wires!(d, [
  (r_data, 1) => (read, 1),
  (read, 1) => (read_get, 1),
  (read_get, 1) => (eval_formula, 2),
  (ols, 1) => (fit, 1),
  (eval_formula, 1) => (fit, 2),
  (eval_formula, 2) => (fit, 3),
  (fit, 1) => (output_id(d), 1),
])
@test semantic == d

end
