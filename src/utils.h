#pragma once
#include <string>
#include <chrono>

using std::chrono::duration_cast;
using std::chrono::duration;
using std::chrono::microseconds;
using std::chrono::nanoseconds;
using std::chrono::steady_clock;
using std::clog;
using std::endl;
using std::string;


template<class T>
T MyRand(const T & min, const T & max) {
    static thread_local std::mt19937 generator;
    std::uniform_real_distribution<T> distribution(min,max);
    return distribution(generator);
}

template<class T>
void GenerateRandomMatrix(T* input, size_t input_length) {
  for(int i = 0; i < input_length; ++i) {
    input[i] = MyRand<T>(-1.0f, 1.0f);
  }
}

#define CUDA_CHECK(err) cuda_check((err), __FILE__, __LINE__);
inline void cuda_check(cudaError_t err, const char* file, int line) {
  if (err != cudaSuccess) {
    throw std::runtime_error(
        string(file) + ":" + std::to_string(line) + ": " + string(cudaGetErrorString(err)));
  }
}

void CudaDeviceInfo() {
  int deviceId;

  cudaGetDevice(&deviceId);

  cudaDeviceProp props{};
  cudaGetDeviceProperties(&props, deviceId);

  printf("Device ID: %d\n\
    Name: %s\n\
    Compute Capability: %d.%d\n\
    memoryBusWidth: %d\n\
    maxThreadsPerBlock: %d\n\
    maxThreadsPerMultiProcessor: %d\n\
    maxRegsPerBlock: %d\n\
    maxRegsPerMultiProcessor: %d\n\
    totalGlobalMem: %zuMB\n\
    sharedMemPerBlock: %zuKB\n\
    sharedMemPerMultiprocessor: %zuKB\n\
    totalConstMem: %zuKB\n\
    multiProcessorCount: %d\n\
    Warp Size: %d\n",
         deviceId, props.name, props.major, props.minor, props.memoryBusWidth,
         props.maxThreadsPerBlock, props.maxThreadsPerMultiProcessor,
         props.regsPerBlock, props.regsPerMultiprocessor,
         props.totalGlobalMem / 1024 / 1024, props.sharedMemPerBlock / 1024,
         props.sharedMemPerMultiprocessor / 1024, props.totalConstMem / 1024,
         props.multiProcessorCount, props.warpSize);
};