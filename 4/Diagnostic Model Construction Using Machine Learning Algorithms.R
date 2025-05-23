# 
#install.packages(c("seqinr", "plyr", "openxlsx", "randomForestSRC", "glmnet", "RColorBrewer"))

# 
#install.packages(c("ade4", "plsRcox", "superpc", "gbm", "plsRglm", "BART", "snowfall"))

# 
#install.packages(c("caret", "mboost", "e1071", "BART", "MASS", "pROC", "xgboost"))

# 
#if (!require("BiocManager", quietly = TRUE))
#    install.packages("BiocManager")

# 
#BiocManager::install("mixOmics")
#BiocManager::install("survcomp")
#BiocManager::install("ComplexHeatmap")

#
setwd("")
min.selected.var =5     

library(openxlsx)        
library(seqinr)          
library(plyr)            
library(randomForestSRC) 
library(glmnet)          
library(plsRglm)         
library(gbm)             
library(caret)           
library(mboost)          
library(e1071)           
library(BART)            
library(MASS)            
library(snowfall)        
library(xgboost)         
library(ComplexHeatmap)  
library(RColorBrewer)    
library(pROC)            


 
RunML <- function(method, Train_set, Train_label, mode = "Model", classVar){
  # 
  method = gsub(" ", "", method) # 
  method_name = gsub("(\\w+)\\[(.+)\\]", "\\1", method)  # 
  method_param = gsub("(\\w+)\\[(.+)\\]", "\\2", method) # 
  
   
  method_param = switch(
    EXPR = method_name,
    "Enet" = list("alpha" = as.numeric(gsub("alpha=", "", method_param))),
    "Stepglm" = list("direction" = method_param),
    NULL  # 
  )
  
   
  message("Run ", method_name, " algorithm for ", mode, "; ",
          method_param, ";",
          " using ", ncol(Train_set), " Variables")
  
   
  args = list("Train_set" = Train_set,
              "Train_label" = Train_label,
              "mode" = mode,
              "classVar" = classVar)
  args = c(args, method_param)
  
   
  obj <- do.call(what = paste0("Run", method_name),
                 args = args) 
  
   
  if(mode == "Variable"){
    message(length(obj), " Variables retained;\n")
  }else{message("\n")}
  return(obj)
}

 
RunEnet <- function(Train_set, Train_label, mode, classVar, alpha){
  
  cv.fit = cv.glmnet(x = Train_set,
                     y = Train_label[[classVar]],
                     family = "binomial", alpha = alpha, nfolds = 10)
  
  fit = glmnet(x = Train_set,
               y = Train_label[[classVar]],
               family = "binomial", alpha = alpha, lambda = cv.fit$lambda.min)
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}


RunLasso <- function(Train_set, Train_label, mode, classVar){
  RunEnet(Train_set, Train_label, mode, classVar, alpha = 1)
}


RunRidge <- function(Train_set, Train_label, mode, classVar){
  RunEnet(Train_set, Train_label, mode, classVar, alpha = 0)
}


