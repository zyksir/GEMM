#include <vector>
#include <tuple>
#include <sstream> // for ostringstream
#include "lib/macros.cuh" 
#include "kernels/sgemm_kun.cu"
#include "gemm_test.hpp"
#include "kernels/1_naive.cuh"
#include "kernels/2_kernel_global_mem_coalesce.cuh"
#include "kernels/3_kernel_shared_mem_blocking.cuh"
#include "kernels/4_kernel_blocktiling.cuh"
#include "kernels/5_kernel_vectorize.cuh"
#include "kernels/6_kernel_double_buffering.cuh"
#include "kernels/6_kernel_double_buffering2.cuh"
#include "kernels/7_kernel_warptiling.cuh"
#include "kernels/7_kernel_warptiling2.cuh"

void runCublas(cublasHandle_t handle, int M, int N, int K, float alpha,
                   float *A, float *B, float beta, float *C) {
  // cuBLAS uses column-major order. So we change the order of our row-major A &
  // B, since (B^T*A^T)^T = (A*B)
  // This runs cuBLAS in full fp32 mode
  cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, 
            &alpha, B, N, A, K, &beta, C, N);
}

void runCublasFP32(cublasHandle_t handle, int M, int N, int K, float alpha,
                   float *A, float *B, float beta, float *C) {
  cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, B, CUDA_R_32F,
               N, A, CUDA_R_32F, K, &beta, C, CUDA_R_32F, N, CUBLAS_COMPUTE_32F,
               CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}

void runCublasBF16(cublasHandle_t handle, int M, int N, int K, float alpha,
                   float *A, float *B, float beta, float *C) {
  cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, B, CUDA_R_32F,
               N, A, CUDA_R_32F, K, &beta, C, CUDA_R_32F, N,
               CUBLAS_COMPUTE_32F_FAST_16BF, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}

void runCublasTF32(cublasHandle_t handle, int M, int N, int K, float alpha,
                   float *A, float *B, float beta, float *C) {
  cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, &alpha, B, CUDA_R_32F,
               N, A, CUDA_R_32F, K, &beta, C, CUDA_R_32F, N,
               CUBLAS_COMPUTE_32F_FAST_TF32, CUBLAS_GEMM_DEFAULT_TENSOR_OP);
}

using triple = std::tuple<size_t, size_t, size_t>;
int main() {
  const uint num_repeats = 10;
  std::vector<triple> problem_size = {
    triple(4096, 4096, 4096),
    triple(2048, 2048, 2048),
    triple(1024, 1024, 1024),
    triple(512, 512, 512),
    triple(128, 4096, 1024)
  };
  CudaDeviceInfo();
  for(const auto& problem : problem_size) {
    size_t M, N, K;
    std::tie(M, N, K) = problem;
    std::ostringstream test_name;
    test_name << "SGEMM ";
    test_name << M << "x" << N << "x" << K << " ";
    auto sgemm_test = GemmTest(M, N, K, test_name.str(), num_repeats);
    sgemm_test.run_baseline();
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      static cublasHandle_t handle;
      cublasCreate(&handle);
      runCublas(handle, M, N, K, 1.0, A, B, 0.0, C);
    }, "cublas");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      static cublasHandle_t handle;
      cublasCreate(&handle);
      runCublasFP32(handle, M, N, K, 1.0, A, B, 0.0, C);
    }, "cublas_fp32");
    // // wrong result
    // sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
    //   static cublasHandle_t handle;
    //   cublasCreate(&handle);
    //   runCublasBF16(handle, M, N, K, 1.0, A, B, 0.0, C);
    // }, "cublas_bf32");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      static cublasHandle_t handle;
      cublasCreate(&handle);
      runCublasTF32(handle, M, N, K, 1.0, A, B, 0.0, C);
    }, "cublas_tf32");
    sgemm_test.run_cuda(run_kun, "kun");
    sgemm_test.run_cuda(run_kun_v3, "kun_v3");
    // sgemm_test.run_cuda(run_ziqi, "ziqi"); // run result
    // // too slow
    // sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
    //   run_sgemm_naive(M, N, K, 1.0, A, B, 0.0, C);
    // }, "v1_naive");
    // sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
    //   run_sgemm_coalesce(M, N, K, 1.0, A, B, 0.0, C);
    // }, "v2_coalesce");
    // sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
    //   run_sgemm_shared_mem_block(M, N, K, 1.0, A, B, 0.0, C);
    // }, "v3_shared_mem");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      run_sgemm_blocktiling(M, N, K, 1.0, A, B, 0.0, C);
    }, "v4_block_tiling");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      run_sgemm_vectorize(M, N, K, 1.0, A, B, 0.0, C);
    }, "v5_vectorize");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      run_sgemm_double_buffering(M, N, K, 1.0, A, B, 0.0, C);
    }, "v6_double_buffering");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      run_sgemm_double_buffering2(M, N, K, 1.0, A, B, 0.0, C);
    }, "v6_double_buffering2");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      run_sgemm_warptiling(M, N, K, 1.0, A, B, 0.0, C);
    }, "v7_warptiling");
    sgemm_test.run_cuda([](float* A, float* B, float* C, size_t M, size_t N, size_t K){
      run_sgemm_warptiling2(M, N, K, 1.0, A, B, 0.0, C);
    }, "v7_warptilin2");
  }
  return 0;
}