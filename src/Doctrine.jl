module Doctrine
export Monocl, MonoclCategory, MonoclError, Ob, Hom, SubOb, dom, codom,
  compose, id, subid, otimes, munit, opow, braid, mcopy, delete, pair,
  hom, ev, curry, coerce, construct, to_wiring_diagram

using Catlab
using Catlab.Doctrine: CategoryExpr, ObExpr, HomExpr, SymmetricMonoidalCategory
import Catlab.Doctrine: Ob, Hom, dom, codom, compose, id, otimes, munit,
  braid, mcopy, delete, pair, hom, ev, curry

using Catlab.Diagram
import Catlab.Diagram.Wiring: Box, WiringDiagram, to_wiring_diagram

# Cartesian (closed) category
#############################

""" Doctrine of *cartesian category*

This signature differs from the official Catlab doctrine by allowing `mcopy`
terms of size greater than 2.
"""
@signature SymmetricMonoidalCategory(Ob,Hom) => CartesianCategory(Ob,Hom) begin
  mcopy(A::Ob, n::Int)::Hom(A,opow(A,n))
  delete(A::Ob)::Hom(A,munit())
  
  mcopy(A::Ob) = mcopy(A,2)
  opow(A::Ob, n::Int) = otimes([A for i=1:n])
  opow(f::Hom, n::Int) = otimes([f for i=1:n])
end

""" Doctrine of *cartesian closed category*

This signature is identical to the official Catlab doctrine, except for
inheriting from a different doctrine.
"""
@signature CartesianCategory(Ob,Hom) => CartesianClosedCategory(Ob,Hom) begin
  hom(A::Ob, B::Ob)::Ob
  ev(A::Ob, B::Ob)::Hom(otimes(hom(A,B),A),B)
  curry(A::Ob, B::Ob, f::Hom(otimes(A,B),C))::Hom(A,hom(B,C)) <= (C::Ob)
end

# Monocl category
#################

struct MonoclError <: Exception
  message::String
end

""" Doctrine for Monocl: MONoidal Ontology and Computer Language

A doctrine of monoidal categories derived from the doctrine of cartesian closed
categories with implicit conversion of types.
"""
@signature CartesianClosedCategory(Ob,Hom) => MonoclCategory(Ob,Hom,SubOb) begin
  """ Subobject relation.
  
  The domain type is a subobject (subtype) of the codomain type.
  """
  SubOb(dom::Ob, codom::Ob)::TYPE
  
  # Subcategory of subobject morphisms.
  # XXX: Cannot reuse `id` for subobjects because cannot dispatch on return type.
  subid(A::Ob)::SubOb(A,A)
  compose(f::SubOb(A,B), g::SubOb(B,C))::SubOb(A,C) <= (A::Ob, B::Ob, C::Ob)
  otimes(f::SubOb(A,B), g::SubOb(C,D))::SubOb(otimes(A,C),otimes(B,D)) <=
    (A::Ob, B::Ob, C::Ob, D::Ob)

  """ Coercion morphism of type A to type B.
  """
  coerce(sub::SubOb(A,B))::Hom(A,B) <= (A::Ob, B::Ob)

  """ Constructor for instances of type A with data f: A -> B.
  
  The semantics of this term are:
     compose(construct(f), f) = id(B)
  """
  construct(f::Hom(A,B))::Hom(B,A) <= (A::Ob, B::Ob)
  construct(A::Ob) = construct(delete(A))
end

