
###########################################################################################
# LOAD PACKAGES
###########################################################################################

rm(list=ls())
source('utils/saver.r')
source('utils/loader.r')
source('utils/reader.r')
source('S4objects/S4classes.r')
source('S3objects/S3methods.r')

source('params.R')

# dimensions

## number of monte carlo samples
nreps <- 200
## number of projection years
nyr.proj <- 50

## matrix of paramter values
params <- matrix(param,nrow=length(param),ncol=nreps)  
rownames(params) <- names(param)                       
colnames(params) <- 1:nreps

# initial population size (Swanepoel et al. 2014; ±2000 leopard)
x.initial <- c(nc=694,
           nj=410,
           saf=117,
           f36=99,
           f48=80,
           f60=73,
           f72=45,
           f84=194,
           sam=84,
           m36=41,
           m48=24,
           m60=24,
           m72=28,
           m84=95)

# population projection array
x <- array(x.initial,dim=c(length(x.initial),nreps,nyr.proj))
dimnames(x) <- list(age.class = names(x.initial),rep = 1:nreps, year = 1:nyr.proj)
x[,,2:nyr.proj] <- NA

# projection
for (i in 1:nreps) {
    
    # sample parameters
    param.sample <- params[,i]
    
    # create new object to hold leopard numbers
    # and vital rates
    xx <- leopard(x.initial, param.sample[1:14], param.sample[15:19])
    
    # assign multiplicative maternal effects
    xx@maternal.effect[] <- matrix(maternal.effects, nrow=2, ncol=5, byrow=T)
    
    # assign cubs at random to maternal age class
    prob.maternal.age <- xx[4:8]/sum(xx[4:8])
    xx@realised.birth[1,] <- rmultinom(1, xx[1], prob.maternal.age)
    xx@realised.birth[2,] <- rmultinom(1, xx[2], prob.maternal.age)
    
    # loop forward over years
    for (y in 2:nyr.proj) {
        
        # correlated deviation in survival: 
        # log-normal with cv = 0.2
        # truncated at 0 and 1
        sdev <- rnorm(1)
        sigma <- sqrt(log(1+0.20^2))
        
        # (check this: if you take 1000 values of sdev the right hand side should have a mean value
        # approximately equal to param.sample)
        param.sample[1:14] <- exp(log(param.sample[1:14]) +  sigma * sdev - sigma^2/2)
        param.sample[1:14] <- vapply(vapply(param.sample[1:14],function(x) max(x,0),numeric(1)),function(x) min(x,1),numeric(1))
        
        # calculate stochastic survival
        xx <- survival(xx)
        
        # calculate stochastic birth
        xx <- birth(xx)
        
        # step forward
        xx <- transition(xx)
                
        # record numbers
        x[,i,y] <- xx
                
    }
}

###########################################################################################
# PLOTS
###########################################################################################

x.tot <- apply(x, 2:3, sum)
boxplot(x.tot,ylab="N",xaxt="n",xlab="Step",outline=FALSE)
axis(side=1,at=1:nyr.proj)

###########################################################################################
# END
###########################################################################################