import numpy as np
from os.path import join as j
import itertools
import pandas as pd
from snakemake.utils import Paramspace
import os
#from workflow.models.EmbeddingModels import *
#from workflow.prediction.NetworkTopologyPredictionModels import *

include: "./workflow/workflow_utils.smk"  # not able to merge this with snakemake_utils.py due to some path breakage issues

configfile: "workflow/config.yaml"

# =========================
# Root folder path setting
# =========================

# network file
DATA_DIR = config["data_dir"]  # set test_data for testing

DERIVED_DIR = j(DATA_DIR, "derived")
NETWORK_DIR = j(DERIVED_DIR, "networks")
RAW_UNPROCESSED_NETWORKS_DIR = j(NETWORK_DIR, "raw")
RAW_PROCESSED_NETWORKS_DIR = j(NETWORK_DIR, "preprocessed")
#EMB_DIR = j(DERIVED_DIR, "embedding")
MODEL_DIR = j(DERIVED_DIR, "models")
PRED_DIR = j(DERIVED_DIR, "link-prediction")
OPT_STACK_DIR = j(DERIVED_DIR, "optimal_stacking")

#All networks
DATA_LIST = [
    f.split("_")[1].split(".")[0] for f in os.listdir(RAW_UNPROCESSED_NETWORKS_DIR)
]

# Small networks
# Comment out if you want to run for all networks
if config["small_networks"]:
    with open("workflow/small-networks.json", "r") as f:
        DATA_LIST = json.load(f)

N_ITERATION = 5

# ====================
# Configuration
# ====================
#
# Train test split
#
params_train_test_split = {
    "testEdgeFraction": [0.5],
    "sampleId": list(range(N_ITERATION)),
}
paramspace_train_test_split = to_paramspace(paramName = "trainTestSplit", param = params_train_test_split, index=["testEdgeFraction"])


#
# Negative edge sampler
#
params_negative_edge_sampler = {
    "negativeEdgeSampler": ["uniform", "degreeBiased"],
}
paramspace_negative_edge_sampler = to_paramspace(paramName = "negativeSampling", param = params_negative_edge_sampler, index ="negativeEdgeSampler")


#
# Network embedding
#
params_model = [
    {
        "model": ["line"],
        "dim":[64],
        "num_walks":[40],
        "modelType":["embedding"]
    },
    {
        "model": ["GCN", "GIN", "GAT", "GraphSAGE"],
        "feature_dim":[64],
        "dim_h":[64],
        "num_layers":[2],
        "in_channels": [64],
        "hidden_channels": [64],
        "num_layers": [2],
        "out_channels": [64],
        "dim":[64],
        "modelType":["embedding"]
    },
    {
        "model": ["seal+GCN", "seal+GIN", "seal+GAT", "seal+GraphSAGE"],
        "feature_dim":[64],
        "dim_h":[64],
        "num_layers":[2],
        "negative_edge_sampler": ["uniform", "degreeBiased"],
        "epochs": 10,
        "hops": 2,
        "batch_size": 50,
        "lr": 1e-3,
        "in_channels": 64,
        "hidden_channels": 64,
        "num_layers": 2,
        "out_channels": 64,
        "modelType":["seal"]
    },
    {
        "model":["stacklp"],
        "modelType":["stacklp"],
        "negative_edge_sampler": ["uniform", "degreeBiased"],
        "val_edge_frac":[0.2],
        "n_train_samples":[10000],
        "n_cv":[5]
    },
    {
        "model": ["preferentialAttachment", "commonNeighbors", "jaccardIndex", "resourceAllocation", "adamicAdar", "localRandomWalk", "localPathIndex"],
        "modelType":["network"]
    }
]
paramspace_model= to_paramspace(paramName = "PredictionModel", param = params_model, index = ["model", "modelType"])


# =============================
# Networks & Benchmark Datasets
# =============================

# Edge table
EDGE_TABLE_FILE = j(NETWORK_DIR, "preprocessed", "{data}", "edge_table.csv")  # train

# Benchmark
DATASET_DIR = j(DERIVED_DIR, "datasets")
TRAIN_NET_FILE = j(
    DATASET_DIR,
    "{data}",
    f"train-net_{paramspace_train_test_split.wildcard_pattern}.npz",
)
TARGET_EDGE_TABLE_FILE = j(
    DATASET_DIR,
    "{data}",
    f"targetEdgeTable_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}.csv",
)
TEST_EDGE_TABLE_FILE = j(
    DATASET_DIR,
    "{data}",
    f"testEdgeTable_{paramspace_train_test_split.wildcard_pattern}.csv",
)

