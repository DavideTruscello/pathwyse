#include "static_arc_reduction.h"
#include <limits>
#include <stdlib.h>
#include <algorithm>

StaticArcReduction::StaticArcReduction(Problem* problem) : problem(problem) {
    num_nodes = problem->getNumNodes();

    score.resize(num_nodes, std::vector(num_nodes, std::numeric_limits<double>::max()));
    arcsConnection.resize(num_nodes);

    Resource* obj = problem->getObj();
    max_abs_arc_cost = 1;
    max_abs_node_cost = 1;
    for (int i = 0; i < num_nodes; i++) {
        max_abs_node_cost = std::max(max_abs_node_cost, std::abs(obj->getNodeCost(i)));
        for (auto& j : problem->getNeighbors(i, true))
            max_abs_arc_cost = std::max(max_abs_arc_cost, std::abs(obj->getArcCost(i, j)));
    }
}

double StaticArcReduction::computeScore(int i, int j, double K, double K2) const {
    Resource* obj = problem->getObj();

    const double C_ij = obj->getArcCost(i, j);

    double resource_term = 0.0;
    for (int l = 0; l < problem->getNumRes(); l++) {
        Resource* res = problem->getRes(l);
        const double r_l = res->getArcCost(i, j) + res->getNodeCost(j);
        const double R_l = res->getUB();
        if (R_l != INFPLUS and R_l != 0)
            resource_term += r_l / R_l;
    }
    resource_term = resource_term / problem->getNumRes(); // consumo % media per res
    const double P_s = obj->getNodeCost(i);
    const double P_d = obj->getNodeCost(j);

    // TODO: dividi costi e premi per il costo massimo e premio massimo (in valore assoluto a den)
    return C_ij / max_abs_arc_cost + K * resource_term + K2 * (P_s + P_d) / (max_abs_node_cost*2);
}

void StaticArcReduction::reduce(double beta, double K, double K2) {
    struct ScoredArc { int i, j; double s; };
    std::vector<ScoredArc> arcs;

    for (int i = 0; i < num_nodes; i++) {
        for (auto& j : problem->getNeighbors(i, true)) {
            double s = computeScore(i, j, K, K2);
            score[i][j] = s;
            arcs.push_back({i, j, s});
        }
    }

    std::sort(arcs.begin(), arcs.end(),
              [](const ScoredArc& a, const ScoredArc& b) { return a.s < b.s; });

    size_t n_keep = static_cast<size_t>(beta * arcs.size());

    for (size_t idx = 0; idx < n_keep and idx < arcs.size(); idx++) {
        arcsConnection[arcs[idx].i].push_back(arcs[idx].j);
    }

    ensureDepotConnectivity();
}

void StaticArcReduction::ensureDepotConnectivity() {
    int s = problem->getOrigin();
    int t = problem->getDestination();

    for (auto& j : problem->getNeighbors(s, true)) {
        auto& vec = arcsConnection[s];
        if (std::find(vec.begin(), vec.end(), j) == vec.end())
            vec.push_back(j);
    }

    for (auto& i : problem->getNeighbors(t, false)) {
        auto& vec = arcsConnection[i];
        if (std::find(vec.begin(), vec.end(), t) == vec.end())
            vec.push_back(t);
    }
}

void StaticArcReduction::apply() {
    this->reduce(Parameters::getGraphArcsReductionCutoff(), Parameters::getGraphReductionK1(), Parameters::getGraphReductionK2());
    problem->getNetwork()->clearArcs();
    problem->setNeighbors(arcsConnection);
}
