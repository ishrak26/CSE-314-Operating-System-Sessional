// taken from https://cplusplus.com/reference/random/poisson_distribution/

// poisson_distribution
#include <random>

using namespace std;

class Poisson_Random {
    default_random_engine generator;
    poisson_distribution<int> distribution;

public:
    Poisson_Random() {
        
    }
    
    Poisson_Random(double mean) {
        distribution = poisson_distribution<int> (mean);
    }

    int get_random_number() {
        int number = distribution(generator);
        return number;
    }
};