# Optimal stacking training and heldout dataset
OPT_TRAIN_DATASET_DIR = j(OPT_STACK_DIR, "train_datasets")
OPT_HELDOUT_DATASET_DIR = j(OPT_STACK_DIR, "heldout_datasets")

HELDOUT_NET_FILE_OPTIMAL_STACKING = j(
    OPT_HELDOUT_DATASET_DIR,
    "{data}",
    f"heldout-net{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_train_test_split.wildcard_pattern}.npz",
)

TRAIN_NET_FILE_OPTIMAL_STACKING = j(
    OPT_TRAIN_DATASET_DIR,
    "{data}",
    f"train-net_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_train_test_split.wildcard_pattern}.npz",
)

# ====================
# Intermediate files
# ====================

#
# Network statistics
#
NET_STAT_FILE = j(
   NETWORK_DIR, "network-stats.csv"
)

COMMON_NEIGHBOR_COVERAGE = j(NETWORK_DIR, "common_neighbor_link_coverage.csv")

#
# Models
#
MODEL_FILE = j(
    MODEL_DIR,
    "{data}",
    f"model_{paramspace_train_test_split.wildcard_pattern}_{paramspace_model.wildcard_pattern}.pickle",
)

# classification
PRED_SCORE_MODEL_FILE = j(
    PRED_DIR,
    "{data}",
    f"score_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_model.wildcard_pattern}.csv",
)
# ranking
PRED_RANK_MODEL_FILE = j(
    PRED_DIR,
    "{data}",
    f"score_ranking_{paramspace_train_test_split.wildcard_pattern}_{paramspace_model.wildcard_pattern}.npz",
)

##
## Topology-based
##
#PRED_SCORE_NET_FILE = j(
#    PRED_DIR,
#    "{data}",
#    f"score_basedOn~net_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_net_linkpred.wildcard_pattern}.csv",
#)
#PRED_RANK_NET_FILE = j(
#    PRED_DIR,
#    "{data}",
#    f"score_ranking_basedOn~net_{paramspace_train_test_split.wildcard_pattern}_{paramspace_net_linkpred.wildcard_pattern}.npz",
#)



# ====================
# Evaluation
# ====================
RESULT_DIR = j(DERIVED_DIR, "results")

# Classification
LP_SCORE_MODEL_FILE = j(
    RESULT_DIR,
    "auc-roc",
    "{data}",
    f"result_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_model.wildcard_pattern}.csv",
)

# Ranking
RANK_SCORE_MODEL_FILE = j(
    RESULT_DIR,
    "ranking",
    "{data}",
    f"result_{paramspace_train_test_split.wildcard_pattern}_{paramspace_model.wildcard_pattern}.csv",
)

LP_ALL_AUCROC_SCORE_FILE = j(RESULT_DIR, "result_auc_roc.csv")
LP_ALL_RANKING_SCORE_FILE = j(RESULT_DIR, "result_ranking.csv")
LP_ALL_QUANTILE_RANKING_FILE = j(RESULT_DIR, "result_quantile_ranking.csv")

LP_SCORE_OPT_STACK_FILE = j(
    OPT_STACK_DIR,
    "auc-roc",
    "{data}",
    f"result_basedOn~optstack_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}.csv"
)

BEST_RF_FEATURES = j(
    OPT_STACK_DIR,
    "feature-importance",
    "{data}",
    f"bestfeatures-rf_basedOn~optstack_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}.pkl",
)

LP_ALL_SCORE_OPT_STACK_FILE = j(RESULT_DIR, "result_opt_stack_auc_roc.csv")


