# for pseudo_basis, basis_pmat, etc. see NfRel/NfRelOrdIdl.jl

################################################################################
#
#  Basic field access
#
################################################################################

doc"""
***
    order(a::NfRelOrdFracIdl) -> NfRelOrd

> Returns the order of $a$.
"""
order(a::NfRelOrdFracIdl) = a.order

doc"""
***
    nf(a::NfRelOrdFracIdl) -> RelativeExtension

> Returns the number field, of which $a$ is an fractional ideal.
"""
nf(a::NfRelOrdFracIdl) = nf(order(a))

################################################################################
#
#  Parent
#
################################################################################

parent(a::NfRelOrdFracIdl) = a.parent

################################################################################
#
#  Numerator and Denominator
#
################################################################################

function assure_has_denominator(a::NfRelOrdFracIdl)
  if isdefined(a, :den)
    return nothing
  end
  O = order(a)
  n = degree(O)
  PM = basis_pmat(a, Val{false})
  pb = pseudo_basis(O, Val{false})
  inv_coeff_ideals = Hecke.inv_coeff_ideals(O, Val{false})
  d = fmpz(1)
  for i = 1:n
    for j = 1:i
      d = lcm(d, denominator(simplify(PM.matrix[i, j]*PM.coeffs[i]*inv_coeff_ideals[j])))
    end
  end
  a.den = d
  return nothing
end

doc"""
***
    denominator(a::NfRelOrdFracIdl) -> fmpz

> Returns the smallest positive integer $d$ such that $da$ is contained in
> the order of $a$.
"""
function denominator(a::NfRelOrdFracIdl)
  assure_has_denominator(a)
  return a.den
end

doc"""
***
    numerator(a::NfRelOrdFracIdl) -> NfRelOrdIdl

> Returns the ideal $d*a$ where $d$ is the denominator of $a$.
"""
function numerator(a::NfRelOrdFracIdl)
  d = denominator(a)
  PM = basis_pmat(a)
  if isone(d)
    return NfRelOrdIdl{typeof(a).parameters...}(order(a), PM)
  end
  for i = 1:degree(order(a))
    PM.coeffs[i] = PM.coeffs[i]*d
    PM.coeffs[i] = simplify(PM.coeffs[i])
  end
  PM = pseudo_hnf(PM, :lowerleft)
  return NfRelOrdIdl{typeof(a).parameters...}(order(a), PM)
end

################################################################################
#
#  String I/O
#
################################################################################

function show(io::IO, s::NfRelOrdFracIdlSet)
  print(io, "Set of fractional ideals of ")
  print(io, s.order)
end

function show(io::IO, a::NfRelOrdFracIdl)
  compact = get(io, :compact, false)
  if compact
    print(io, "Fractional ideal with basis pseudo-matrix\n")
    showcompact(io, basis_pmat(a, Val{false}))
  else
    print(io, "Fractional ideal of\n")
    showcompact(order(a))
    print(io, "\nwith basis pseudo-matrix\n")
    showcompact(io, basis_pmat(a, Val{false}))
  end
end

################################################################################
#
#  Construction
#
################################################################################

doc"""
***
    frac_ideal(O::NfRelOrd, M::PMat) -> NfRelOrdFracIdl

> Creates the fractional ideal of $\mathcal O$ with basis pseudo-matrix $M$.
"""
function frac_ideal(O::NfRelOrd{T, S}, M::PMat{T, S}) where {T, S}
  H = pseudo_hnf(M, :lowerleft, true)
  return NfRelOrdFracIdl{T, S}(O, H)
end

doc"""
***
    frac_ideal(O::NfRelOrd, M::Generic.Mat) -> NfRelOrdFracIdl

> Creates the fractional ideal of $\mathcal O$ with basis matrix $M$.
"""
function frac_ideal(O::NfRelOrd{T, S}, M::Generic.Mat{T}) where {T, S}
  coeffs = deepcopy(basis_pmat(O, Val{false})).coeffs
  return frac_ideal(O, PseudoMatrix(M, coeffs))
end

function frac_ideal(O::NfRelOrd{T, S}, x::RelativeElement{T}) where {T, S}
  d = degree(O)
  pb = pseudo_basis(O, Val{false})
  M = zero_matrix(base_ring(nf(O)), d, d)
  for i = 1:d
    elem_to_mat_row!(M, i, pb[i][1]*x)
  end
  M = M*basis_mat_inv(O, Val{false})
  PM = PseudoMatrix(M, [ deepcopy(pb[i][2]) for i = 1:d ])
  PM = pseudo_hnf(PM, :lowerleft)
  return NfRelOrdFracIdl{T, S}(O, PM)
end

*(O::NfRelOrd{T, S}, x::RelativeElement{T}) where {T, S} = frac_ideal(O, x)

*(x::RelativeElement{T}, O::NfRelOrd{T, S}) where {T, S} = frac_ideal(O, x)

################################################################################
#
#  Deepcopy
#
################################################################################

