module Doctrine
export Monocl, MonoclCategory, Ob, Hom, dom, codom, compose, id, otimes, munit,
  opow, braid, mcopy, delete, pair, hom, ev, curry, coerce, construct

using Catlab
using Catlab.Doctrine: ObExpr, HomExpr, SymmetricMonoidalCategory
import Catlab.Doctrine: Ob, Hom, dom, codom, compose, id, otimes, munit,
  braid, mcopy, delete, pair, hom, ev, curry

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

""" Doctrine for Monocl: MONoidal Ontology and Computer Language

A doctrine of monoidal categories derived from the doctrine of cartesian closed
categories with implicit conversion of types.
"""
@signature CartesianClosedCategory(Ob,Hom) => MonoclCategory(Ob,Hom) begin
  """ Coercion, aka implicit conversion, of type A to type B.
  """
  coerce(A::Ob, B::Ob)::Hom(A,B)

  """ Constructor for instances of type A with data f: A -> B.
  
  The semantics of this term are:
     compose(construct(f), f) = id(B)
  """
  construct(f::Hom(A,B))::Hom(B,A) <= (A::Ob, B::Ob)
  construct(A::Ob) = construct(delete(A))
end

""" Syntax system for Monocl: MONoidal Ontology and Computer Language
"""
@syntax Monocl(ObExpr,HomExpr) MonoclCategory begin
  # XXX: Implicit conversion is not yet implemented, so we have disabled
  # domain checks when composing morphisms!
  compose(f::Hom, g::Hom) = associate_unit(Super.compose(f,g; strict=false), id)
  
  otimes(A::Ob, B::Ob) = associate_unit(Super.otimes(A,B), munit)
  otimes(f::Hom, g::Hom) = associate(Super.otimes(f,g))
  
  # TODO: Enforce pre-order, not just transitivity.
  coerce(A::Ob, B::Ob) = A == B ? id(A) : Super.coerce(A,B)
end

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

end