# ====================
# Output
# ====================
FIG_AUCROC = j(RESULT_DIR, "figs", "aucroc.pdf")
FIG_DEGSKEW_AUCDIFF = j(RESULT_DIR, "figs", "corr_degskew_aucdiff.pdf")
FIG_NODES_AUCDIFF = j(RESULT_DIR, "figs", "corr_nodes_aucdiff.pdf")
FIG_DEGSKEW_AUCDIFF_NODESIZE = j(RESULT_DIR, "figs", "corr_degskew_aucdiff_nodesize.pdf")
FIG_PREC_RECAL_F1 =j(RESULT_DIR, "figs", "prec-recall-f1.pdf")
FIG_DEG_DEG_PLOT =j(RESULT_DIR, "figs", "deg_deg_plot_negativeEdgeSampler~{negativeEdgeSampler}.pdf")
FIG_QUANTILE_RANKING=j(RESULT_DIR, "figs", "quantile_ranking_negativeEdgeSampler~{negativeEdgeSampler}.pdf")
FIG_PERF_VS_KURTOSIS_PLOT=j(RESULT_DIR, "figs", "performance_vs_degree_kurtosis.pdf")
FIG_RANKING_SIMILARITY=j(RESULT_DIR, "figs", "ranking-similarity-similarityMetric~{similarityMetric}.pdf")
#
#
# RULES
#
save_param_table(j(DATA_DIR, "parameter_table.csv"))
rule all:
    input:
        #
        # All results
        #
        #LP_ALL_AUCROC_SCORE_FILE,
        #LP_ALL_RANKING_SCORE_FILE,
        #
        # Link classification (Check point 1)
        #
        expand(
            MODEL_FILE,
            data=DATA_LIST,
            predictionModel= paramspace_model,
            negativeSampler = paramspace_negative_edge_sampler,
            trainTestSplit = paramspace_train_test_split
        ),
        #expand(
        #    LP_SCORE_MODEL_FILE,
        #    data=DATA_LIST,
        #    predictionModel= paramspace_model,
        #    negativeSampler = paramspace_negative_edge_sampler,
        #    trainTestSplit = paramspace_train_test_split
        #),
        #
        # Network stats (Check point 2)
        #
        #NET_STAT_FILE,
        #COMMON_NEIGHBOR_COVERAGE,
        #
        # Link ranking (Check point 3)
        #
#        expand(
#            RANK_SCORE_MODEL_FILE,
#            data=DATA_LIST,
#            **params_model,
#            **params_train_test_split
#        ),
#        expand(
#            RANK_SCORE_NET_FILE,
#            data=DATA_LIST,
#            **params_net_linkpred,
#            **params_train_test_split
#        )
        #
        # Quantile ranking file (Checkpoint 4)
        #
        #LP_ALL_QUANTILE_RANKING_FILE


rule figs:
    input:
        expand(FIG_DEG_DEG_PLOT, **params_negative_edge_sampler),
        expand(FIG_QUANTILE_RANKING, **params_negative_edge_sampler),
        expand(FIG_RANKING_SIMILARITY, similarityMetric = ["RBO", "Spearmanr"]),
        FIG_PERF_VS_KURTOSIS_PLOT,
        FIG_AUCROC,
        #FIG_DEGSKEW_AUCDIFF,
        #FIG_NODES_AUCDIFF,
        #FIG_DEGSKEW_AUCDIFF_NODESIZE,
        #FIG_PREC_RECAL_F1

rule _all:
    input:
        COMMON_NEIGHBOR_COVERAGE,
# ============================
# Cleaning networks
# Gets edge list of GCC as csv
# ============================
rule clean_networks:
    input:
        raw_unprocessed_networks_dir=RAW_UNPROCESSED_NETWORKS_DIR,
        raw_processed_networks_dir=RAW_PROCESSED_NETWORKS_DIR,
    output:
        edge_table_file=EDGE_TABLE_FILE,
    script:
        "workflow/preprocessing/clean_networks.py"

rule calc_network_stats:
    input:
        input_files = expand(EDGE_TABLE_FILE, data = DATA_LIST)
    output:
        output_file = NET_STAT_FILE
    script:
        "workflow/preprocessing/calc-network-stats.py"


rule calc_common_neighbor_edge_coverage:
    input:
        edge_table_files = expand(TEST_EDGE_TABLE_FILE, data = DATA_LIST, **params_train_test_split),
        net_files = expand(TRAIN_NET_FILE, data = DATA_LIST, **params_train_test_split)
    output:
        output_file = COMMON_NEIGHBOR_COVERAGE
    script:
        "workflow/preprocessing/calc-link-coverage-by-distance.py"

# ============================
# Generating benchmark dataset
# ============================
rule generate_link_prediction_dataset:
    input:
        edge_table_file=EDGE_TABLE_FILE,
    params:
        parameters=paramspace_train_test_split.instance,
    output:
        output_train_net_file=TRAIN_NET_FILE,
        output_test_edge_file=TEST_EDGE_TABLE_FILE
    script:
        "workflow/preprocessing/generate-train-test-edge-split.py"

