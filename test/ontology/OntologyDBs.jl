# Copyright 2018 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module TestOntologyDBs
using Base.Test

using Catlab
using SemanticFlowGraphs

# Local file
############

# Load concepts.
db = OntologyDB()
@test !has_concept(db, "foo")
@test_throws OntologyError concept(db, "foo")
load_ontology_file(db, joinpath(@__DIR__, "data", "foobar.json"))
@test has_concept(db, "foo")
@test isa(concept(db, "foo"), Monocl.Ob)
@test isa(concept(db, "bar-from-foo"), Monocl.Hom)

# Concept accessors.
@test isa(concepts(db), Presentation)
@test concepts(db, ["foo", "bar-from-foo"]) ==
  [ concept(db, "foo"), concept(db, "bar-from-foo") ]

# Remote database
#################

# Load single concept.
db = OntologyDB()
@test !has_concept(db, "model")
@test isa(load_concept(db, "model"), Monocl.Ob)
@test isa(concept(db, "model"), Monocl.Ob)
@test isa(load_concept(db, "fit"), Monocl.Hom)
@test isa(concept(db, "fit"), Monocl.Hom)
@test isa(concept_document(db, "model"), Associative)
@test_throws OntologyError load_concept(db, "xxx")

# Load many concepts.
@test !has_concept(db, "data-source")
load_concepts(db; ids=["data", "data-source", "read-data"])
@test isa(concept(db, "model"), Monocl.Ob)       # Already loaded.
@test isa(concept(db, "fit"), Monocl.Hom)        # Already loaded.
@test isa(concept(db, "data-source"), Monocl.Ob) # Not loaded.
@test isa(concept(db, "read-data"), Monocl.Hom)  # Not loaded.
@test !has_concept(db, "fit-supervised")

# Load single annotation.
df_id = AnnotationID("python", "pandas", "data-frame")
@test !has_annotation(db, df_id)
@test_throws OntologyError annotation(db, df_id)
@test isa(load_annotation(db, df_id), ObAnnotation)
@test isa(annotation(db, df_id), ObAnnotation)
@test isa(annotation_document(db, df_id), Associative)
@test has_annotation(db, df_id)
@test annotation(db, df_id) == annotation(db, "python/pandas/data-frame")
@test annotation(db, df_id) == annotation(db, "annotation/python/pandas/data-frame")

bad_id = AnnotationID("python", "pandas", "xxx")
@test_throws OntologyError load_annotation(db, bad_id)

# Load all annotations in a package.
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
