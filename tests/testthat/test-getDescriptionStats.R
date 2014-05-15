library('testthat')
library('stringr')
library('Hmisc') # I need to include this for unknown reason or the test fails in R CMD check mode
context('getDescriptionStatsBy')

data("Loblolly")

set.seed(1)
Loblolly$young <- Loblolly$age < 10
Loblolly$young <- factor(Loblolly$young, label=c("Yes", "No"))
Loblolly$fvar <- factor(sample(letters[1:3], size=nrow(Loblolly), replace=TRUE))
Loblolly$young_w_missing <- Loblolly$young
Loblolly$young_w_missing[sample(1:nrow(Loblolly), size=4)] <- NA
Loblolly$fvar_w_missing <- Loblolly$fvar
Loblolly$fvar_w_missing[sample(1:nrow(Loblolly), size=4)] <- NA
Loblolly$height_w_missing <- Loblolly$height
Loblolly$height_w_missing[sample(1:nrow(Loblolly), size=4)] <- NA

test_that("Check mean function", 
{ 
  stats <- by(Loblolly$height, Loblolly$young, mean)
  a <- getDescriptionStatsBy(Loblolly$height, Loblolly$young, 
                             statistics=TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  # Check that it contains the true mean
  expect_true(grepl(round(stats[["No"]], 2), a[1,"No"]),
              info="Expected the mean")
  expect_true(grepl(round(stats[["Yes"]], 2), a[1,"Yes"]),
              info="Expected the mean")
  
  # Check that it contains the sd
  stats <- by(Loblolly$height, Loblolly$young, sd)
  expect_true(grepl(round(stats[["No"]], 2), a[1,"No"]),
              info="Expected the sd")
  expect_true(grepl(round(stats[["Yes"]], 2), a[1,"Yes"]),
              info="Expected the sd")
  
  true_wilc_pv <- pvalueFormatter(wilcox.test(Loblolly$height ~ Loblolly$young)$p.value,
                                  sig.limit=10^-4)
  expect_equal(as.character(a[1, "p-value"]), 
               true_wilc_pv)
  
  # Check p-value without truncation
  a <- getDescriptionStatsBy(Loblolly$height, Loblolly$age == 10, 
                             statistics=TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  true_wilc_pv <- pvalueFormatter(wilcox.test(Loblolly$height ~ Loblolly$age == 10)$p.value,
                                  sig.limit=10^-4)
  expect_equal(as.character(a[1, "p-value"]), 
               true_wilc_pv)
})

test_that("Check median function", 
{ 
  stats <- by(Loblolly$height, Loblolly$young, median)
  a <- getDescriptionStatsBy(Loblolly$height, Loblolly$young, 
                             continuous_fn=describeMedian,
                             statistics=TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  # Check that it contains the true mean
  expect_true(grepl(round(stats[["No"]], 2), a[1,"No"]),
              info="Expected the median")
  expect_true(grepl(round(stats[["Yes"]], 2), a[1,"Yes"]),
              info="Expected the median")
  
  # Check that it contains the sd
  stats <- by(Loblolly$height, Loblolly$young, 
              function(x) str_trim(paste(format(quantile(x, probs=c(.25, .75)), 
                                                digits=2,
                                                nsmall=2), collapse=" - ")))
  expect_true(grepl(stats[["No"]], a[1,"No"]),
              info="Expected the iqr range")
  expect_true(grepl(stats[["Yes"]], a[1,"Yes"]),
              info="Expected the iqr range")
  
  true_wilc_pv <- pvalueFormatter(wilcox.test(Loblolly$height ~ Loblolly$young)$p.value,
                                  sig.limit=10^-4)
  expect_equal(as.character(a[1, "p-value"]), 
               true_wilc_pv)
  
  a <- getDescriptionStatsBy(Loblolly$height, Loblolly$young, 
                             continuous_fn=function(...) 
                               describeMedian(..., iqr = FALSE),
                             statistics=TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  
  # Check that it contains the sd
  stats <- by(Loblolly$height, Loblolly$young, 
              function(x) paste(round(range(x), 2), collapse=" - "))
  expect_true(grepl(stats[["No"]], a[1,"No"]),
              info="Expected the range")
  expect_true(grepl(stats[["Yes"]], a[1,"Yes"]),
              info="Expected the range")
})

test_that("Check factor function", 
{ 
  stats <- table(Loblolly$fvar, Loblolly$young)
  a <- getDescriptionStatsBy(Loblolly$fvar, Loblolly$young, 
                             continuous_fn=describeMedian,
                             statistics=TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  # Check that it contains the true mean
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young))
      expect_match(a[rn, cn], as.character(stats[rn, cn]),
                   info="Factor count don't match")
  }
  
  vertical_perc_stats <- format(apply(stats, 2, function(x){
    x/sum(x)*100
  }), nsmall=2, digits=2)
  horizontal_perc_stats <- t(format(apply(stats, 1, function(x){
    x/sum(x)*100
  }), nsmall=2, digits=2))
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young))
      expect_match(a[rn, cn], sprintf("%s%%", vertical_perc_stats[rn, cn]),
                  info="Factor percentagess don't match in vertical mode")
  }
  
  a <- getDescriptionStatsBy(Loblolly$fvar, Loblolly$young, hrzl_prop=TRUE,
                             continuous_fn=describeMedian,
                             statistics=TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young))
      expect_match(a[rn, cn], sprintf("%s%%", horizontal_perc_stats[rn, cn]),
                  info="Factor percentagess don't match in horizontal mode")
  }
  
  true_fisher_pval <-pvalueFormatter(fisher.test(Loblolly$fvar, Loblolly$young)$p.value, 
                                     sig.limit=10^-4)
  
  expect_equivalent(as.character(a[1, "p-value"]), 
                    true_fisher_pval)
  
})

