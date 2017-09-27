module TestOntologyDBs
using Base.Test

using Catlab
using OpenDiscCore

# Local file
############

# Load concepts.
db = OntologyDB()
@test_throws OntologyError concept(db, "foo")
load_ontology_file(db, joinpath(@__DIR__, "data", "foobar.json"))
@test isa(concept(db, "foo"), Monocl.Ob)
@test isa(concept(db, "bar-from-foo"), Monocl.Hom)

# Concept accessors.
@test isa(concepts(db), Presentation)
@test concepts(db, ["foo", "bar-from-foo"]) ==
  [ concept(db, "foo"), concept(db, "bar-from-foo") ]

# Remote database
#################

# Load concepts.
db = OntologyDB()
@test_throws OntologyError concept(db, "model")
load_concepts(db)
@test isa(concept(db, "model"), Monocl.Ob)
@test isa(concept(db, "fit"), Monocl.Hom)

# Load single annotation.
df_id = AnnotationID("python", "pandas", "data-frame")
df_id_str = "python/pandas/data-frame"
@test_throws OntologyError annotation(db, df_id)
@test isa(load_annotation(db, df_id), ObAnnotation)
@test isa(annotation(db, df_id), ObAnnotation)
@test annotation(db, df_id) == annotation(db, df_id_str)

# Load all annotations in package.
series_id = AnnotationID("python", "pandas", "series")
ndarray_id = AnnotationID("python", "numpy", "ndarray")
@test_throws OntologyError annotation(db, series_id)
@test_throws OntologyError annotation(db, ndarray_id)
load_annotations(db, language="python", package="pandas")
@test_throws OntologyError annotation(db, ndarray_id)

note = annotation(db, series_id)
@test isa(note, Annotation)
@test isa(note.definition, Monocl.Ob)

note = annotation(db, AnnotationID("python", "pandas", "read-table"))
@test isa(note, Annotation)
@test isa(note.definition, Monocl.Hom)

end