""" Syntax system for Monocl: MONoidal Ontology and Computer Language
"""
@syntax Monocl(ObExpr,HomExpr,CategoryExpr) MonoclCategory begin
  
  """ Establish subobject relation between two object generators.
  """
  function SubOb(value::Any, A::Ob, B::Ob)
    if !(head(A) == :generator && head(B) == :generator)
      msg = "Cannot construct subobject $A <: $B: subobject generators must contain object generators"
      throw(MonoclError(msg))
    end
    SubOb(value, A, B)
  end

  # TODO: Implicit conversion is not yet implemented, so we have disabled
  # domain checks when composing morphisms!
  compose(f::Hom, g::Hom) = associate_unit(Super.compose(f,g; strict=false), id)
  
  compose(f::SubOb, g::SubOb) = associate_unit(Super.compose(f,g; strict=true), subid)
  
  otimes(A::Ob, B::Ob) = associate_unit(Super.otimes(A,B), munit)
  otimes(f::Hom, g::Hom) = associate(Super.otimes(f,g))
  otimes(f::SubOb, g::SubOb) = associate(Super.otimes(f,g))
  
  # TODO: Enforce pre-order, not just reflexivity.
  coerce(sub::SubOb) = dom(sub) == codom(sub) ? id(dom(sub)) : Super.coerce(sub)
end

""" Subobject generator with no name.
"""
SubOb(dom::Monocl.Ob, codom::Monocl.Ob) = SubOb(nothing, dom, codom)

""" Pairing of two (or more) morphisms.

Pairing is possible in any cartesian category. This method differs from the
standard Catlab definition by allowing coercion of the common domain object.
"""
function pair(A::Monocl.Ob, fs::Vector{Monocl.Hom})
  compose(mcopy(A,length(fs)), otimes(fs))
end
function pair(fs::Vector{Monocl.Hom})
  A = dom(first(fs))
  @assert all(dom(f) == A for f in fs)
  pair(A, fs)
end
pair(A::Monocl.Ob, fs::Vararg{Monocl.Hom}) = pair(A, collect(Monocl.Hom,fs))
pair(fs::Vararg{Monocl.Hom}) = pair(collect(Monocl.Hom,fs))

# Monocl wiring diagrams
########################

function Box(f::Monocl.Hom)
  Box(f, collect(dom(f)), collect(codom(f)))
end
function WiringDiagram(dom::Monocl.Ob, codom::Monocl.Ob)
  WiringDiagram(collect(dom), collect(codom))
end

function to_wiring_diagram(expr::Monocl.Hom)
  functor((Ports, WiringDiagram, Monocl.SubOb), expr;
    terms = Dict(
      :Ob => (expr) -> Ports([expr]),
      :Hom => (expr) -> WiringDiagram(expr),
      :SubOb => identity,
      :coerce => (expr) -> to_wiring_diagram(first(expr)),
      :construct => (expr) -> WiringDiagram(expr),
    )
  )
end

function to_wiring_diagram(sub::Monocl.SubOb)
  A, B = collect(dom(sub)), collect(codom(sub))
  @assert length(A) == length(B)
  f = WiringDiagram(A, B)
  add_wires!(f, ((input_id(f),i) => (output_id(f),i) for i in eachindex(A)))
  return f
end

# Graphviz support.
GraphvizWiring.label(box::Box{Monocl.Hom{:coerce}}) = "to"
GraphvizWiring.node_id(box::Box{Monocl.Hom{:coerce}}) = ":coerce"

GraphvizWiring.label(box::Box{Monocl.Hom{:construct}}) = string(codom(box.value))
GraphvizWiring.node_id(box::Box{Monocl.Hom{:construct}}) = ":construct"

# TikZ support.
function TikZWiring.box(name::String, f::Monocl.Hom{:generator})
  TikZWiring.rect(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:mcopy})
  TikZWiring.junction_circle(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:delete})
  TikZWiring.junction_circle(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:coerce})
  TikZWiring.trapezium(
    name,
    "to",
    TikZWiring.wires(dom(f)),
    TikZWiring.wires(codom(f))
  )
end
function TikZWiring.box(name::String, f::Monocl.Hom{:construct})
  TikZWiring.rect(
    name,
    string(codom(f)),
    TikZWiring.wires(dom(f)),
    TikZWiring.wires(codom(f))
  )
end

end