test_that("Check factor function with missing", 
{ 
  stats <- table(Loblolly$fvar, Loblolly$young_w_missing, useNA="ifany")
  expect_warning(a <- getDescriptionStatsBy(Loblolly$fvar, Loblolly$young_w_missing, 
                                            statistics=TRUE,
                                            html=TRUE, digits=2, sig.limit=10^-4))
  
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young))
      expect_match(a[rn, cn], as.character(stats[rn, cn]),
                   info="Factor count don't match")
  }
  
  
  stats <- table(Loblolly$fvar, Loblolly$young_w_missing, useNA="no")
  vertical_perc_stats <- format(apply(stats, 2, function(x){
    x/sum(x)*100
  }), nsmall=2, digits=2)
  horizontal_perc_stats <- t(format(apply(stats, 1, function(x){
    x/sum(x)*100
  }), nsmall=2, digits=2))
  
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young))
      expect_match(a[rn, cn], sprintf("%s%%", vertical_perc_stats[rn, cn]),
                  info="Factor vertical percentages don't match")
  }
  
  a <- getDescriptionStatsBy(Loblolly$fvar, Loblolly$young_w_missing, 
                             hrzl_prop=TRUE,
                             statistics=TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young))
      expect_match(a[rn, cn], sprintf("%s%%", horizontal_perc_stats[rn, cn]),
                  info="Factor percentages don't match in horizontal mode")
  }
  
  a <- getDescriptionStatsBy(Loblolly$fvar_w_missing, Loblolly$young_w_missing, 
                             html=TRUE, digits=2, sig.limit=10^-4)
  stats <- table(Loblolly$fvar_w_missing, Loblolly$young_w_missing, useNA="no")
  vertical_perc_stats <- format(apply(stats, 2, function(x){
    x/sum(x)*100
  }), nsmall=2, digits=2)
  
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young)){
      expect_match(a[rn, cn], as.character(stats[rn, cn]),
                  info="Factor count don't match")
      expect_match(a[rn, cn], sprintf("%s%%", vertical_perc_stats[rn, cn]),
                  info="Factor vertical percentages don't match")
    }
  }
  
  a <- getDescriptionStatsBy(Loblolly$fvar_w_missing, Loblolly$young_w_missing, 
                             show_missing="ifany",
                             html=TRUE, digits=2, sig.limit=10^-4)
  stats <- table(Loblolly$fvar_w_missing, Loblolly$young_w_missing, useNA="ifany")
  stats <- stats[,!is.na(colnames(stats))]
  rownames(stats)[is.na(rownames(stats))] <- "Missing"
  vertical_perc_stats <- format(apply(stats, 2, function(x){
    x/sum(x)*100
  }), nsmall=2, digits=2)
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young)){
      expect_match(a[rn, cn], as.character(stats[rn, cn]),
                  info="Factor count don't match")
      expect_match(a[rn, cn], sprintf("%s%%", str_trim(vertical_perc_stats[rn, cn])),
                  info="Factor vertical percentages don't match")
    }
  }
  
  a <- getDescriptionStatsBy(Loblolly$fvar_w_missing, Loblolly$young_w_missing, 
                             show_missing="ifany", hrzl_prop = TRUE,
                             html=TRUE, digits=2, sig.limit=10^-4)
  horizontal_perc_stats <- t(format(apply(stats, 1, function(x){
    x/sum(x)*100
  }), nsmall=2, digits=2))
  
  
  for (rn in rownames(a)){
    for (cn in levels(Loblolly$young)){
      expect_match(a[rn, cn], sprintf("%s%%", str_trim(horizontal_perc_stats[rn, cn])),
                  info="Factor vertical percentages don't match")
    }
  }
})