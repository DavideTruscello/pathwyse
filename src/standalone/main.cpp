#include "solver.h"
#include <fstream>
#include <filesystem>

// Main file for standalone application
int main(int argc, char **argv) {

    // Read data from console
    if(not Parameters::parseConsole(argc, argv))
        return 1;

    // Create a Pathwyse solver
    Solver pathwyse = Solver();

    // Read problem
    pathwyse.readProblem();

    // Setup algorithms
    pathwyse.setupAlgorithms();

    // Solve the problem
    pathwyse.solve();

    // Print solution
    pathwyse.printBestSolution();

    // ---------------------------------------------------------------------
    // Benchmark: append one CSV row per run to
    // benchmark_times/time_<instance>.txt with the format
    //     time,obj,tour_length,seed
    // If no solution was found, obj and tour_length are left empty.
    // seed is the value of algo/default/graph_reduction/arcs/seed read from
    // the settings file (a negative value means a random seed was drawn).
    // ---------------------------------------------------------------------
    std::string stem =
        std::filesystem::path(argv[1]).stem().string();

    double elapsed = pathwyse.getGlobalTime();

    std::filesystem::create_directories("benchmark_times");

    std::ofstream out(
        "benchmark_times/time_" + stem + ".txt",
        std::ios::app
    );

    out << elapsed << ",";
    if(pathwyse.getNumberOfSolutions() > 0) {
        Path best = pathwyse.getBestSolution();
        out << best.getObjective() << "," << best.getTourLength();
    }
    else
        out << ",";
    out << "," << Parameters::getGraphArcsReductionSeed();
    out << "\n";
    // ---------------------------------------------------------------------

    return 0;
}
