
#ifndef NODE_STATS_H
#define NODE_STATS_H

#include <vector>
#include "data/problem.h"

class LMDefault;

class NodeStats {

public:

    NodeStats() : available(false), n_nodes(0), n_unobserved(0),
                  max_abs_obj(1.0), max_abs_res(1.0), max_count(1.0) {}

    void collect(LMDefault* lm, Problem* problem);

    bool isAvailable() const {return available;}
    int getUnobservedCount() const {return n_unobserved;}

    double objectiveTerm(int i, int j) const;
    double resourceTerm(int i, int j) const;
    double labelCountTerm(int i, int j) const;

    double getObjective(int v) const {return obj[v] / max_abs_obj;}
    double getResource(int v) const {return res[v] / max_abs_res;}
    double getLabelCount(int v) const {return count[v] / max_count;}

private:

    bool available;
    int n_nodes;
    int n_unobserved;

    std::vector<double> obj;
    std::vector<double> res;
    std::vector<double> count;

    double max_abs_obj, max_abs_res, max_count;

    static double meanOfObserved(const std::vector<double> & values,
                                 const std::vector<unsigned int> & counts);
};

#endif