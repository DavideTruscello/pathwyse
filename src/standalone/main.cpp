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
    // Benchmark: append the global resolution time of the main algorithm
    // to benchmark_times/time_<instance>.txt (one line per run).
    // ---------------------------------------------------------------------
    std::string stem =
        std::filesystem::path(argv[1]).stem().string();

    double elapsed = pathwyse.getGlobalTime();

    std::filesystem::create_directories("benchmark_times");

    std::ofstream out(
        "benchmark_times/time_" + stem + ".txt",
        std::ios::app
    );

    out << elapsed << "\n";
    // ---------------------------------------------------------------------

    return 0;
}