RunStepglm <- function(Train_set, Train_label, mode, classVar, direction){
  
  fit <- step(glm(formula = Train_label[[classVar]] ~ .,
                  family = "binomial", 
                  data = as.data.frame(Train_set)),
              direction = direction, trace = 0)
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunSVM <- function(Train_set, Train_label, mode, classVar){
  
  data <- as.data.frame(Train_set)
  data[[classVar]] <- as.factor(Train_label[[classVar]])
  
  fit = svm(formula = eval(parse(text = paste(classVar, "~."))),
            data= data, probability = T)
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunLDA <- function(Train_set, Train_label, mode, classVar){
  
  data <- as.data.frame(Train_set)
  data[[classVar]] <- as.factor(Train_label[[classVar]])
  
  fit = train(eval(parse(text = paste(classVar, "~."))), 
              data = data, 
              method="lda",
              trControl = trainControl(method = "cv"))
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunglmBoost <- function(Train_set, Train_label, mode, classVar){
  
  data <- cbind(Train_set, Train_label[classVar])
  data[[classVar]] <- as.factor(data[[classVar]])
  
  fit <- glmboost(eval(parse(text = paste(classVar, "~."))),
                  data = data,
                  family = Binomial())
  
  cvm <- cvrisk(fit, papply = lapply,
                folds = cv(model.weights(fit), type = "kfold"))
  fit <- glmboost(eval(parse(text = paste(classVar, "~."))),
                  data = data,
                  family = Binomial(), 
                  control = boost_control(mstop = max(mstop(cvm), 40)))
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunplsRglm <- function(Train_set, Train_label, mode, classVar){
  
  cv.plsRglm.res = cv.plsRglm(formula = Train_label[[classVar]] ~ ., 
                              data = as.data.frame(Train_set),
                              nt=10, verbose = FALSE)
  
  fit <- plsRglm(Train_label[[classVar]], 
                 as.data.frame(Train_set), 
                 modele = "pls-glm-logistic",
                 verbose = F, sparse = T)
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunRF <- function(Train_set, Train_label, mode, classVar){
 
  rf_nodesize = 5 
  
  Train_label[[classVar]] <- as.factor(Train_label[[classVar]])
  
  fit <- rfsrc(formula = formula(paste0(classVar, "~.")),
               data = cbind(Train_set, Train_label[classVar]),
               ntree = 1000, nodesize = rf_nodesize,
               importance = T,
               proximity = T,
               forest = T)
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunGBM <- function(Train_set, Train_label, mode, classVar){
  
  fit <- gbm(formula = Train_label[[classVar]] ~ .,
             data = as.data.frame(Train_set),
             distribution = 'bernoulli',
             n.trees = 10000,
             interaction.depth = 3,
             n.minobsinnode = 10,
             shrinkage = 0.001,
             cv.folds = 10,n.cores = 6)
  
  best <- which.min(fit$cv.error)
  fit <- gbm(formula = Train_label[[classVar]] ~ .,
             data = as.data.frame(Train_set),
             distribution = 'bernoulli',
             n.trees = best,
             interaction.depth = 3,
             n.minobsinnode = 10,
             shrinkage = 0.001, n.cores = 8)
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunXGBoost <- function(Train_set, Train_label, mode, classVar){
  
  indexes = createFolds(Train_label[[classVar]], k = 5, list=T)
  
  CV <- unlist(lapply(indexes, function(pt){
    dtrain = xgb.DMatrix(data = Train_set[-pt, ], 
                         label = Train_label[-pt, ])
    dtest = xgb.DMatrix(data = Train_set[pt, ], 
                        label = Train_label[pt, ])
    watchlist <- list(train=dtrain, test=dtest)
    
    bst <- xgb.train(data=dtrain, 
                     max.depth=2, eta=1, nthread = 2, nrounds=10, 
                     watchlist=watchlist, 
                     objective = "binary:logistic", verbose = F)
    which.min(bst$evaluation_log$test_logloss)
  }))
  
   
  nround <- as.numeric(names(which.max(table(CV))))
  fit <- xgboost(data = Train_set, 
                 label = Train_label[[classVar]], 
                 max.depth = 2, eta = 1, nthread = 2, nrounds = nround, 
                 objective = "binary:logistic", verbose = F)
  fit$subFeature = colnames(Train_set)
  
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
RunNaiveBayes <- function(Train_set, Train_label, mode, classVar){
  
  data <- cbind(Train_set, Train_label[classVar])
  data[[classVar]] <- as.factor(data[[classVar]])
  
  fit <- naiveBayes(eval(parse(text = paste(classVar, "~."))), 
                    data = data)
  fit$subFeature = colnames(Train_set)
  if (mode == "Model") return(fit)
  if (mode == "Variable") return(ExtractVar(fit))
}

 
# RunDRF <- function(Train_set, Train_label, mode, classVar){
#   Train_label <- data.frame(
#     "0" = as.numeric(Train_label == 0),
#     "1" = as.numeric(Train_label == 1)
#   )
#   fit <- drf(X = Train_set, 
#              Y = Train_label, 
#              compute.variable.importance = F)
#   fit$subFeature = colnames(Train_set)
#   
#   summary(predict(fit, functional = "mean", as.matrix(Train_set))$mean)
#   
#   if (mode == "Model") return(fit)
#   if (mode == "Variable") return(ExtractVar(fit))
# }

 
quiet <- function(..., messages=FALSE, cat=FALSE){
  if(!cat){
    sink(tempfile())  
    on.exit(sink())  
  }
   
  out <- if(messages) eval(...) else suppressMessages(eval(...))
  out
}

 
standarize.fun <- function(indata, centerFlag, scaleFlag) {  
  scale(indata, center=centerFlag, scale=scaleFlag)
}

 
scaleData <- function(data, cohort = NULL, centerFlags = NULL, scaleFlags = NULL){
  samplename = rownames(data)  
 
  if (is.null(cohort)){
    data <- list(data); names(data) = "training"
  }else{
    data <- split(as.data.frame(data), cohort)  
  }
  
  if (is.null(centerFlags)){
    centerFlags = F; message("No centerFlags found, set as FALSE")
  }
   
  if (length(centerFlags)==1){
    centerFlags = rep(centerFlags, length(data)); message("set centerFlags for all cohort as ", unique(centerFlags))
  }
   
  if (is.null(names(centerFlags))){
    names(centerFlags) <- names(data); message("match centerFlags with cohort by order\n")
  }
  
   
  if (is.null(scaleFlags)){
    scaleFlags = F; message("No scaleFlags found, set as FALSE")
  }
   
  if (length(scaleFlags)==1){
    scaleFlags = rep(scaleFlags, length(data)); message("set scaleFlags for all cohort as ", unique(scaleFlags))
  }
   
  if (is.null(names(scaleFlags))){
    names(scaleFlags) <- names(data); message("match scaleFlags with cohort by order\n")
  }
  
  centerFlags <- centerFlags[names(data)]; scaleFlags <- scaleFlags[names(data)]
   
  outdata <- mapply(standarize.fun, indata = data, centerFlag = centerFlags, scaleFlag = scaleFlags, SIMPLIFY = F)
  # lapply(out.data, function(x) summary(apply(x, 2, var)))
   
  outdata <- do.call(rbind, outdata)
  outdata <- outdata[samplename, ]
  return(outdata)
}

 
ExtractVar <- function(fit){
  Feature <- quiet(switch(
    EXPR = class(fit)[1],
    "lognet" = rownames(coef(fit))[which(coef(fit)[, 1]!=0)], 
    "glm" = names(coef(fit)), 
    "svm.formula" = fit$subFeature, 
    "train" = fit$coefnames, 
    "glmboost" = names(coef(fit)[abs(coef(fit))>0]), 
    "plsRglmmodel" = rownames(fit$Coeffs)[fit$Coeffs!=0], 
    "rfsrc" = var.select(fit, verbose = F)$topvars, 
    "gbm" = rownames(summary.gbm(fit, plotit = F))[summary.gbm(fit, plotit = F)$rel.inf>0], 
    "xgb.Booster" = fit$subFeature, 
    "naiveBayes" = fit$subFeature 
    # "drf" = fit$subFeature 
  ))
  
   
  Feature <- setdiff(Feature, c("(Intercept)", "Intercept"))
  return(Feature)
}

 
CalPredictScore <- function(fit, new_data, type = "lp"){
   
  new_data <- new_data[, fit$subFeature]
   
  RS <- quiet(switch(
    EXPR = class(fit)[1],
    "lognet"      = predict(fit, type = 'response', as.matrix(new_data)), 
    "glm"         = predict(fit, type = 'response', as.data.frame(new_data)), 
    "svm.formula" = predict(fit, as.data.frame(new_data), probability = T), 
    "train"       = predict(fit, new_data, type = "prob")[[2]], 
    "glmboost"    = predict(fit, type = "response", as.data.frame(new_data)), 
    "plsRglmmodel" = predict(fit, type = "response", as.data.frame(new_data)), 
    "rfsrc"        = predict(fit, as.data.frame(new_data))$predicted[, "1"], 
    "gbm"          = predict(fit, type = 'response', as.data.frame(new_data)), 
    "xgb.Booster" = predict(fit, as.matrix(new_data)), 
    "naiveBayes" = predict(object = fit, type = "raw", newdata = new_data)[, "1"] 
    # "drf" = predict(fit, functional = "mean", as.matrix(new_data))$mean 
  ))
   
  RS = as.numeric(as.vector(RS))
  names(RS) = rownames(new_data)
  return(RS)
}

 
PredictClass <- function(fit, new_data){
  
  new_data <- new_data[, fit$subFeature]
 
  label <- quiet(switch(
    EXPR = class(fit)[1],
    "lognet"      = predict(fit, type = 'class', as.matrix(new_data)), 
    "glm"         = ifelse(test = predict(fit, type = 'response', as.data.frame(new_data))>0.5, 
                           yes = "1", no = "0"), 
    "svm.formula" = predict(fit, as.data.frame(new_data), decision.values = T), 
    "train"       = predict(fit, new_data, type = "raw"), 
    "glmboost"    = predict(fit, type = "class", as.data.frame(new_data)), 
    "plsRglmmodel" = ifelse(test = predict(fit, type = 'response', as.data.frame(new_data))>0.5, 
                            yes = "1", no = "0"), 
    "rfsrc"        = predict(fit, as.data.frame(new_data))$class, 
    "gbm"          = ifelse(test = predict(fit, type = 'response', as.data.frame(new_data))>0.5,
                            yes = "1", no = "0"), 
    "xgb.Booster" = ifelse(test = predict(fit, as.matrix(new_data))>0.5,
                           yes = "1", no = "0"), 
    "naiveBayes" = predict(object = fit, type = "class", newdata = new_data) 
    # "drf" = predict(fit, functional = "mean", as.matrix(new_data))$mean 
  ))
   
  label = as.character(as.vector(label))
  names(label) = rownames(new_data)
  return(label)
}

 
RunEval <- function(fit, 
                    Test_set = NULL, 
                    Test_label = NULL, 
                    Train_set = NULL, 
                    Train_label = NULL, 
                    Train_name = NULL,
                    cohortVar = "Cohort",
                    classVar){
  
  
  if(!is.element(cohortVar, colnames(Test_label))) {
    stop(paste0("There is no [", cohortVar, "] indicator, please fill in one more column!"))
  } 
  
   
  if((!is.null(Train_set)) & (!is.null(Train_label))) {
    new_data <- rbind.data.frame(Train_set[, fit$subFeature],
                                 Test_set[, fit$subFeature])
    
     
    if(!is.null(Train_name)) {
      Train_label$Cohort <- Train_name
    } else {
      Train_label$Cohort <- "Training"
    }
     
    colnames(Train_label)[ncol(Train_label)] <- cohortVar
    Test_label <- rbind.data.frame(Train_label[,c(cohortVar, classVar)],
                                   Test_label[,c(cohortVar, classVar)])
    Test_label[,1] <- factor(Test_label[,1], 
                             levels = c(unique(Train_label[,cohortVar]), setdiff(unique(Test_label[,cohortVar]),unique(Train_label[,cohortVar]))))
  } else {
    new_data <- Test_set[, fit$subFeature]
  }
  
   
  RS <- suppressWarnings(CalPredictScore(fit = fit, new_data = new_data))
  
   
  Predict.out <- Test_label
  Predict.out$RS <- as.vector(RS)
   
  Predict.out <- split(x = Predict.out, f = Predict.out[,cohortVar])
 
  unlist(lapply(Predict.out, function(data){
    as.numeric(auc(suppressMessages(roc(data[[classVar]], data$RS))))
  }))
}

 
SimpleHeatmap <- function(Cindex_mat, avg_Cindex, 
                          CohortCol, barCol,
                          cellwidth = 1, cellheight = 0.5, 
                          cluster_columns, cluster_rows){
   
  col_ha = columnAnnotation("Cohort" = colnames(Cindex_mat),
                            col = list("Cohort" = CohortCol),
                            show_annotation_name = F)
  
   
  row_ha = rowAnnotation(bar = anno_barplot(avg_Cindex, bar_width = 0.8, border = FALSE,
                                            gp = gpar(fill = barCol, col = NA),
                                            add_numbers = T, numbers_offset = unit(-10, "mm"),
                                            axis_param = list("labels_rot" = 0),
                                            numbers_gp = gpar(fontsize = 9, col = "white"),
                                            width = unit(3, "cm")),
                         show_annotation_name = F)
  
   
  Heatmap(as.matrix(Cindex_mat), name = "AUC",
          right_annotation = row_ha, 
          top_annotation = col_ha,
          col = c("#4195C1", "#FFFFFF", "#FFBC90"), 
          cluster_columns = cluster_columns, cluster_rows = cluster_rows, 
          show_column_names = FALSE, 
          show_row_names = TRUE,
          row_names_side = "left",
          width = unit(cellwidth * ncol(Cindex_mat) + 2, "cm"),
          height = unit(cellheight * nrow(Cindex_mat), "cm"),
          column_split = factor(colnames(Cindex_mat), levels = colnames(Cindex_mat)), 
          column_title = NULL,
          cell_fun = function(j, i, x, y, w, h, col) { 
            grid.text(label = format(Cindex_mat[i, j], digits = 3, nsmall = 3),
                      x, y, gp = gpar(fontsize = 10))
          }
  )
}

 
Train_data <- read.table("data.train.txt", header = T, sep = "\t", check.names=F, row.names=1, stringsAsFactors=F)
 
Train_expr=Train_data[,1:(ncol(Train_data)-1),drop=F]
Train_class=Train_data[,ncol(Train_data),drop=F]

 
Test_data <- read.table("data.test.txt", header=T, sep="\t", check.names=F, row.names=1, stringsAsFactors = F)
 
Test_expr=Test_data[,1:(ncol(Test_data)-1),drop=F]
Test_class=Test_data[,ncol(Test_data),drop=F]
 
Test_class$Cohort=gsub("(.*)\\_(.*)\\_(.*)", "\\1", row.names(Test_class))
Test_class=Test_class[,c("Cohort", "Type")]

 
comgene <- intersect(colnames(Train_expr), colnames(Test_expr))
 
Train_expr <- as.matrix(Train_expr[,comgene])
Test_expr <- as.matrix(Test_expr[,comgene])
 
Train_set = scaleData(data=Train_expr, centerFlags=T, scaleFlags=T) 


 
set.seed(123)  
noise <- matrix(rnorm(n = nrow(Train_set) * ncol(Train_set), mean = 1.5, sd = 4), 
                nrow = nrow(Train_set), ncol = ncol(Train_set))
Train_set <- Train_set + noise
 
Test_set = scaleData(data = Test_expr, cohort = Test_class$Cohort, centerFlags = T, scaleFlags = T)
noise_test <- matrix(rnorm(n = nrow(Test_set) * ncol(Test_set), mean = 1.5, sd = 4), 
                     nrow = nrow(Test_set), ncol = ncol(Test_set))
Test_set <- Test_set + noise_test
names(x = split(as.data.frame(Test_expr), f = Test_class$Cohort))
Test_set = scaleData(data = Test_expr, cohort = Test_class$Cohort, centerFlags = T, scaleFlags = T)

 
methodRT <- read.table("refer.methodLists.txt", header=T, sep="\t", check.names=F)
methods=methodRT$Model
methods <- gsub("-| ", "", methods) 

 
classVar = "Type"         
Variable = colnames(Train_set)
preTrain.method =  strsplit(methods, "\\+") 
preTrain.method = lapply(preTrain.method, function(x) rev(x)[-1]) 
preTrain.method = unique(unlist(preTrain.method)) 


 
preTrain.var <- list()       
set.seed(seed = 123)         
for (method in preTrain.method){
  preTrain.var[[method]] = RunML(method = method,              
                                 Train_set = Train_set,        
                                 Train_label = Train_class,    
                                 mode = "Variable",            
                                 classVar = classVar)          
}
preTrain.var[["simple"]] <- colnames(Train_set) 

 
model <- list()            
set.seed(seed = 123)       
Train_set_bk = Train_set   
for (method in methods){
  cat(match(method, methods), ":", method, "\n") 
  method_name = method
  method <- strsplit(method, "\\+")[[1]] 
  if (length(method) == 1) method <- c("simple", method) 
  Variable = preTrain.var[[method[1]]] 
  Train_set = Train_set_bk[, Variable]
  Train_label = Train_class
  model[[method_name]] <- RunML(method = method[2],           
                                Train_set = Train_set,        
                                Train_label = Train_label,    
                                mode = "Model",               
                                classVar = classVar)          
  
   
  if(length(ExtractVar(model[[method_name]])) <= min.selected.var) {
    model[[method_name]] <- NULL
  }
}
Train_set = Train_set_bk; rm(Train_set_bk) 
 
saveRDS(model, "model.MLmodel.rds")

 
FinalModel <- c("panML", "multiLogistic")[2]
if (FinalModel == "multiLogistic"){
  # 
  logisticmodel <- lapply(model, function(fit){    
    tmp <- glm(formula = Train_class[[classVar]] ~ .,
               family = "binomial", 
               data = as.data.frame(Train_set[, ExtractVar(fit)]))
    tmp$subFeature <- ExtractVar(fit)
    return(tmp)
  })
}
 
saveRDS(logisticmodel, "model.logisticmodel.rds")

 
model <- readRDS("model.MLmodel.rds")            
#model <- readRDS("model.logisticmodel.rds")     
methodsValid <- names(model)                     
RS_list <- list()
for (method in methodsValid){
  RS_list[[method]] <- CalPredictScore(fit = model[[method]], new_data = rbind.data.frame(Train_set,Test_set))
}
riskTab=as.data.frame(t(do.call(rbind, RS_list)))
riskTab=cbind(id=row.names(riskTab), riskTab)
write.table(riskTab, "model.riskMatrix.txt", sep="\t", row.names=F, quote=F)

 
Class_list <- list()
for (method in methodsValid){
  Class_list[[method]] <- PredictClass(fit = model[[method]], new_data = rbind.data.frame(Train_set,Test_set))
}
Class_mat <- as.data.frame(t(do.call(rbind, Class_list)))
 
#Class_mat <- cbind.data.frame(Test_class, Class_mat[rownames(Class_mat),]) 
classTab=cbind(id=row.names(Class_mat), Class_mat)
write.table(classTab, "model.classMatrix.txt", sep="\t", row.names=F, quote=F)

 
fea_list <- list()
for (method in methodsValid) {
  fea_list[[method]] <- ExtractVar(model[[method]])
}
fea_df <- lapply(model, function(fit){
  data.frame(ExtractVar(fit))
})
fea_df <- do.call(rbind, fea_df)
fea_df$algorithm <- gsub("(.+)\\.(.+$)", "\\1", rownames(fea_df))
colnames(fea_df)[1] <- "features"
write.table(fea_df, file="model.genes.txt", sep = "\t", row.names = F, col.names = T, quote = F)

 
AUC_list <- list()
for (method in methodsValid){
  AUC_list[[method]] <- RunEval(fit = model[[method]],      
                                Test_set = Test_set,        
                                Test_label = Test_class,    
                                Train_set = Train_set,      
                                Train_label = Train_class,  
                                Train_name = "Train",       
                                cohortVar = "Cohort",       
                                classVar = classVar)        
}
AUC_mat <- do.call(rbind, AUC_list)
aucTab=cbind(Method=row.names(AUC_mat), AUC_mat)
write.table(aucTab, "model.AUCmatrix.txt", sep="\t", row.names=F, quote=F)


 
AUC_mat <- read.table("model.AUCmatrix.txt", header=T, sep="\t", check.names=F, row.names=1, stringsAsFactors=F)


avg_AUC <- apply(AUC_mat, 1, mean)
avg_AUC <- sort(avg_AUC, decreasing = T)
AUC_mat <- AUC_mat[names(avg_AUC),]

fea_sel <- fea_list[[rownames(AUC_mat)[1]]]
avg_AUC <- as.numeric(format(avg_AUC, digits = 3, nsmall = 3))

 
CohortCol <- brewer.pal(n = ncol(AUC_mat), name = "Paired")
names(CohortCol) <- colnames(AUC_mat)

 
cellwidth = 1; cellheight = 0.5
hm <- SimpleHeatmap(Cindex_mat = AUC_mat,       
                    avg_Cindex = avg_AUC,       
                    CohortCol = CohortCol,      
                    barCol = "steelblue",       
                    cellwidth = cellwidth, cellheight = cellheight,    
                    cluster_columns = F, cluster_rows = F)      

 
pdf(file="model.AUCheatmap.pdf", width=cellwidth * ncol(AUC_mat) + 6, height=cellheight * nrow(AUC_mat) * 0.45)
draw(hm, heatmap_legend_side="right", annotation_legend_side="right")
dev.off()