rule train_test_edge_split:
    input:
        edge_table_file=EDGE_TABLE_FILE,
        train_net_file=TRAIN_NET_FILE,
    params:
        parameters=paramspace_negative_edge_sampler.instance,
    output:
        output_target_edge_table_file=TARGET_EDGE_TABLE_FILE,
    script:
        "workflow/preprocessing/generate-test-edges.py"



# =======================
# Train prediction models
# =======================

rule train_model:
    input:
        net_file=TRAIN_NET_FILE,
    params:
        parameters=paramspace_model.instance,
    output:
        output_file=MODEL_FILE,
    script:
        "workflow/train-predict/train.py"


#
##
## Positive vs Negative
##
#rule embedding_link_prediction:
#    input:
#        input_file=TARGET_EDGE_TABLE_FILE,
#        MODEL_FILE=MODEL_FILE,
#        net_file = TRAIN_NET_FILE,
#    params:
#        parameters=paramspace_model.instance,
#    output:
#        output_file=PRED_SCORE_MODEL_FILE,
#    script:
#        "workflow/prediction/embedding-link-prediction.py"
#
##
## Ranking
##
#rule embedding_link_ranking:
#    input:
#        input_file=TEST_EDGE_TABLE_FILE,
#        net_file=TRAIN_NET_FILE,
#        MODEL_FILE=MODEL_FILE,
#    params:
#        parameters=paramspace_model.instance,
#        topK = 150
#    output:
#        output_file=PRED_RANK_MODEL_FILE,
#    script:
#        "workflow/prediction/embedding-link-ranking.py"
#
## ==============================
## Prediction based on networks
## ==============================
#
##
## Positive vs Negative
##
#rule network_link_prediction:
#    input:
#        input_file=TARGET_EDGE_TABLE_FILE,
#        net_file=TRAIN_NET_FILE,
#    params:
#        parameters=paramspace_net_linkpred.instance,
#    output:
#        output_file=PRED_SCORE_NET_FILE,
#    script:
#        "workflow/prediction/network-link-prediction.py"
#
##
## Ranking
##
#rule network_link_ranking:
#    input:
#        input_file=TEST_EDGE_TABLE_FILE,
#        net_file=TRAIN_NET_FILE,
#    params:
#        parameters=paramspace_net_linkpred.instance,
#        topK = 150
#    output:
#        output_file=PRED_RANK_NET_FILE,
#    script:
#        "workflow/prediction/network-link-ranking.py"
#
## =====================
## Evaluation
## =====================
#
#
##
## Positive vs Negative edges
##
#rule eval_link_prediction_embedding:
#    input:
#        input_file=PRED_SCORE_MODEL_FILE,
#    params:
#        data_name=lambda wildcards: wildcards.data,
#    output:
#        output_file=LP_SCORE_MODEL_FILE,
#    script:
#        "workflow/evaluation/eval-link-prediction-performance.py"
#
#
#rule eval_link_prediction_networks:
#    input:
#        input_file=PRED_SCORE_NET_FILE,
#    params:
#        data_name=lambda wildcards: wildcards.data,
#    output:
#        output_file=LP_SCORE_NET_FILE,
#    script:
#        "workflow/evaluation/eval-link-prediction-performance.py"
#
##
## Ranking
##
#rule eval_link_ranking_embedding:
#    input:
#        ranking_score_file=PRED_RANK_MODEL_FILE,
#        edge_table_file = TEST_EDGE_TABLE_FILE
#    params:
#        data_name=lambda wildcards: wildcards.data,
#    output:
#        output_file=RANK_SCORE_MODEL_FILE,
#    script:
#        "workflow/evaluation/eval-link-ranking-performance.py"
#
#rule eval_link_ranking_networks:
#    input:
#        ranking_score_file=PRED_RANK_NET_FILE,
#        edge_table_file = TEST_EDGE_TABLE_FILE
#    params:
#        data_name=lambda wildcards: wildcards.data,
#    output:
#        output_file=RANK_SCORE_NET_FILE,
#    script:
#        "workflow/evaluation/eval-link-ranking-performance.py"
#
#
#rule concatenate_aucroc_results:
#    input:
#        input_file_list=expand(
#            LP_SCORE_MODEL_FILE,
#            data=DATA_LIST,
#            **params_model,
#            **params_negative_edge_sampler,
#            **params_train_test_split
#        )
#        + expand(
#            LP_SCORE_NET_FILE,
#            data=DATA_LIST,
#            **params_net_linkpred,
#            **params_negative_edge_sampler,
#            **params_train_test_split
#        )
#    output:
#        output_file=LP_ALL_AUCROC_SCORE_FILE,
#    script:
#        "workflow/concat-results.py"
#
#rule concatenate_ranking_results:
#    input:
#        input_file_list = expand(
#            RANK_SCORE_MODEL_FILE,
#            data=DATA_LIST,
#            **params_model,
#            **params_train_test_split
#        )
#        + expand(
#            RANK_SCORE_NET_FILE,
#            data=DATA_LIST,
#            **params_net_linkpred,
#            **params_train_test_split,
#            **params_negative_edge_sampler,
#        ),
#    output:
#        output_file=LP_ALL_RANKING_SCORE_FILE,
#    script:
#        "workflow/concat-results.py"
#
##
## Evaluate the quantile
##
#rule calc_quantiles:
#    input:
#        auc_roc_table_file =  LP_ALL_AUCROC_SCORE_FILE,
#        ranking_table_file = LP_ALL_RANKING_SCORE_FILE,
#        net_stat_file = NET_STAT_FILE
#    output:
#        output_file = LP_ALL_QUANTILE_RANKING_FILE
#    script:
#        "workflow/evaluation/calc-quantiles.py"
#
## =====================
## Plot
## =====================
#
##
## Figure 1 and 2
##
#rule calc_deg_deg_plot:
#    input:
#        edge_table_file=EDGE_TABLE_FILE.format(data = "airport-rach"),
#    params:
#        negativeEdgeSampler = lambda wildcards: wildcards.negativeEdgeSampler
#    output:
#        output_file=FIG_DEG_DEG_PLOT,
#    script:
#        "workflow/plots/plot-deg-deg-plot.py"
#
#
#rule calc_deg_skewness_plot:
#    input:
#        auc_roc_table_file =  LP_ALL_AUCROC_SCORE_FILE,
#        ranking_table_file = LP_ALL_RANKING_SCORE_FILE,
#        net_stat_file = NET_STAT_FILE
#    output:
#        output_file=FIG_PERF_VS_KURTOSIS_PLOT,
#    script:
#        "workflow/plots/plot-performance-vs-degree-skewness.py"
#
#rule plot_node2vec_vs_pa_ranking:
#    input:
#        input_file=LP_ALL_QUANTILE_RANKING_FILE,
#    params:
#        negativeEdgeSampler = lambda wildcards: wildcards.negativeEdgeSampler
#    output:
#        output_file=FIG_QUANTILE_RANKING,
#    script:
#        "workflow/plots/plot-ranking-pref-vs-node2vec.py"
#
#rule plot_ranking_correlation:
#    input:
#        input_file=LP_ALL_QUANTILE_RANKING_FILE,
#    params:
#        similarityMetric = lambda wildcards: wildcards.similarityMetric
#    output:
#        output_file=FIG_RANKING_SIMILARITY,
#    script:
#        "workflow/plots/plot-ranking-similarity.py"
#
#rule plot_aucroc:
#    input:
#        input_file=LP_ALL_AUCROC_SCORE_FILE,
#    output:
#        output_file=FIG_AUCROC,
#    script:
#        "workflow/plots/plot-auc-roc.py"
#
#
#rule plot_aucdiff:
#    input:
#        auc_results_file=LP_ALL_AUCROC_SCORE_FILE,
#        networks_dir=RAW_PROCESSED_NETWORKS_DIR,
#    output:
#        degskew_outputfile=FIG_DEGSKEW_AUCDIFF,
#        nodes_outputfile=FIG_NODES_AUCDIFF,
#        degskew_nodesize_outputfile = FIG_DEGSKEW_AUCDIFF_NODESIZE,
#    script:
#        "workflow/plots/plot-NetProp-AucDiff.py"
#
#
#rule plot_prec_recal_f1:
#    input:
#        input_file=LP_ALL_RANKING_SCORE_FILE,
#    output:
#        output_file=FIG_PREC_RECAL_F1,
#    script:
#        "workflow/plots/plot-prec-recall-f1.py"
#