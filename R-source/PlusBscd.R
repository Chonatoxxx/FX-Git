#|------------------------------------------------------------------------------------------|
#|                                                                               PlusBscd.R |
#|                                                             Copyright � 2012, Dennis Lee |
#| Motivation                                                                               |
#|    In Coursera's Financial Engineering and Risk Management (FERM) course, Prof. Haugh    |
#|  uses an Excel spreadsheet to specify and build a binomial tree model in terms of Black- |
#|  Scholes parameters. The model can then be used to price European and American options   |
#|  for EITHER an underlying stock OR futures. Note that the binomial tree model price      |
#|  converges to Black-Scholes price as n (the number of periods) approaches INFINITY (oo). |
#|                                                                                          |
#| Background                                                                               |
#|    The R Markdown file "Haugh_01_black-scholes_fOptions.Rmd" provides a detailed         |
#|  explanation of the binomial tree model specification in terms of Black-Scholes          |
#|  parameters.                                                                             |
#|                                                                                          |
#| Function                                                                                 |
#|    (1) The function BscdCreateModel() accepts FIVE (5) parameters as follows:            |
#|        (i)   r     - the continuously compounded interest rate;                          |
#|        (ii)  b     - the annualized dividend yield (OR cost-of-carry rate) of the        |
#|                      underlying security;                                                |
#|        (iii) n     - the number of periods;                                              |
#|        (iv)  Time  - time to maturity measured in years, e.g. 0.5 means 6 months;        |
#|        (v)   sigma - the annualized volatility of the underlying security, e.g. 0.3      |
#|                      means 30% volatility p.a.                                           |
#|      The function returns an object of class "Bscd", i.e. Black-Scholes Discrete class,  |
#|    that consists of several variables, e.g. q, u, d, etc, and TWO (2) matrices: (a)      |
#|    stock price rates lattice; and (b) futures price rates lattice. These matrices are    |
#|    based on an initial value of ONE (1) and could be used to construct option binomial   |
#|    tree prices. To obtain the actual prices, just multiply the matrix by the initial     |
#|    value S, e.g. 100*sRateMtx.                                                           |
#|                                                                                          |
#|    (2) The function BscdOptionPrice() accepts FIVE (5) parameters as follows:            |
#|        (i)   model     - the Black-Scholes Discrete model;                               |
#|        (ii)  S         - the initial price of the underlying security;                   |
#|        (iii) X         - the strike price;                                               |
#|        (iv)  n         - the number of periods for the option (default: NULL means the   |
#|                          same number of periods as underlying security);                 |
#|        (v)   TypeFlag  - a character vector for ONE (1) or MORE option types:            |
#|                          (1) "ce": European call; (2) "pe": European put;                |
#|                          (3) "ca": American call; (4) "pa": American put.                |
#|      The function returns a list containing the specified number of option binomial tree |
#|    prices as matrices. The option price is the value in FIRST row and FIRST column of    |
#|    EACH matrix.                                                                          |
#|                                                                                          |
#| Example Usage                                                                            |
#|    (a) Create a FIFTEEN(15)-period model that can be used to price an option:            |
#|    > model.bscd  <- BscdCreateModel(0.02, 0.01, 15, 0.25, 0.3)                           |
#|    > options     <- BscdOptionPrice(model.bscd, 100, 100)                                |
#|    > str(options)                                                                        |
#|                                                                                          |
#|    (b) Using the same model as above, we can then price a TEN(10)-period chooser:        |
#|    > # Column ONE (1) is period ZERO (0), i.e. the value of the option.                  |
#|    > payChooserNum <- apply(cbind(options$ce[,11], options$pe[,11]), 1, max, 0)          |
#|    > payChooserNum <- payChooserNum[1:11]                                                |
#|    > chooserMtx    <- BscdPayTwoLeafMtx( model.bscd$q, payChooserNum, model.bscd$RInv )  |
#|    > head(chooserMtx)                                                                    |
#|                                                                                          |
#| Assert History                                                                           |
#|  0.9.0   This library contains external R functions to specify and build a binomial tree |
#|          model in terms of Black-Scholes parameters. Todo: (a) Construct an early        |
#|          exercise lattice (for American), and (b) create a test script.                  |
#|------------------------------------------------------------------------------------------|

