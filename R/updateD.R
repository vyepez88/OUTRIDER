
updateD <- function(ods, theta, control, BPPARAM, ...){
    D <- getD(ods)
    b <- getb(ods)
    H <- getx(ods) %*% getE(ods)
    k <- t(counts(ods))
    sf <- sizeFactors(ods)
    sf[1:ncol(ods)] <- 1
    
    fitD <- function(i, D, b, k, H, sf, theta, control){
        par <- c(b[i], D[i,])
        ki <- k[,i]
        thetai <- theta[i]
        fit <- optim(c(par), fn=lossD, gr=gradD, k=ki, H=H, sf=sf, theta=thetai,
                method='L-BFGS', control=control)
        fit
    }
    
    # TODO check errors: ERROR: ABNORMAL_TERMINATION_IN_LNSRCH
    # This comes from genes where extrem values are present (Z score > 15)
    fitls <- bplapply(1:nrow(ods), fitD, D=D, b=b, k=k, sf=sf, H=H, theta=theta, 
            control=control, BPPARAM=BPPARAM)
    
    # update D and bias terms
    parMat <- sapply(fitls, '[[', 'par')
    print(table(sapply(fitls, '[[', 'message')))
    ods <- setb(ods, parMat[1,])
    ods <- setD(ods, t(parMat)[,-1])
    
    return(ods)
}

lossD <- function(d, k, H, sf, theta, minMu=0.01){
    b <- d[1]
    d <- d[-1]
    
    y <- H %*% d + b
    yexp <- sf * (minMu + exp(y))
    
    ll <- mean(dnbinom(k, mu=yexp, size=theta, log=TRUE))
    
    return(-ll)
}


gradD <- function(d, k, H, sf=1, theta, minMu=0.01){
    b <- d[1]
    d <- d[-1]
    
    y <- c(H %*% d + b)
    yexp <- sf * (minMu + exp(y))
    t1 <- colMeans(c(k * sf * exp(y) / yexp) * H)
    
    kt <- (k + theta) * sf * exp(y) / (sf * exp(y) + theta)
    t2 <- colMeans(c(kt * sf * exp(y) / yexp) * H) 
    
    dd <- t2-t1
    db <- mean(kt - k * sf * exp(y) / yexp)
    
    return(c(db, dd))
}


debugLossD <- function(){
    samples <- 80
    q<- 2
    
    #Hidden Space is a sample time q matrix. 
    H <- matrix(c(rep(c(-1,1), each=samples/2), 
                  rep(c(-2,2), samples/2)), ncol=2)
    
    H
    D_true <- rnorm(q)
    y_true <- H %*% D_true + 3
    mu_true <- 0.01 + exp(y_true)
    
    k <- rnbinom(length(mu_true), mu = mu_true, size=25)
    
    #library(MASS)
    #glm.nb(k~H)
    
    init<-c(mean(log(k+1)),0,0)
    #b <- 3
    #d <- D_true
    
    
    fit <- optim(init, fn=lossD, gr=gradD, k=k, H=H, s=1, theta=25, method='L-BFGS')
    fit$par
    
    D_true
    lossD(init, k, H, 1, 25)
    lossD(c(3, D_true), k, H, 1, 25)
    
    
    
    which(sapply(fitls, '[[', 'message') == 'ERROR: ABNORMAL_TERMINATION_IN_LNSRCH')
    i <- 437
    control$trace <- 6
    fitD(i=i, D=D, b=b, k=k, sf=sf, H=H, theta=theta, control=control)
    par <- c(0.00940116, 0.0553455, -0.0601702, 0.493793, -0.297911, -0.272072)
    par <- c(mean(log(ki + 1)), D[i,])
    par <- c(b[i], D[i,])
    ki <- k[,i]
    mu <- predictED(getE(ods), getD(ods), getb(ods), getx(ods), sizeFactors(ods))
    cD <- cooksDistance(k, mu, q=5, trim=0.1)
    table(cD > 1)
    sort(round(cD[i,], 2))
    thetai <- theta[i]
    lossD(par, ki, H, sf, theta=thetai)
    gradD(par, ki, H, sf, theta=thetai)
    hist(log10(ki))
    
    sum(ki > 200000)
    sort(ki)
    fit <- optim(c(par), fn=lossD, gr=gradD, k=ki, H=H, sf=sf, theta=thetai,
                 method='L-BFGS', control=control)
    fitD(i=48, D=D, b=b, k=k, sf=sf, H=H, theta=theta, control=control)
    
    lk <- log2(counts(ods) + 1)
}
