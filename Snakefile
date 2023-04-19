import numpy as np
from os.path import join as j
import itertools
import pandas as pd
from snakemake.utils import Paramspace
import os
from workflow.EmbeddingModels import *
from workflow.NetworkTopologyPredictionModels import *

include: "./workflow/workflow_utils.smk"  # not able to merge this with snakemake_utils.py due to some path breakage issues

configfile: "workflow/config.yaml"

# ====================
# Root folder path setting
# ====================

# network file
DATA_DIR = config["data_dir"]  # set test_data for testing

DERIVED_DIR = j(DATA_DIR, "derived")
NETWORK_DIR = j(DERIVED_DIR, "networks")
RAW_UNPROCESSED_NETWORKS_DIR = j(NETWORK_DIR, "raw")
RAW_PROCESSED_NETWORKS_DIR = j(NETWORK_DIR, "preprocessed")
EMB_DIR = j(DERIVED_DIR, "embedding")
PRED_DIR = j(DERIVED_DIR, "link-prediction")
OPT_STACK_DIR = j(DERIVED_DIR, "optimal_stacking")

# All networks
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
# Negative edge sampler
#
params_train_test_split = {
    "testEdgeFraction": [0.5],
    "sampleId": list(range(N_ITERATION)),
}
paramspace_train_test_split = to_paramspace(params_train_test_split)


params_negative_edge_sampler = {
    "negativeEdgeSampler": ["uniform", "degreeBiased"],
}
paramspace_negative_edge_sampler = to_paramspace(params_negative_edge_sampler)


#
# Network embedding
#
params_emb = {"model": list(embedding_models.keys()), "dim": [64]}
paramspace_emb = to_paramspace(params_emb)


#
# Network-based link prediction
#
params_net_linkpred = {
    "model": list(topology_models.keys())
}
paramspace_net_linkpred = to_paramspace(params_net_linkpred)

# params_cv_files = {
#     "xtrain" : "X_trainE_cv",
#     "fold" : list(range(1,6)),
#     "negativeEdgeSampler": ["uniform", "degreeBiased"],
#     "testEdgeFraction": [0.5],
#     "sampleId": list(range(N_ITERATION)),
# }

# params_cv_files = to_paramspace(params_cv_files)

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
    f"heldout-net_{paramspace_negative_edge_sampler.wildcard_pattern}.npz",
)

TRAIN_NET_FILE_OPTIMAL_STACKING = j(
    OPT_TRAIN_DATASET_DIR,
    "{data}",
    f"train-net_{paramspace_negative_edge_sampler.wildcard_pattern}.npz",
)

# ====================
# Intermediate files
# ====================

#
# Embedding
#
EMB_FILE = j(
    EMB_DIR,
    "{data}",
    f"emb_{paramspace_train_test_split.wildcard_pattern}_{paramspace_emb.wildcard_pattern}.npz",
)
# classification
PRED_SCORE_EMB_FILE = j(
    PRED_DIR,
    "{data}",
    f"score_basedOn~emb_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_emb.wildcard_pattern}.csv",
)
# ranking
PRED_RANK_EMB_FILE = j(
    PRED_DIR,
    "{data}",
    f"score_ranking_basedOn~emb_{paramspace_train_test_split.wildcard_pattern}_{paramspace_emb.wildcard_pattern}.npz",
)

#
# Topology-based
#
PRED_SCORE_NET_FILE = j(
    PRED_DIR,
    "{data}",
    f"score_basedOn~net_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_net_linkpred.wildcard_pattern}.csv",
)
PRED_RANK_NET_FILE = j(
    PRED_DIR,
    "{data}",
    f"score_ranking_basedOn~net_{paramspace_train_test_split.wildcard_pattern}_{paramspace_net_linkpred.wildcard_pattern}.npz",
)

#
# Optimal Stacking
#
TRAIN_FEATURE_MATRIX = j(
    OPT_STACK_DIR,
    "{data}",
    "feature_matrices",
    f"train-feature_{paramspace_train_test_split.wildcard_pattern}.pkl",
)