#|------------------------------------------------------------------------------------------|
#|                            E X T E R N A L   F U N C T I O N S                           |
#|------------------------------------------------------------------------------------------|
BscdCreateModel <- function(r, b, n, Time, sigma)
{
  #---  Calculate the risk neutral probabilities (q) and (q-1)
  #       (1) Calculate EACH discrete term used by q
  #       (2) R = exp(r*T/n)
  #       (3) RInv = exp(-r*T/n)
  #       (4) Rb = exp((r-b)*T/n)
  #       (5) u = exp(sigma*sqrt(T/n))
  #       (6) d = 1/u
  #       (7) q = ( R - d )   / ( u - d),   if b = 0
  #           q = ( Rb - d )  / ( u - d ),  if b > 0
  #       (8) qInv = 1 - q
  R     <- exp(r*Time/n)
  RInv  <- exp(-r*Time/n)
  Rb    <- exp((r-b)*Time/n)
  u     <- exp(sigma*sqrt(Time/n))
  d     <- 1/u
  if( b==0 )
    q   <- (R-d)/(u-d)
  if( b>0 )
    q   <- (Rb-d)/(u-d)
  qInv  <- 1 - q
  
  #---  Construct a stock lattice (base) matrix using initial value of ONE (1)
  #       (1) matrix n1 x n1, where n1=n+1 because of initial term at n=0
  #       (2)   1         2         3         4
  #           1 u^0*d^0   u^1*d^0   u^2*d^0   u^3*d^0
  #           2           u^0*d^1   u^1*d^1   u^2*d^1
  #           3                     u^0*d^2   u^1*d^2
  #           4                               u^0*d^3
  n1 <- n+1
  basMtx <- matrix( rep(0, n1*n1), nrow=n1, ncol=n1)
  for( i in 1:nrow(basMtx) )
  {
    for( j in i:ncol(basMtx) )
    {
      pd <- i-1
      pu <- j-1-pd
      basMtx[i,j] <- u^pu*d^pd
    }
  }
  
  #---  Construct a futures lattice matrix based on the stock's final payoff at n
  #       (1) Copy last column of basMtx to last column of futMtx
  #       (2) Calculate backwards, starting from the previous column n-1 to 0
  #           using the expected TWO (2) leaf values weighted on risk neutral 
  #           probabilities (q) and (1-q)
  #       (3)   1         2         3         4
  #           1 q*[1,2]+  q*[1,3]+  q*[1,4]+  u^3*d^0
  #             qI*[2,2]  qI*[2.3]  qI*[2,4]  
  #           2           q*[2,3]+  q*[2,4]+  u^2*d^1
  #                       qI*[3,3]  qI*[3,4]
  #           3                     q*[3,4]+  u^1*d^2
  #                                 qI*[4,4]
  #           4                               u^0*d^3
  futMtx <- matrix( rep(0, n1*n1), nrow=n1, ncol=n1)
  futMtx[, n1] <- basMtx[, n1]
  for( j in (n1-1):1 )
  {
    for( i in j:1 )
    {
      ld <- futMtx[i+1, j+1]
      lu <- futMtx[i, j+1]
      futMtx[i,j] <- q*lu+qInv*ld
    }
  }
  
  #---  Return an object of class Bscd, i.e. Black-Scholes Discrete model
  #
  ret.Bscd <- list("r"      = r,
                   "b"      = b,
                   "n"      = n,
                   "n1"     = n1,
                   "Time"   = Time,
                   "sigma"  = sigma,
                   "R"      = R,
                   "RInv"   = RInv,
                   "Rb"     = Rb,
                   "u"      = u,
                   "d"      = d,
                   "q"      = q,
                   "qInv"   = 1 - q,
                   "sRateMtx" = basMtx,
                   "fRateMtx" = futMtx,
                   "fRateNum" = futMtx[1,1]
  )
  class(ret.Bscd) <- "Bscd"
  ret.Bscd
}
BscdOptionPrice <- function( model, S, X, n=NULL, TypeFlag=c("ce", "pe", "ca", "pa") )
{
  #---  Check that arguments are valid
  if( is.null(n) )  
    n <- model$n
  if( n > model$n )
    stop("n CANNOT be greater than model$n")
  typeStr <- c("ce", "pe", "ca", "pa")
  if( length(TypeFlag) == 0 )
    stop("TypeFlag MUST be ONE (1) OR MORE of: ce, pe, ca, pa")
  for( i in 1:length(TypeFlag) )
  {
    if( length(which(typeStr==TypeFlag[i])) == 0 )
      stop("TypeFlag MUST be ONE (1) OR MORE of: ce, pe, ca, pa")
  }
  ceBln <- length(which(typeStr[1]==TypeFlag)) > 0
  peBln <- length(which(typeStr[2]==TypeFlag)) > 0
  caBln <- length(which(typeStr[3]==TypeFlag)) > 0
  paBln <- length(which(typeStr[4]==TypeFlag)) > 0
  
  #---  Construct a stock lattice using model and initial price S
  stockMtx <- model$sRateMtx * S
  
  #---  Construct EACH option lattice
  #       (1) matrix n1 x n1, where n1=n+1 because of initial term at n=0
  #       (2) Calculate the LAST column of typeMtx, where type: ce, pe, ca, pa
  #           using the function max() with arguments ZERO (0) and the difference
  #           in strike price (X) and the corresponding nth column stockMtx price.
  #           For a put option, we need to invert the result of max, i.e. -result.
  #       (3) Calculate backwards, starting from the previous column n-1 to 0
  #           using the expected TWO (2) leaf values weighted on risk neutral 
  #           probabilities (q) and (1-q) scaled by 1/R
  #       (4)   1         2         3         n
  #           1 q*[1,2]+  q*[1,3]+  q*[1,4]+  max((flag*stockMtx[1,n]-X),0)
  #             qI*[2,2]  qI*[2.3]  qI*[2,4]  
  #           2           q*[2,3]+  q*[2,4]+  max((flag*stockMtx[2,n]-X),0)
  #                       qI*[3,3]  qI*[3,4]
  #           3                     q*[3,4]+  max((flag*stockMtx[3,n]-X),0)
  #                                 qI*[4,4]
  #           4                               max((flag*stockMtx[4,n]-X),0)
  n1 <- n+1
  difNum    <- S*model$sRateMtx[, model$n1]-X
  if( ceBln )
  {
    flag      <- 1
    payNum    <- sapply(flag*difNum, max, 0)
    ceMtx     <- BscdPayTwoLeafMtx( model$q, payNum, scalar=model$RInv )
  }
  if( peBln )
  {
    flag      <- -1
    payNum    <- sapply(flag*difNum, max, 0)
    peMtx     <- BscdPayTwoLeafMtx( model$q, payNum, scalar=model$RInv )
  }
  difMtx    <- S*model$sRateMtx-X
  if( caBln )
  {
    flag      <-  1
    payMtx    <- matrix( sapply(flag*difMtx, max, 0), nrow=n1, ncol=n1 )
    caMtx     <- BscdPayTwoLeafAMtx( model$q, payMtx, scalar=model$RInv )
  }
  if( paBln )
  {
    flag      <- -1
    payMtx    <- matrix( sapply(flag*difMtx, max, 0), nrow=n1, ncol=n1 )
    paMtx     <- BscdPayTwoLeafAMtx( model$q, payMtx, scalar=model$RInv )
  }
  retBln <- c( ceBln, peBln, caBln, paBln )
  ret.lst <- vector("list", sum(retBln))
  if( retBln[1] & exists("ceMtx") ) ret.lst <- append.lst( ret.lst, ceMtx )
  if( retBln[2] & exists("peMtx") ) ret.lst <- append.lst( ret.lst, peMtx )
  if( retBln[3] & exists("caMtx") ) ret.lst <- append.lst( ret.lst, caMtx )
  if( retBln[4] & exists("paMtx") ) ret.lst <- append.lst( ret.lst, paMtx )
  names(ret.lst) <- typeStr[which(retBln)]
  ret.lst
}

