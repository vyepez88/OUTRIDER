context("Testing helper functions")

test_that("check ODS object", {
    ods <- makeExampleOutriderDataSet(10,10)
    expect_error(checkOutriderDataSet("a"), "Please provide an OutriderData")
    expect_true(checkOutriderDataSet(ods))
    
    expect_error(checkFullAnalysis(ods), "Please calculate the size factors")
    ods <- estimateSizeFactors(ods)
    
    expect_error(checkFullAnalysis(ods), "Please calculate the P-values before")
    padj(ods) <- matrix(runif(ncol(ods)*nrow(ods)), ncol=ncol(ods))
    
    expect_error(checkFullAnalysis(ods), "Please calculate the Z-scores before")
    zScore(ods) <- matrix(runif(ncol(ods)*nrow(ods)), ncol=ncol(ods))
    
    expect_true(checkFullAnalysis(ods))
})

test_that("check theta range", {
    expect_error(checkThetaRange("aaa"), "Please provide a range for theta")
    expect_error(checkThetaRange(c(NA,1)), "Please provide finite values")
    expect_error(checkThetaRange(c(2,1)), "The first element of the range")
    expect_true(checkThetaRange(c(1,2)))
})

test_that("check requirements", {
    ods <- makeExampleOutriderDataSet(10, 150)
    expect_error(checkCountRequirements(ods[,FALSE]), "Please pro.*one sample.")
    expect_error(checkCountRequirements(ods[FALSE,]), "Please pro.*one gene.")
    
    counts(ods)[1,] <- 0
    expect_error(checkCountRequirements(ods), "There are genes without any re")
    counts(ods)[1,1] <- 1
    expect_error(checkCountRequirements(ods), "The model requires for each")
    counts(ods)[1,2] <- 1
    expect_true(!any(checkCountRequirements(ods)))
})
