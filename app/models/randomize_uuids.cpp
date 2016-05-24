/// clang++ -std=c++11 -O3 test_csv.cpp -lpthread -I. -L. -L/usr/local/opt/curl/lib -I/usr/local/opt/curl/include -lrestless -lcurl
#include "csv.h"
#include<iostream>
#include <set>
#include <unordered_map>
#include "json.hpp"
#include <algorithm>
#include <restless.hpp>
#include <regex>
#include <fstream>
#include <vector>

#include <sstream>
#include <string>
std::ifstream infile("random_uuids.log");

std::string remove_spaces(std::string);

std::vector<std::string> split(const std::string &s, char delim);
std::vector<std::string> &split(const std::string &s, char delim, std::vector<std::string> &elems);

using json = nlohmann::json;

int returnVal(char x)
{
  return (int)x - 87;
}

int calc_int_val(std::string word)
{
  for(char alphabet : word)
  {
    std::cout << alphabet << std:: endl;
  }
}

int main(){

  // printf("%d %d\n", get_index_change("SW5"), get_index_change("0LD") );
  std::string line;
  std::vector<std::string> empty_vec = {};
  int val = 29688343;
  std::vector<int> int_vector;
  int_vector.resize(val);

  while (std::getline(infile, line))
  {
    std::vector<std::string>words = split(line, '|');
    int postcode = 
  }


}
//{"a" : {"text" : "kings road","completion" : {"field" : "suggest","size":10000}}}

std::vector<std::string> split(const std::string &s, char delim) {
    std::vector<std::string> elems;
    split(s, delim, elems);
    return elems;
}

std::vector<std::string> &split(const std::string &s, char delim, std::vector<std::string> &elems) {
    std::stringstream ss(s);
    std::string item;
    while (std::getline(ss, item, delim)) {
        elems.push_back(item);
    }
    return elems;
}


std::string remove_spaces(std::string input)
{
  input.erase(std::remove(input.begin(),input.end(),' '),input.end());
  return input;
}


