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

module ConceptRDF
export presentation_to_rdf, generator_rdf_node

using Serd
using Catlab

using ...Doctrine, ...Ontology
using ..OntologyRDF: rdf_list

const R = RDF.Resource

# Data types
############

struct RDFState
  prefix::RDF.Prefix
  blank_count::Dict{String,Int}
  RDFState(prefix::RDF.Prefix) = new(prefix, Dict{String,Int}())
end

# RDF
#####

""" Convert concepts in Monocl ontology to RDF graph.
"""
function presentation_to_rdf(pres::Presentation, prefix::RDF.Prefix;
                             extra_rdf::Union{Function,Nothing}=nothing)
  stmts = RDF.Statement[
    RDF.Prefix("rdf"),
    RDF.Prefix("rdfs"),
    RDF.Prefix("cat", "http://datascienceontology.org/ns/catlab/"),
    RDF.Prefix("monocl", "http://datascienceontology.org/ns/monocl/"),
    prefix
  ]
  state = RDFState(prefix)
  for expr in generators(pres)
    append!(stmts, expr_to_rdf(expr, state))
    if expr isa Monocl.Hom
      append!(stmts, hom_generator_to_wiring_rdf(expr, state))
    end
    if extra_rdf != nothing && first(expr) != nothing
      append!(stmts, extra_rdf(expr, generator_rdf_node(expr, state)))
    end
  end
  stmts
end

""" Generate RDF for object generator.
"""
function expr_to_rdf(ob::Monocl.Ob{:generator}, state::RDFState)
  # FIXME: Objects are not really RDFS Classes but we abuse classes for
  # transitivity inference.
  node = generator_rdf_node(ob, state)
  [ RDF.Triple(node, R("rdf","type"), R("cat","Ob")),
    RDF.Triple(node, R("rdf","type"), R("rdfs","Class")) ]
end

""" Generate RDF for subobject relation.
"""
function expr_to_rdf(sub::Monocl.SubOb, state::RDFState)
  node = head(sub) == :generator && first(sub) != nothing ?
    generator_rdf_node(sub, state) : gen_blank(state, "subob")
  dom_node = generator_rdf_node(dom(sub), state)
  codom_node = generator_rdf_node(codom(sub), state)
  [ RDF.Triple(dom_node, R("rdfs","subClassOf"), codom_node),
    RDF.Triple(node, R("rdf","type"), R("monocl","SubOb")),
    RDF.Triple(node, R("cat","dom"), dom_node),
    RDF.Triple(node, R("cat","codom"), codom_node) ]
end

""" Generate RDF for morphism generator.

The domain and codomain objects are represented as RDF Lists.
"""
function expr_to_rdf(hom::Monocl.Hom{:generator}, state::RDFState)
  # FIXME: Morphisms are not really RDF Properties but we abuse properties for
  # transitivity inference.
  node = generator_rdf_node(hom, state)
  dom_node, dom_stmts = ob_to_rdf_list(dom(hom), state)
  codom_node, codom_stmts = ob_to_rdf_list(codom(hom), state)
  stmts = RDF.Statement[
    RDF.Triple(node, R("rdf","type"), R("cat","Hom")),
    RDF.Triple(node, R("rdf","type"), R("rdf","Property")),
    RDF.Triple(node, R("cat","dom"), dom_node),
    RDF.Triple(node, R("cat","codom"), codom_node),
  ]
  append!(stmts, dom_stmts)
  append!(stmts, codom_stmts)
  stmts
end

""" Generate RDF for submorphism relation.
"""
function expr_to_rdf(sub::Monocl.SubHom, state::RDFState)
  node = head(sub) == :generator && first(sub) != nothing ?
    generator_rdf_node(sub, state) : gen_blank(state, "subhom")
  dom_node = generator_rdf_node(dom(sub), state)
  codom_node = generator_rdf_node(codom(sub), state)
  [ RDF.Triple(dom_node, R("rdfs","subPropertyOf"), codom_node),
    RDF.Triple(node, R("rdf","type"), R("monocl","SubHom")),
    RDF.Triple(node, R("cat","dom"), dom_node),
    RDF.Triple(node, R("cat","codom"), codom_node) ]
end

""" Generate RDF for morphism generator in wiring diagram style.

Cf. `wiring_diagram_to_rdf` in `WiringRDF` module.
"""
function hom_generator_to_wiring_rdf(hom::Monocl.Hom{:generator}, state::RDFState)
  node = generator_rdf_node(hom, state)
  stmts = RDF.Statement[]
  for (i, dom_ob) in enumerate(collect(dom(hom)))
    port_node = generator_rdf_node(dom_ob, state)
    append!(stmts, [
      RDF.Triple(node, R("cat","input-port"), port_node),
      RDF.Triple(node, R("cat","input-port-$i"), port_node),
      RDF.Triple(port_node, R("cat","in"), node),
      RDF.Triple(port_node, R("cat","in-$i"), node),
    ])
  end
  for (i, codom_ob) in enumerate(collect(codom(hom)))
    port_node = generator_rdf_node(codom_ob, state)
    append!(stmts, [
      RDF.Triple(node, R("cat","output-port"), port_node),
      RDF.Triple(node, R("cat","output-port-$i"), port_node),
      RDF.Triple(node, R("cat","out"), port_node),
      RDF.Triple(node, R("cat","out-$i"), port_node),
    ])
  end
  stmts
end

""" Create RDF node for generator expression.
"""
function generator_rdf_node(expr::GATExpr{:generator}, prefix::RDF.Prefix)
  @assert first(expr) != nothing
  R(prefix.name, string(first(expr)))
end
function generator_rdf_node(expr::GATExpr{:generator}, state::RDFState)
  generator_rdf_node(expr, state.prefix)
end

""" Convert compound object in monoidal category ito RDF List. 
"""
function ob_to_rdf_list(dom_ob::Monocl.Ob, state::RDFState)
  nodes = [ generator_rdf_node(ob, state) for ob in collect(dom_ob) ]
  blank = gen_blank(state, "ob")
  rdf_list(nodes, string(blank.name, "-"))
end

""" `gensym` for RDF blank nodes.
"""
function gen_blank(state::RDFState, tag::String="b")
  count = get(state.blank_count, tag, 0) + 1
  state.blank_count[tag] = count
  RDF.Blank(string(tag, count))
end

end