HELDOUT_FEATURE_MATRIX = j(
    OPT_STACK_DIR,
    "{data}",
    "feature_matrices",
    f"heldout-feature_{paramspace_train_test_split.wildcard_pattern}.pkl",
)

CV_DIR = j(OPT_STACK_DIR,
    "{data}",
    "cv",
    f"condition_{paramspace_train_test_split}",
)

OUT_BEST_RF_PARAMS = j(
    OPT_STACK_DIR,
    "{data}",
    f"bestparms-rf_{paramspace_train_test_split.wildcard_pattern}.csv",
)

# ====================
# Evaluation
# ====================
RESULT_DIR = j(DERIVED_DIR, "results")

# Classification
LP_SCORE_EMB_FILE = j(
    RESULT_DIR,
    "auc-roc",
    "{data}",
    f"result_basedOn~emb_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_emb.wildcard_pattern}.csv",
)
LP_SCORE_NET_FILE = j(
    RESULT_DIR,
    "auc-roc",
    "{data}",
    f"result_basedOn~net_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}_{paramspace_net_linkpred.wildcard_pattern}.csv",
)

# Ranking
RANK_SCORE_EMB_FILE = j(
    RESULT_DIR,
    "ranking",
    "{data}",
    f"result_basedOn~emb_{paramspace_train_test_split.wildcard_pattern}_{paramspace_emb.wildcard_pattern}.csv",
)
RANK_SCORE_NET_FILE = j(
    RESULT_DIR,
    "ranking",
    "{data}",
    f"result_basedOn~net_{paramspace_train_test_split.wildcard_pattern}_{paramspace_net_linkpred.wildcard_pattern}.csv",
)

LP_ALL_AUCROC_SCORE_FILE = j(RESULT_DIR, "result_auc_roc.csv")
LP_ALL_RANKING_SCORE_FILE = j(RESULT_DIR, "result_ranking.csv")

LP_SCORE_OPT_STACK_FILE = j(
    OPT_STACK_DIR,
    "auc-roc",
    "{data}",
    f"result_basedOn~optstack_{paramspace_train_test_split.wildcard_pattern}_{paramspace_negative_edge_sampler.wildcard_pattern}.csv"
)

# ====================
# Output
# ====================
FIG_AUCROC = j(RESULT_DIR, "figs", "aucroc.pdf")
FIG_DEGSKEW_AUCDIFF = j(RESULT_DIR, "figs", "corr_degskew_aucdiff.pdf")
FIG_NODES_AUCDIFF = j(RESULT_DIR, "figs", "corr_nodes_aucdiff.pdf")
FIG_PREC_RECAL_F1 =j(RESULT_DIR, "figs", "prec-recall-f1.pdf")

#
#
# RULES
#

rule all:
    input:
        #
        # All results
        #
        LP_ALL_AUCROC_SCORE_FILE,
        LP_ALL_RANKING_SCORE_FILE,
        #
        # Link classification
        #
        expand(
            LP_SCORE_EMB_FILE,
            data=DATA_LIST,
            **params_emb,
            **params_negative_edge_sampler,
            **params_train_test_split
        ),
        expand(
            LP_SCORE_NET_FILE,
            data=DATA_LIST,
            **params_net_linkpred,
            **params_negative_edge_sampler,
            **params_train_test_split
        ),
        #
        # Link ranking
        #
        expand(
            RANK_SCORE_EMB_FILE,
            data=DATA_LIST,
            **params_emb,
            **params_train_test_split
        ),
        expand(
            RANK_SCORE_NET_FILE,
            data=DATA_LIST,
            **params_net_linkpred,
            **params_train_test_split
        )


rule figs:
    input:
        FIG_AUCROC,
        FIG_DEGSKEW_AUCDIFF,
        FIG_NODES_AUCDIFF,
        FIG_PREC_RECAL_F1

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
        "workflow/clean_networks.py"

