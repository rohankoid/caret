modelInfo <- list(label = "Generalized Additive Model using LOESS",
                  library = "gam",
                  loop = NULL,
                  type = c('Regression', 'Classification'),
                  parameters = data.frame(parameter = c('span', 'degree'),
                                          class = c('numeric', 'numeric'),
                                          label = c('Span', 'Degree')),
                  grid = function(x, y, len = NULL, search = "grid") {
                    if(search == "grid") {
                      out <- expand.grid(span = .5, degree = 1)
                    } else {
                      out <- data.frame(span = runif(len, min = 0, max = 1),
                                        degree = sample(1:2, size = len, replace = TRUE))
                    }
                    out
                  },
                  fit = function(x, y, wts, param, lev, last, classProbs, ...) {
                    args <- list(data = if(is.data.frame(x)) x else as.data.frame(x))
                    args$data$.outcome <- y
                    args$formula <- caret:::smootherFormula(x,
                                                            smoother = "lo",
                                                            span = param$span,
                                                            degree = param$degree)
                    theDots <- list(...)
                    
                    
                    if(!any(names(theDots) == "family")) 
                      args$family <- if(is.factor(y)) binomial else gaussian
                    
                    if(length(theDots) > 0) args <- c(args, theDots)
                    
                    do.call(getFromNamespace("gam", "gam"), args)
                  },
                  predict = function(modelFit, newdata, submodels = NULL) {
                    if(!is.data.frame(newdata)) newdata <- as.data.frame(newdata)
                    if(modelFit$problemType == "Classification") {
                      probs <-  gam:::predict.gam(modelFit, newdata, type = "response")
                      out <- ifelse(probs < .5,
                                    modelFit$obsLevel[1],
                                    modelFit$obsLevel[2])
                    } else {
                      out <- gam:::predict.gam(modelFit, newdata, type = "response")
                    }
                    out
                  },
                  prob = function(modelFit, newdata, submodels = NULL){
                    if(!is.data.frame(newdata)) newdata <- as.data.frame(newdata)
                    out <- predict(modelFit, newdata, type = "response")
                    out <- cbind(1-out, out)
                    ## glm models the second factor level, we treat the first as the
                    ## event of interest. See Details in ?glm
                    colnames(out) <-  modelFit$obsLevels
                    out
                  },
                  predictors = function(x, ...) {
                    getNames <- function(x) {
                      x <- strsplit(x, "(\\()|(,)|(\\))")
                      x <- lapply(x, function(x) x[!(x %in% c("s", "lo", ""))])
                      unlist(lapply(x, function(x) x[1]))
                    }
                    getNames(predictors(x$terms))
                  },
                  varImp = function(object, ...) {
                    getNames <- function(x) {
                      x <- strsplit(x, "(\\()|(,)|(\\))")
                      x <- lapply(x, function(x) x[!(x %in% c("s", "lo", ""))])
                      unlist(lapply(x, function(x) x[1]))
                    }
                    gamSummary <- gam:::summary.gam(object)
                    smoothed <- gamSummary$anova
                    smoothed <- smoothed[complete.cases(smoothed), grepl("^P", colnames(smoothed)), drop = FALSE] 
                    linear <- gamSummary$parametric.anova
                    linear <- linear[complete.cases(linear), grepl("^P", colnames(linear)), drop = FALSE] 
                    linear <- linear[!(rownames(linear) %in% rownames(smoothed)),,drop = FALSE]
                    colnames(smoothed) <- colnames(linear) <- "pval"
                    gams <- rbind(smoothed, linear)
                    gams <- gams[rownames(gams) != "(Intercept)",,drop = FALSE]
                    rownames(gams) <- getNames(rownames(gams))
                    colnames(gams)[1] <- "Overall"
                    gams <- as.data.frame(gams)
                    gams$Overall <- -log10(gams$Overall)
                    allPreds <- getNames(colnames(attr(object$terms,"factors")))
                    extras <- allPreds[!(allPreds %in% rownames(gams))]
                    if(any(extras)) {
                      tmp <- data.frame(Overall = rep(NA, length(extras)))
                      rownames(tmp) <- extras
                      gams <- rbind(gams, tmp)
                    }
                    gams
                  },
                  levels = function(x) x$obsLevels,
                  notes = "Which terms enter the model in a nonlinear manner is determined by the number of unique values for the predictor. For example, if a predictor only has four unique values, most basis expansion method will fail because there are not enough granularity in the data. By default, a predictor must have at least 10 unique values to be used in a nonlinear basis expansion.",
                  tags = c("Generalized Linear Model", "Generalized Additive Model"),
                  sort = function(x) x)