function Base.deepcopy_internal(a::NfRelOrdFracIdl{T, S}, dict::ObjectIdDict) where {T, S}
  z = NfRelOrdFracIdl{T, S}(a.order)
  for x in fieldnames(a)
    if x != :order && x != :parent && isdefined(a, x)
      setfield!(z, x, Base.deepcopy_internal(getfield(a, x), dict))
    end
  end
  z.order = a.order
  z.parent = a.parent
  return z
end

################################################################################
#
#  Equality
#
################################################################################

doc"""
***
    ==(a::NfOrdRelFracIdl, b::NfRelOrdFracIdl) -> Bool

> Returns whether $a$ and $b$ are equal.
"""
function ==(a::NfRelOrdFracIdl, b::NfRelOrdFracIdl)
  order(a) != order(b) && return false
  return basis_pmat(a, Val{false}) == basis_pmat(b, Val{false})
end

################################################################################
#
#  Norm
#
################################################################################

# Assumes, that det(basis_mat(a)) == 1
function assure_has_norm(a::NfRelOrdFracIdl)
  if a.has_norm
    return nothing
  end
  c = basis_pmat(a, Val{false}).coeffs
  d = inv_coeff_ideals(order(a), Val{false})
  n = c[1]*d[1]
  for i = 2:degree(order(a))
    n *= c[i]*d[i]
  end
  simplify(n)
  a.norm = n
  a.has_norm = true
  return nothing
end

doc"""
***
    norm(a::NfRelOrdFracIdl{T, S}) -> S

> Returns the norm of $a$
"""
function norm(a::NfRelOrdFracIdl, copy::Type{Val{T}} = Val{true}) where T
  assure_has_norm(a)
  if copy == Val{true}
    return deepcopy(a.norm)
  else
    return a.norm
  end
end

################################################################################
#
#  Ad hoc multiplication
#
################################################################################

function *(a::NfRelOrdFracIdl{T, S}, b::RelativeElement{T}) where {T, S}
  c = b*order(a)
  return c*a
end

*(b::RelativeElement{T}, a::NfRelOrdFracIdl{T, S}) where {T, S} = a*b

function *(a::NfRelOrdFracIdl, b::fmpz)
  PM = basis_pmat(a)
  for i = 1:degree(order(a))
    PM.coeffs[i].num = numerator(PM.coeffs[i])*b
    PM.coeffs[i] = simplify(PM.coeffs[i])
  end
  PM = pseudo_hnf(PM, :lowerleft)
  return typeof(a)(order(a), PM)
end

*(b::fmpz, a::NfRelOrdFracIdl) = a*b

################################################################################
#
#  Integral ideal testing
#
################################################################################

isintegral(a::NfRelOrdFracIdl) = defines_ideal(order(a), basis_pmat(a, Val{false}))

################################################################################
#
#  "Simplification"
#
################################################################################

# The basis_pmat of a NfRelOrdFracIdl should be in pseudo hnf, so it should already
# be "simple". Maybe we could simplify the coefficient ideals?
simplify(a::NfRelOrdFracIdl) = a

################################################################################
#
#  Reduction of element modulo ideal
#
################################################################################

function mod(x::S, y::T) where {S <: Union{nf_elem, RelativeElement}, T <: Union{NfOrdFracIdl, NfRelOrdFracIdl}}
  K = parent(x)
  O = order(y)
  d = K(lcm(denominator(x, O), denominator(y)))
  dx = d*x
  dy = d*y
  if T == NfOrdFracIdl
    dy = simplify(dy)
    dynum = numerator(dy)
  else
    dynum = NfRelOrdIdl{T.parameters...}(O, basis_pmat(dy, Val{false}))
  end
  dz = mod(O(dx), dynum)
  z = divexact(K(dz), d)
  return z
end

################################################################################
#
#  Inclusion of elements in ideals
#
################################################################################

doc"""
***
    in(x::RelativeElement, y::NfRelOrdFracIdl)

> Returns whether $x$ is contained in $y$.
"""
function in(x::RelativeElement, y::NfRelOrdFracIdl)
  parent(x) != nf(order(y)) && error("Number field of element and ideal must be equal")
  O = order(y)
  b_pmat = basis_pmat(y, Val{false})
  t = zero_matrix(base_ring(nf(O)), 1, degree(O))
  elem_to_mat_row!(t, 1, x)
  t = t*basis_mat_inv(O, Val{false})
  t = t*basis_mat_inv(y, Val{false})
  for i = 1:degree(O)
    if !(t[1, i] in b_pmat.coeffs[i])
      return false
    end
  end
  return true
end

################################################################################
#
#  Valuation
#
################################################################################

function valuation(A::NfRelOrdFracIdl, P::NfRelOrdIdl)
  return valuation(numerator(A), P) - valuation(denominator(A), P)
end

function valuation_naive(a::RelativeElement, P::NfRelOrdIdl)
  @assert !iszero(a)
  return valuation(a*order(P), P)
end

valuation(a::RelativeElement, P::NfRelOrdIdl) = valuation_naive(a, P)

################################################################################
#
#  Random elements
#
################################################################################

function rand(a::NfRelOrdFracIdl, B::Int)
  pb = pseudo_basis(a, Val{false})
  z = nf(order(a))()
  for i = 1:degree(order(a))
    t = rand(pb[i][2], B)
    z += t*pb[i][1]
  end
  return z
end
