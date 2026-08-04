//
// Created by Fabio Ceccatelli on 8/4/26.
//

#ifndef PATHWYSE_DYNAMIC_NODE_REDUCTION_H
#define PATHWYSE_DYNAMIC_NODE_REDUCTION_H

#include <vector>

#include "data/node_stats.h"
#include "data/problem.h"

/**
 * Node-level graph reduction driven by statistics collected during a first,
 * relaxed iteration of the labeling algorithm.
 *
 * Every node is scored by a weighted combination of the statistics gathered by
 * NodeStats: the estimated cost of a complete path through the node, the estimated
 * resource usage of such a path, and the number of labels observed at the node.
 * Nodes are then ranked and the worst-scoring ones are deactivated, so that the
 * remaining iterations of the labeling algorithm explore a smaller network.
 *
 * Origin and destination are never deactivated.
 */
class DynamicNodeReduction {

public:

    explicit DynamicNodeReduction(Problem* problem);

    /** Scores the nodes, deactivates the worst ones, and returns how many were pruned. */
    int apply(const NodeStats & stats);

    /** Score of a single node. Public to allow inspection and testing. */
    double computeScore(int v, const NodeStats & stats) const;

    /** Diagnostics */
    const std::vector<double> & getScores() const {return score;}

private:

    Problem* problem;
    int num_nodes;
    std::vector<double> score;

    /** Reads cutoff and weights from the configuration file. */
    void readConfiguration();

    double cutoff{};
    double k3{};
    double k4{};
    double k5{};
};


#endif //PATHWYSE_DYNAMIC_NODE_REDUCTION_H