#|------------------------------------------------------------------------------------------|
#|                            I N T E R N A L   F U N C T I O N S                           |
#|------------------------------------------------------------------------------------------|
BscdPayTwoLeafMtx <- function( q, finalNum, scalar=1 )
{
  qInv        <- 1-q
  n           <- length(finalNum)
  retMtx      <- matrix(rep(0, n*n), nrow=n, ncol=n)
  retMtx[, n] <- finalNum
  for( j in (n-1):1 )
  {
    for( i in j:1 )
    {
      ld <- retMtx[i+1, j+1]
      lu <- retMtx[i,   j+1]
      retMtx[i,j] <- scalar * (q*lu + qInv*ld)
    }
  }
  retMtx
}
BscdPayTwoLeafAMtx <- function( q, finalMtx, scalar=1 )
{
  qInv        <- 1-q
  n           <- nrow(finalMtx)
  retMtx      <- matrix(rep(0, n*n), nrow=n, ncol=n)
  retMtx[, n] <- finalMtx[ ,n]
  for( j in (n-1):1 )
  {
    for( i in j:1 )
    {
      ld <- retMtx[i+1, j+1]
      lu <- retMtx[i,   j+1]
      retMtx[i,j] <- max( finalMtx[i,j], scalar * (q*lu + qInv*ld) )
    }
  }
  retMtx
}
append.lst <- function( lst, obj, objStr )
{
  for( i in 1:length(lst) )
  {
    if( is.null(lst[[i]]) )
    {
      lst[[i]] <- obj
      return( lst )
    }
  }
  lst
}

#|------------------------------------------------------------------------------------------|
#|                                E N D   O F   S C R I P T                                 |
#|------------------------------------------------------------------------------------------|