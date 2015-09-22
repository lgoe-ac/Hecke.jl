import Base: ceil, log, -, <, <=, vcat, sum, ^, &, +, /

export dickman_rho, bach_rho, bach_G, bach_F, logarithmic_integral, exponential_integral, li, ei

#= source: http://cr.yp.to/bib/1996/bach-semismooth.pdf

  idea is that
  n = prod n_i
  and n_1>= n_2 >= ...
  Psi(x, B) = #{ 0<n<x | n is B-smooth} = #{ n | n_1<= B}
  Psi(x, A, B) = # {0<n<x | n_1 <= A, n_2 <= B}

  then

  Psi(x, x^1/u) = x*dickman_rho(u)
  Psi(x, x^1/u, x^1/v) = x * bach_rho(v, u)

  OK, the "=" is an approximation

  bach_rho can be used to estimate the large-prime-variant

  The explicit 55 should be linked to the actual precision desired.
  It should be enough for dickman_rho to guarantee doubles (53 bits)
  In the paper Bach used 21 for the bach_rho function

  In the values tested, the results agree with Magma (DickmanRho) and
  the paper for bach_rho

  The program is terribly inefficient in the bash_rho (bach_J) part.
  Lots of powers are computed over and over again.
=#

type analytic_func{T<:Number}
  coeff::Array{T, 1}
  valid::Tuple{T, T}
  function analytic_func()
    return new()
  end
end


function rho_coeff{T<: Number}(x::T, prec = 55)
  a = analytic_func{T}()
  k = ceil(x)
  a.coeff = vcat([ 1-log(T(2))] ,
                [1/(i*T(2)^i) for i=1:prec])
  a.valid=(1,2)
  while k>a.valid[2]
    d = [ sum([a.coeff[j+1]/(i*(a.valid[2]+1)^(i-j)) for j=0:(i-1) ])  for i=1:prec]
    d = vcat([1/(a.valid[2]) * sum([d[j]/(j+1) for j=1:prec ])] , d)
    a.coeff = d
    a.valid = (a.valid[1]+1, a.valid[2]+1)
  end
  return a
end

function analytic_eval{T<:Number}(a::analytic_func{T}, b::T)
  s = T(0)
  for i=length(a.coeff):-1:1
    s = s*b + a.coeff[i]
  end
  return s
end
 
function dickman_rho(x::Number, prec=55)
  if x < 0
    error("argument must be positive")
  end

  if x<= 1
    return typeof(x)(1)
  end

  if x <= 2
    return 1-log(x)
  end
  
  k = ceil(x)
  return analytic_eval(rho_coeff(x, prec), k-x)
end

function bach_F{T<: Number}(x::T)
  return dickman_rho(1/x)
end

function bach_rho{T<:Number}(a::T, b::T, prec = 21)
  if b>a || a<0 || b <0
    error("wrong values")
  end
  if a <1
    return T(1)
  end
  return dickman_rho(a, prec) + bach_J(a, b, a, prec)
end

function bach_G(a,b)
  return bach_rho(1/a, 1/b)
end

function bach_J{T<:Number}(u::T, v::T, w::T, prec)
  k = ceil(w-w/u)
  function xi(t::T)
    return k-w+w/t
  end

  if xi(v) <= 1 
    local A = w/v+k-w,
          B = w/u+k-w,
          C = k-w
    function H_i(u::T, v::T, w::T, i::Int)
      return C^i*(log(u/v) + sum([(A/C)^j/j for j=1:i]) -
                             sum([(B/C)^j/j for j=1:i]))
    end
    a = rho_coeff(k*1.0, prec)
    return sum([a.coeff[i+1] * H_i(u, v, w, i) for i=0:(length(a.coeff)-1)])
  else
    #println("recurse: k = ", Int(k))
    return bach_J(w/(w-k+1), v, w, prec) + bach_J(u, w/(w-k+1), w, prec)
  end
end

#the function Ei = -integral(-x, infty, exp(-t)/t dt)

@doc """
  exponential_integral(x::FloatingPoint) -> FloatingPoint
  ei(x::FloatingPoint) -> FloatingPoint

  Compute the exponential integral function
""" ->
function exponential_integral(x::BigFloat)
  z = BigFloat()
  ccall((:mpfr_eint, :libmpfr), Int32, (Ptr{BigFloat}, Ptr{BigFloat}, Int32), &z, &x, Base.MPFR.ROUNDING_MODE[end])
  return z
end

function exponential_integral{T<:FloatingPoint}(x::T)
  return T(exponential_integral(BigFloat(x)))
end