# ============================
# Optimal stacking
# ============================
rule optimal_stacking_all:
    input:
        expand(
            LP_SCORE_OPT_STACK_FILE,
            data=DATA_LIST,
            **params_negative_edge_sampler
        )

rule optimal_stacking_train_heldout_dataset:
    input:
        edge_table_file=EDGE_TABLE_FILE,
    params:
        parameters=paramspace_negative_edge_sampler.instance
    output:
        output_heldout_net_file=HELDOUT_NET_FILE_OPTIMAL_STACKING,
        output_train_net_file=TRAIN_NET_FILE_OPTIMAL_STACKING,
    script:
        "workflow/generate-optimal-stacking-train-heldout-networks.py"

rule optimal_stacking_generate_features:
    input:
        input_original_edge_table_file=EDGE_TABLE_FILE,
        input_heldout_net_file=HELDOUT_NET_FILE_OPTIMAL_STACKING,
        input_train_net_file=TRAIN_NET_FILE_OPTIMAL_STACKING,
    output:
        output_heldout_feature=HELDOUT_FEATURE_MATRIX,
        output_train_feature=TRAIN_FEATURE_MATRIX
    script:
        "workflow/generate-optimal-stacking-topological-features.py"

rule optimal_stacking_generate_cv_files:
    input:
        input_heldout_feature=HELDOUT_FEATURE_MATRIX,
        input_train_feature=TRAIN_FEATURE_MATRIX,
    output:
        output_cv_dir=directory(CV_DIR),
    script:
        "workflow/generate-optimal-stacking-cv.py"

rule optimal_stacking_model_selection:
    input:
        input_cv_dir=CV_DIR,
    output:
        output_best_rf_params=OUT_BEST_RF_PARAMS,
    script:
        "workflow/optimal-stacking-modelselection.py"

rule optimal_stacking_performance:
    input:
        input_best_rf_params=OUT_BEST_RF_PARAMS,
        input_seen_unseen_data_dir=CV_DIR,
    params:
        data_name=lambda wildcards: wildcards.data,
    output:
        output_file=LP_SCORE_OPT_STACK_FILE
    script:
        "workflow/optimal-stacking-performance.py"

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
        "workflow/generate-train-test-edge-split.py"

rule train_test_edge_split:
    input:
        edge_table_file=EDGE_TABLE_FILE,
        train_net_file=TRAIN_NET_FILE,
    params:
        parameters=paramspace_negative_edge_sampler.instance,
    output:
        output_target_edge_table_file=TARGET_EDGE_TABLE_FILE,
    script:
        "workflow/generate-test-edges.py"



# ==============================
# Prediction based on embedding
# ==============================
rule embedding:
    input:
        net_file=TRAIN_NET_FILE,
    params:
        parameters=paramspace_emb.instance,
    output:
        output_file=EMB_FILE,
    script:
        "workflow/embedding.py"


#
# Positive vs Negative
#
rule embedding_link_prediction:
    input:
        input_file=TARGET_EDGE_TABLE_FILE,
        emb_file=EMB_FILE,
    params:
        parameters=paramspace_emb.instance,
    output:
        output_file=PRED_SCORE_EMB_FILE,
    script:
        "workflow/embedding-link-prediction.py"

#
# Ranking
#
rule embedding_link_ranking:
    input:
        input_file=TEST_EDGE_TABLE_FILE,
        net_file=TRAIN_NET_FILE,
        emb_file=EMB_FILE,
    params:
        parameters=paramspace_emb.instance,
        topK = 50
    output:
        output_file=PRED_RANK_EMB_FILE,
    script:
        "workflow/embedding-link-ranking.py"

# ==============================
# Prediction based on networks
# ==============================

#
# Positive vs Negative
#
rule network_link_prediction:
    input:
        input_file=TARGET_EDGE_TABLE_FILE,
        net_file=TRAIN_NET_FILE,
    params:
        parameters=paramspace_net_linkpred.instance,
    output:
        output_file=PRED_SCORE_NET_FILE,
    script:
        "workflow/network-link-prediction.py"

