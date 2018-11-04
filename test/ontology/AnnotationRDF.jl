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

module TestAnnotationRDF
using Test

using Serd, Serd.RDF
using Catlab

using SemanticFlowGraphs

const R = Resource

A, B, C, D = Ob(Monocl, "A", "B", "C", "D")
f = Hom("f", A, B)
g = Hom("g", B, C)
h = Hom("h", D, D)

# Object annotations

prefix = RDF.Prefix("ex", "http://www.example.org/#")
annotation = ObAnnotation(
  AnnotationID("python", "mypkg", "a"),
  Dict(:class => "ClassA"),
  A, []
)
stmts = annotation_to_rdf(annotation, prefix)
node = R("ex", "python:mypkg:a")
@test Triple(node, R("monocl", "code_language"), Literal("python")) in stmts
@test Triple(node, R("monocl", "code_package"), Literal("mypkg")) in stmts
@test Triple(node, R("monocl", "code_class"), Literal("ClassA")) in stmts
@test Triple(node, R("monocl", "code_meaning"), R("ex","A")) in stmts

# Morphism annotations

annotation = HomAnnotation(
  AnnotationID("python", "mypkg", "a-do-composition"),
  Dict(:class => ["ClassA", "MixinB"], :method => "do_composition"),
  otimes(compose(f,g),h)
)
node = R("ex", "python:mypkg:a-do-composition")
graph_node = R("ex", "python:mypkg:a-do-composition:diagram")
stmts = annotation_to_rdf(annotation, prefix)
@test Triple(node, R("monocl", "code_language"), Literal("python")) in stmts
@test Triple(node, R("monocl", "code_package"), Literal("mypkg")) in stmts
@test Triple(node, R("monocl", "code_class"), Literal("ClassA")) in stmts
@test Triple(node, R("monocl", "code_class"), Literal("MixinB")) in stmts
@test Triple(node, R("monocl", "code_method"), Literal("do_composition")) in stmts
@test Triple(node, R("monocl", "code_meaning"), graph_node) in stmts

end
