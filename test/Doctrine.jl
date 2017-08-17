module TestDoctrine
using Base.Test

using Catlab
using OpenDiscCore.Doctrine

# Monocl category
#################

A, B, C = Ob(Monocl, :A, :B, :C)
A0, B0, A1, B1 = Ob(Monocl, :A0, :B0, :A1, :B1)
I = munit(Monocl.Ob)
f = Hom(:f, A, B)
g = Hom(:f, A, C)

# Subobjects
subA = SubOb(A0, A)
subB = SubOb(B0, B)
@test dom(subA) == A0
@test codom(subA) == A
@test_throws MonoclError SubOb(otimes(A,B), C)
@test_throws MonoclError SubOb(A,I)

sub = compose(SubOb(A0, A), SubOb(A, A1))
@test dom(sub) == A0
@test codom(sub) == A1
@test dom(subid(A)) == A
@test codom(subid(A)) == A
@test_throws SyntaxDomainError compose(subA, subB)

sub = otimes(subA, subB)
@test dom(sub) == otimes(A0,B0)
@test codom(sub) == otimes(A,B)

# Coercion
@test dom(coerce(subA)) == A0
@test codom(coerce(subA)) == A
@test coerce(subid(A)) == id(A)
@test compose(coerce(subid(A)), f) == f
@test compose(f, coerce(subid(B))) == f

# Constructors
@test dom(construct(A)) == I
@test codom(construct(A)) == A
@test dom(construct(f)) == B
@test codom(construct(f)) == A

# Pair
@test dom(pair(f,g)) == A
@test codom(pair(f,g)) == otimes(B,C)
@test pair(f,g) == compose(mcopy(A), otimes(f,g))
@test dom(pair(A0,f,g)) == A0
@test codom(pair(A0,f,g)) == otimes(B,C)

end
