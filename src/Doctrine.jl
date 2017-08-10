module Doctrine
export Monocl, MonoclCategory

using Catlab
using Catlab.Doctrine: ObExpr, HomExpr, SymmetricMonoidalCategory
import Catlab.Doctrine: dom, codom, compose, id, otimes, munit, braid,
  mcopy, delete, pair, hom, ev, curry

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
  pair(fs::Vararg{Hom}) = compose(mcopy(A,length(fs)), otimes(fs...))
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

""" Doctrine for Monocl: MONoidal Ontology and Computer Language

A doctrine of monoidal categories derived from the doctrine of cartesian closed
categories.
"""
@signature CartesianClosedCategory(Ob,Hom) => MonoclCategory(Ob,Hom) begin
  constructor(A, f::Hom(A,B))::Hom(B,A) <= (A::Ob, B::Ob)
end

""" Syntax system for Monocl: MONoidal Ontology and Computer Language
"""
#@syntax Monocl(ObExpr,HomExpr) MonoclCategory begin
#
#end

end
