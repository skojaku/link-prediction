# -*- coding: utf-8 -*-
# @Author: Sadamori Kojaku
# @Date:   2022-10-14 15:08:01
# @Last Modified by:   Sadamori Kojaku
# @Last Modified time: 2023-04-19 18:00:22

import embcom
import torch
import numpy as np

embedding_models = {}
embedding_model = lambda f: embedding_models.setdefault(f.__name__, f)


def calc_prob_i_j(emb, src, trg, net, model_name):
    score = np.sum(emb[src, :] * emb[trg, :], axis=1).reshape(-1)

    # We want to calculate the probability P(i,j) of
    # random walks moving from i to j, instead of the dot similarity.
    # The P(i,j) is given by
    #    P(i,j) \propto \exp(u[i]^\top u[j] + \ln p0[i] + \ln p0[j])
    # where p0 is proportional to the degree. In residual2vec paper,
    # we found that P(i,j) is more predictable of missing edges than
    # the dot similarity u[i]^\top u[j].
    if model_name in ["deepwalk", "node2vec", "line", "graphsage"]:
        deg = np.array(net.sum(axis=1)).reshape(-1)
        deg = np.maximum(deg, 1)
        deg = deg / np.sum(deg)
        log_deg = np.log(deg)
        score += log_deg[src] + log_deg[trg]
    return score


@embedding_model
def node2vec(network, dim, window_length=10, num_walks=40):
    model = embcom.embeddings.Node2Vec(window_length=window_length, num_walks=num_walks)
    model.fit(network)
    return model.transform(dim=dim)


@embedding_model
def deepwalk(network, dim, window_length=10, num_walks=40):
    model = embcom.embeddings.DeepWalk(window_length=window_length, num_walks=num_walks)
    model.fit(network)
    return model.transform(dim=dim)


@embedding_model
def leigenmap(network, dim):
    model = embcom.embeddings.LaplacianEigenMap()
    model.fit(network)
    return model.transform(dim=dim)


@embedding_model
def modspec(network, dim):
    model = embcom.embeddings.ModularitySpectralEmbedding()
    model.fit(network)
    return model.transform(dim=dim)


# @embedding_model
# def GCN(network,dim,feature_dim=10,device='cpu',dim_h=128):
#
#    """
#    Parameters
#    ----------
#    network: adjacency matrix
#    feature_dim: dimension of features
#    dim: dimension of embedding vectors
#    dim_h : dimension of hidden layer
#    device : device
#
#    """
#
#    model = embcom.embeddings.LaplacianEigenMap()
#    model.fit(network)
#    features = model.transform(dim=feature_dim)
#
#
#    model_GCN, data = embcom.embeddings.GCN(feature_dim,dim_h,dim).to(device), torch.from_numpy(features).to(dtype=torch.float,device = device)
#    model_trained = embcom.train(model_GCN,data,network,device)
#
#    network_c = network.tocoo()
#
#    edge_list_gcn = torch.from_numpy(np.array([network_c.row, network_c.col])).to(device)
#
#
#
#    embeddings = model_trained(data,edge_list_gcn)
#
#    return embeddings


# @embedding_model
# def nonbacktracking(network, dim):
#    model = embcom.embeddings.NonBacktrackingSpectralEmbedding()
#    model.fit(network)
#    return model.transform(dim=dim)


@embedding_model
def graphsage(network, num_walks=1, walk_length=5, dim=10):
    model = embcom.embeddings.graphSAGE(
        num_walks=num_walks, walk_length=walk_length, emb_dim=dim
    )
    model.fit(network)
    model.train_GraphSAGE()
    return model.get_embeddings()
