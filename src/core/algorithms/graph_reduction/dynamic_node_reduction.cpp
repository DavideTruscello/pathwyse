//
// Created by Fabio Ceccatelli on 8/4/26.
//

#include "dynamic_node_reduction.h"
#include <algorithm>
#include <limits>


DynamicNodeReduction::DynamicNodeReduction(Problem* problem) : problem(problem) {
    num_nodes = problem->getNumNodes();
    score.assign(num_nodes, 0.0);
    readConfiguration();
}

void DynamicNodeReduction::readConfiguration() {
    cutoff = Parameters::getGraphNodeReductionCutoff();
    k3 = Parameters::getGraphReductionK3();
    k4 = Parameters::getGraphReductionK4();
    k5 = Parameters::getGraphReductionK5();
}

double DynamicNodeReduction::computeScore(int v, const NodeStats & stats) const {
    return k3 * stats.getObjective(v)
         + k4 * stats.getResource(v)
         + k5 * stats.getLabelCount(v);
}

int DynamicNodeReduction::apply(const NodeStats & stats) {
    if(not stats.isAvailable())
        return 0;

    const int origin = problem->getOrigin();
    const int destination = problem->getDestination();
    struct ScoredNode { int v; double s; };
    std::vector<ScoredNode> candidates;
    candidates.reserve(num_nodes);

    for(int v = 0; v < num_nodes; v++) {
        if(v == origin or v == destination or not problem->isActiveNode(v))
            continue;

        score[v] = computeScore(v, stats);
        candidates.push_back({v, score[v]});
    }

    if(candidates.empty())
        return 0;

    std::sort(candidates.begin(), candidates.end(),
              [](const ScoredNode & a, const ScoredNode & b) { return a.s < b.s; });

    size_t n_keep = static_cast<size_t>(cutoff * candidates.size());
    if(n_keep >= candidates.size())
        return 0;

    int pruned = 0;
    for(size_t idx = n_keep; idx < candidates.size(); idx++) {
        problem->pruneActiveNode(candidates[idx].v);
        pruned++;
    }

    if(Parameters::getVerbosity() >= 1)
        std::cout << "Dynamic node reduction: pruned " << pruned << " of "
                  << candidates.size() << " candidate nodes ("
                  << problem->countActiveNodes() << " active nodes left)" << std::endl;

    return pruned;
}