#ifndef PW_GRAPH_REDUCTION_H
#define PW_GRAPH_REDUCTION_H

#include <vector>

#include "data/node_stats.h"
#include "data/problem.h"

class StaticArcReduction {
public:
    StaticArcReduction(Problem* problem);

    void reduce(double beta, double K, double K2);

    void repairIsolatedNodes(int k_min_arcs);

    void apply();
    void setNodeStats(const NodeStats & s) {stats = s;}

private:
    Problem* problem;
    int num_nodes;
    int max_abs_arc_cost;
    int max_abs_node_cost;

    std::vector<std::vector<double>> score;
    std::vector<std::vector<int>> arcsConnection;

    double computeScore(int i, int j, double K, double K2) const;
    void ensureDepotConnectivity();
    NodeStats stats;
};

#endif