#ifndef SUPEROPTIMAL_POOL_H
#define SUPEROPTIMAL_POOL_H

#include <vector>
#include <set>

//A path collected from a join: sequence of nodes from origin to destination
struct PoolPath {
    std::vector<int> tour;      //nodes from origin to destination
    int cost;                   //objective value
    bool elementary;            //true if no node is visited more than once
    int iteration;              //DSSR iteration in which the path was found
};

//Pool of the paths found by the joins of all the DSSR iterations.
//Paths can be super-optimal (with cycles) or elementary. Duplicated tours are stored only once.
class SuperoptimalPool {

public:
    void init(int n_nodes);
    void clear();

    //Adds a path. Returns false if the same tour is already in the pool
    bool add(const std::vector<int> & tour, int cost, int iteration);

    //Queries
    const std::vector<PoolPath> & getPaths() const {return paths;}
    int size() const {return paths.size();}
    int countElementary() const;
    const PoolPath* getBestElementary() const;
    std::vector<int> getNodes() const;          //Union of the nodes of all the paths in the pool

    //Output
    void print() const;

private:
    bool isElementary(const std::vector<int> & tour) const;

    int n_nodes = 0;
    std::vector<PoolPath> paths;
    std::set<std::vector<int>> seen_tours;
    int best_elementary_id = -1;
};

#endif
