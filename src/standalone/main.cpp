#include "solver.h"
#include <fstream>
#include <filesystem>
#include <sstream>
#include <locale>
#include <string>
#include <vector>

// ---------------------------------------------------------------------
// Benchmark output
//
// If output/benchmark = 1 in the settings file, every run appends one row
// to two CSV files with the same content and different formats:
//   benchmark/result_intl.csv   separator ","  decimal point "."  (international)
//   benchmark/result_it.csv     separator ";"  decimal comma ","  (Excel, Italian settings)
// The header row is written only when a file is created.
// ---------------------------------------------------------------------

namespace {

const std::string BENCHMARK_DIR = "benchmark";

const std::vector<std::string> BENCHMARK_HEADER = {
    "file", "arcs_active", "is_deterministic", "full_network",
    "cutoff", "k1", "k2", "seed", "temperature",
    "status", "obj", "total_time", "tour_length", "dssr_iterations"
};

// One CSV field: its text (always with "." as decimal separator) and whether it is a decimal number
struct Field {
    std::string text;
    bool decimal;
};

Field textField(const std::string & s) {return {s, false};}
Field intField(long long v) {return {std::to_string(v), false};}
Field emptyField() {return {"", false};}

Field decimalField(double v) {
    std::ostringstream os;
    os.imbue(std::locale::classic());       //always "." whatever the system locale is
    os << v;
    return {os.str(), true};
}

std::string statusName(int status) {
    switch(status) {
        case PATH_OPTIMAL:      return "Optimal";
        case PATH_FEASIBLE:     return "Feasible";
        case PATH_SUPEROPTIMAL: return "Superoptimal";
        case PATH_INFEASIBLE:   return "Infeasible";
        default:                return "Unknown";
    }
}

// Writes a row: decimal numbers get decimal_sep, text containing the separator is quoted
std::string formatRow(const std::vector<Field> & fields, char sep, char decimal_sep) {
    std::string row;
    for(size_t k = 0; k < fields.size(); k++) {
        std::string text = fields[k].text;

        if(fields[k].decimal)
            for(char & c: text)
                if(c == '.')
                    c = decimal_sep;

        if(text.find(sep) != std::string::npos or text.find('"') != std::string::npos) {
            std::string quoted = "\"";
            for(char c: text) {
                if(c == '"') quoted += '"';
                quoted += c;
            }
            text = quoted + "\"";
        }

        if(k > 0) row += sep;
        row += text;
    }
    return row;
}

void appendRow(const std::string & file_name, const std::vector<Field> & fields, char sep, char decimal_sep) {
    std::string path = BENCHMARK_DIR + "/" + file_name;
    bool new_file = not std::filesystem::exists(path);

    std::ofstream out(path, std::ios::app);
    if(not out) {
        std::cout << "Warning: cannot write benchmark file " << path << std::endl;
        return;
    }

    if(new_file) {
        std::vector<Field> header;
        for(auto & h: BENCHMARK_HEADER)
            header.push_back(textField(h));
        out << formatRow(header, sep, decimal_sep) << "\n";
    }
    out << formatRow(fields, sep, decimal_sep) << "\n";
}

void writeBenchmark(Solver & pathwyse, const std::string & instance_path) {
    std::vector<Field> row;

    //Instance: file name with extension, without folders
    row.push_back(textField(std::filesystem::path(instance_path).filename().string()));

    //Settings read from the settings file
    row.push_back(intField(Parameters::isArcsGraphReductionEnabled()));
    row.push_back(intField(Parameters::isGraphArcsReductionDeterministic()));
    row.push_back(intField(Parameters::isDefaultJoinFullNetwork()));
    row.push_back(decimalField(Parameters::getGraphArcsReductionCutoff()));
    row.push_back(decimalField(Parameters::getGraphReductionK1()));
    row.push_back(decimalField(Parameters::getGraphReductionK2()));
    row.push_back(intField(Parameters::getGraphArcsReductionSeed()));
    row.push_back(decimalField(Parameters::getGraphArcsReductionTemperature()));

    //Results
    if(pathwyse.getNumberOfSolutions() > 0) {
        Path best = pathwyse.getBestSolution();
        row.push_back(textField(statusName(best.getStatus())));
        row.push_back(intField(best.getObjective()));
        row.push_back(decimalField(pathwyse.getTotalTime()));
        row.push_back(intField(best.getTourLength()));
    }
    else {
        row.push_back(textField("NoSolution"));
        row.push_back(emptyField());
        row.push_back(decimalField(pathwyse.getTotalTime()));
        row.push_back(emptyField());
    }
    row.push_back(intField(pathwyse.getIterations()));

    std::filesystem::create_directories(BENCHMARK_DIR);
    appendRow("result_intl.csv", row, ',', '.');
    appendRow("result_it.csv", row, ';', ',');
}

} // namespace

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

    // Benchmark output (output/benchmark = 1 in the settings file)
    if(Parameters::isBenchmarkEnabled())
        writeBenchmark(pathwyse, argv[1]);

    return 0;
}