#
# Ranking
#
rule network_link_ranking:
    input:
        input_file=TEST_EDGE_TABLE_FILE,
        net_file=TRAIN_NET_FILE,
    params:
        parameters=paramspace_net_linkpred.instance,
        topK = 50
    output:
        output_file=PRED_RANK_NET_FILE,
    script:
        "workflow/network-link-ranking.py"

# =====================
# Evaluation
# =====================


#
# Positive vs Negative edges
#
rule eval_link_prediction_embedding:
    input:
        input_file=PRED_SCORE_EMB_FILE,
    params:
        data_name=lambda wildcards: wildcards.data,
    output:
        output_file=LP_SCORE_EMB_FILE,
    script:
        "workflow/eval-link-prediction-performance.py"


rule eval_link_prediction_networks:
    input:
        input_file=PRED_SCORE_NET_FILE,
    params:
        data_name=lambda wildcards: wildcards.data,
    output:
        output_file=LP_SCORE_NET_FILE,
    script:
        "workflow/eval-link-prediction-performance.py"

#
# Ranking
#
rule eval_link_ranking_embedding:
    input:
        ranking_score_file=PRED_RANK_EMB_FILE,
        edge_table_file = TEST_EDGE_TABLE_FILE
    params:
        data_name=lambda wildcards: wildcards.data,
    output:
        output_file=RANK_SCORE_EMB_FILE,
    script:
        "workflow/eval-link-ranking-performance.py"

rule eval_link_ranking_networks:
    input:
        ranking_score_file=PRED_RANK_NET_FILE,
        edge_table_file = TEST_EDGE_TABLE_FILE
    params:
        data_name=lambda wildcards: wildcards.data,
    output:
        output_file=RANK_SCORE_NET_FILE,
    script:
        "workflow/eval-link-ranking-performance.py"


rule concatenate_aucroc_results:
    input:
        input_file_list=expand(
            LP_SCORE_EMB_FILE,
            data=DATA_LIST,
            **params_emb,
            **params_negative_edge_sampler,
            **params_train_test_split
        )
        + expand(
            LP_SCORE_NET_FILE,
            data=DATA_LIST,
            **params_net_linkpred,
            **params_negative_edge_sampler,
            **params_train_test_split
        )
    output:
        output_file=LP_ALL_AUCROC_SCORE_FILE,
    script:
        "workflow/concat-results.py"

rule concatenate_ranking_results:
    input:
        input_file_list = expand(
            RANK_SCORE_EMB_FILE,
            data=DATA_LIST,
            **params_emb,
            **params_train_test_split
        )
        + expand(
            RANK_SCORE_NET_FILE,
            data=DATA_LIST,
            **params_net_linkpred,
            **params_train_test_split,
            **params_negative_edge_sampler,
        ),
    output:
        output_file=LP_ALL_RANKING_SCORE_FILE,
    script:
        "workflow/concat-results.py"


# =====================
# Plot
# =====================
rule plot_aucroc:
    input:
        input_file=LP_ALL_AUCROC_SCORE_FILE,
    output:
        output_file=FIG_AUCROC,
    script:
        "workflow/plot-auc-roc.py"


rule plot_aucdiff:
    input:
        auc_results_file=LP_ALL_AUCROC_SCORE_FILE,
        networks_dir=RAW_PROCESSED_NETWORKS_DIR,
    output:
        degskew_outputfile=FIG_DEGSKEW_AUCDIFF,
        nodes_outputfile=FIG_NODES_AUCDIFF,
    script:
        "workflow/plot-NetProp-AucDiff.py"


rule plot_prec_recal_f1:
    input:
        input_file=LP_ALL_RANKING_SCORE_FILE,
    output:
        output_file=FIG_PREC_RECAL_F1,
    script:
        "workflow/plot-prec-recall-f1.py"