#the function li = integral(0, x, dt/log(t))
#             li(x) = Ei(log(x)) according to wiki and ?
@doc """
  logarithmic_integral(x::FloatingPoint) -> FloatingPoint
  li(x::FloatingPoint) -> FloatingPoint

  Compute the logarithmic integral function. Used as an approximation
  for the number of primes up to x
""" ->

function logarithmic_integral(x::FloatingPoint)
  return exponential_integral(log(x))
end

const ei = exponential_integral
const li = logarithmic_integral


#=
From Feller:An Introduction to Probability Theory and Its Applications vol1
Chapter IX, Question 18
The formula (for n=365) is in the solutions.
=#

@doc """
  rels_from_partial(n::Int, k::Int) -> Int

  Estimates the number of collision in k samples among n possibilities. Used 
  to estimate the number of full relations to be expected from k partial
  relations involving n (large) primes
""" ->
function rels_from_partial(n::Int, k::Int) 
  N = fmpz(n)
  return Int(round(N*(1-(N-1)^k//N^k-k*(N-1)^(k-1)//N^k)))
end


#=
Let p_i,j = 1 if the i-th and j-th person have the same birthday and 0 
otherwise.
We need
  W = E(sum p_i,j)
the expectation of the sum, how many birthdays are common.
Then 
  lambda = k(k-1)/(2n)
  the expectation is lambda as this should be Poisson distributed
  P(W=x) = exp(-l)l^x/x!
=#  

@doc """
  euler_phi(n::Int) -> Int

  The Euler ϕ function of n
  Ie. the number of integers 0<= i = n coprime to n
""" ->

function euler_phi(a::Int)
  f = factor(a)
  e = 1
  for p=keys(f)
    e *= (p-1)*p^(f[p]-1)
  end
  return e
end 

#= computes (hopefully) the 
  vol(prod x_i <= b meet [0,1]^n)
an easy excercise in induction...
  vol = b(sum_1^{n-1} (-1)^k/k! log(b)^k)
=#

function vol{T<:Number}(n::Int, b::T)
  lb = log(b)
  s = [typeof(b)(1)]
  t = typeof(b)(1)
  for k = 1:n-1
    t  = -t/k * lb
    push!(s, t)
  end
  return b*sum(s)
end

#= D is supposed to be the disccriminant
   n the dimension
   B1 the bound for the factor base
   B2 the bound for the large primes
   steps the number of steps in the integration

Computes s.th. like
  sum (vol(l^i) - vol(l^-1)) rho(

The idea is that we basically generate elements of small, bounded, T2 norm
in the number field. The naive estimate (Arithmetic-geometric) shows that
we expect a norm <= sqrt(D).
But frequently this is smaller.
We re-scalee the fundamental epiped to be [0,1]^n and assume the
norm is still prod x_i (which is "true" for totally real and need
though otherwise). The we try to cound elements of norm <= l^i
for l^i = 1..sqrt D by assuming the proportion is thus the volume
of above.
The dickman_rho or bach_rho functions are then used to estimate the
number of smooth elements among those.

Idea due to Steve Donnelly

experimentally: this might be true, but it depends very much on the sampling
tool:
  for a (fixed) (lll) basis of max real 512 and lin. comb of
  n elements with coeff. in 0,1
  the norms are (roughly) normally distributed with the centre
  less than (2*sqrt(n))^128
  I assume that comes in part from the distribution of the
  conjugates themselves. They are bounded by 2, but the mean is less...

  The norm is the product of the conjugates. If the cojugates are reasonably
  distributed then the central limit theorem should imply that the norms
  are normalily distributed.

  Steve's idea is (probably) correct if one samples in the entire lattice,
  represented by taking few elements of a basis and then changing the basis
=#

function expected_yield(D::fmpz, n::Int, B1::Integer, B2::Integer=0, steps::Int=20)
  lD = log(abs(D))/2
  l = lD/steps

  lB1 = log(B1)
  if B2 != 1
    lB2 = log(B2)
  end

  v_l1 = 0
  yield = 0
  s = []
  for i=1:steps
    v_l = vol(n, exp(i*l-lD))
    b = i*l/lB1
    if b<1 
      b = typeof(b)(1) 
    end
    if b > 15
      println(" argument to dickmann too largee to make sense")
      break
    end
    if B2 == 0
     #elts have norm <= exp(i*l)
      r = dickman_rho(b)
    else
      b2 = i*l/lB2
      if b2<1 
        b2 = typeof(b)(1) 
      end
#      println("Calling bach with", Float64(b), " and ", Float64(b2))
      r = bach_rho(b, b2)
    end
               
    push!(s, (v_l-v_l1)*r)
    v_l1 = v_l
  end
  
  return s
end
