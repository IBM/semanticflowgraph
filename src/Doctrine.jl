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

module Doctrine
export Monocl, ThMonocl, MonoclError, Ob, Hom, SubOb, SubHom,
  dom, codom, subob_dom, subob_codom, subob_id, subhom_id,
  compose, compose2, id, otimes, munit, opow, braid, mcopy, delete, pair,
  hom, ev, curry, coerce, construct, MonoclElem, to_wiring_diagram

using StructEquality

using Catlab
import Catlab.Theories: CategoryExpr, ObExpr, HomExpr,
  ThSymmetricMonoidalCategory, Ob, Hom, dom, codom, compose, id, otimes, munit,
  braid, mcopy, delete, pair, hom, ev, curry

using Catlab.WiringDiagrams
import Catlab.WiringDiagrams: Box, WiringDiagram, to_wiring_diagram

# Cartesian (closed) category
#############################

""" Doctrine of *cartesian category*

This signature differs from the official Catlab doctrine by allowing `mcopy`
terms of size greater than 2.
"""
@signature ThCartesianCategory{Ob,Hom} <: ThSymmetricMonoidalCategory{Ob,Hom} begin
  opow(A::Ob, n::Int)::Ob

  mcopy(A::Ob, n::Int)::Hom(A,opow(A,n))
  delete(A::Ob)::Hom(A,munit())
end

""" Doctrine of *cartesian closed category*

This signature is identical to the official Catlab doctrine, except for
inheriting from a different doctrine.
"""
@signature ThCartesianClosedCategory{Ob,Hom} <: ThCartesianCategory{Ob,Hom} begin
  hom(A::Ob, B::Ob)::Ob
  ev(A::Ob, B::Ob)::Hom(otimes(hom(A,B),A),B)
  curry(A::Ob, B::Ob, f::Hom(otimes(A,B),C))::Hom(A,hom(B,C)) ⊣ (C::Ob)
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
@signature ThMonocl{Ob,Hom,SubOb,SubHom} <: ThCartesianClosedCategory{Ob,Hom} begin
  """ Subobject relation.
  
  The domain object is a subobject of the codomain object. Alternatively,
  in PLT jargon, the domain type is a subtype of the codomain type.
  """
  SubOb(dom::Ob, codom::Ob)::TYPE
  
  """ Submorphism relation.
  
  The domain morphism is a submorphism of the codomain morphism. This means
  there is a natural transformation, whose components are subobject morphisms,
  having as (co)domain the functor on the interval category determined by the
  (co)domain morphism.
  
  Alternatively, in PLT jargon, the domain function is a specialization of the
  codomain function, a form of ad-hoc polymorphism.
  """
  SubHom(dom::Hom(A0,B0), codom::Hom(A,B),
         subob_dom::SubOb(A0,A), subob_codom::SubOb(B0,B))::TYPE ⊣
    (A0::Ob, B0::Ob, A::Ob, B::Ob)

  """ Coercion morphism of type A to type B.
  """
  coerce(sub::SubOb(A,B))::Hom(A,B) ⊣ (A::Ob, B::Ob)

  """ Constructor for instances of type A with data f: A -> B.
  
  The semantics of this term are:
     compose(construct(f), f) = id(B)
  """
  construct(f::Hom(A,B))::Hom(B,A) ⊣ (A::Ob, B::Ob)
  
  # Category of subobject morphisms.
  # TODO: Support internal homs.
  # XXX: Cannot reuse `id` for subobjects because cannot dispatch on return type.
  subob_id(A::Ob)::SubOb(A,A)
  compose(f::SubOb(A,B), g::SubOb(B,C))::SubOb(A,C) ⊣ (A::Ob, B::Ob, C::Ob)
  otimes(f::SubOb(A,B), g::SubOb(C,D))::SubOb(otimes(A,C),otimes(B,D)) ⊣
    (A::Ob, B::Ob, C::Ob, D::Ob)
  
  # 2-category of submorphism natural transformations.
  subhom_id(f::Hom(A,B))::SubHom(f,f,subob_id(dom(f)),subob_id(codom(f))) ⊣
    (A::Ob, B::Ob)
  compose(α::SubHom(f,g,α0,α1), β::SubHom(g,h,β0,β1))::SubHom(f,h,compose(α0,β0),compose(α1,β1)) ⊣
    (A0::Ob, B0::Ob, A::Ob, B::Ob, A1::Ob, B1::Ob,
     f::Hom(A0,B0), g::Hom(A,B), h::Hom(A1,B1),
     α0::SubOb(A0,A), α1::SubOb(B0,B), β0::SubOb(A,A1), β1::SubOb(B,B1))
  compose2(α::SubHom(f,g,α0,α1), β::SubHom(h,k,β0,β1))::SubHom(compose(f,h),compose(g,k),α0,β1) ⊣
    (A0::Ob, B0::Ob, C0::Ob, A::Ob, B::Ob, C::Ob,
     f::Hom(A0,B0), g::Hom(A,B), h::Hom(B0,C0), k::Hom(B,C),
     α0::SubOb(A0,A), α1::SubOb(B0,B), β0::SubOb(B0,B), β1::SubOb(C0,C))
end

""" Syntax system for Monocl: MONoidal Ontology and Computer Language
"""
@syntax Monocl{ObExpr,HomExpr,CategoryExpr,CategoryExpr} ThMonocl begin
  # TODO: Implicit conversion is not yet implemented, so we have disabled
  # domain checks when composing morphisms!
  # TODO: Domain checks when composing submorphisms need only check domain
  # and codomain of subobjects because subobjects form a pre-order.
  compose(f::Hom, g::Hom) = associate_unit(new(f,g; strict=false), id)
  compose(f::SubOb, g::SubOb) = associate_unit(new(f,g; strict=true), subob_id)
  compose(f::SubHom, g::SubHom) = associate_unit(new(f,g; strict=false), subhom_id)
  compose2(f::SubHom, g::SubHom) = associate_unit(new(f,g; strict=false), subhom_id)
  
  otimes(A::Ob, B::Ob) = associate_unit(new(A,B), munit)
  otimes(f::Hom, g::Hom) = associate(new(f,g))
  otimes(f::SubOb, g::SubOb) = associate(new(f,g))
  opow(A::Ob, n::Int) = otimes([A for i=1:n])
  
  # TODO: Enforce pre-order, not just reflexivity.
  coerce(sub::SubOb) = dom(sub) == codom(sub) ? id(dom(sub)) : new(sub)
end

SubOb(dom::Monocl.Ob, codom::Monocl.Ob) = SubOb(nothing, dom, codom)
SubHom(dom::Monocl.Hom, codom::Monocl.Hom,
       subob_dom::Monocl.SubOb, subob_codom::Monocl.SubOb) =
  SubHom(nothing, dom, codom, subob_dom, subob_codom)

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

mcopy(A::Monocl.Ob) = mcopy(A,2)
construct(A::Monocl.Ob) = construct(delete(A))

# Monocl category of elements
#############################

""" Object in Monocl's category of elements.
"""
@struct_hash_equal struct MonoclElem
  ob::Union{Monocl.Ob,Nothing}
  value::Any
  MonoclElem(ob, value=nothing) = new(ob, value)
end

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
      :Hom => (expr) -> singleton_diagram(Box(expr)),
      :SubOb => identity,
      :coerce => (expr) -> to_wiring_diagram(first(expr)),
      :construct => (expr) -> singleton_diagram(Box(expr)),
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

end
